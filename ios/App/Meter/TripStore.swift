import Foundation
import MonehCore

/// Persists the active trip's log after every event, so a trip survives the app being killed.
/// Settled trips move to an archive folder, one file each.
struct TripStore {
    struct StoredEntry: Codable, Equatable {
        let sequence: Int32
        let encoded: String
        let previousHash: String
        let hash: String
    }

    let directory: URL

    static let standard = TripStore(
        directory: URL.applicationSupportDirectory.appending(path: "Trips", directoryHint: .isDirectory)
    )

    private var currentFile: URL {
        directory.appending(path: "current.json")
    }

    private var archive: URL {
        directory.appending(path: "archive", directoryHint: .isDirectory)
    }

    func saveCurrent(_ entries: [TripLog.Entry]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stored = entries.map {
            StoredEntry(sequence: $0.sequence, encoded: $0.encoded, previousHash: $0.previousHash, hash: $0.hash)
        }
        try JSONEncoder().encode(stored).write(
            to: currentFile,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func loadCurrent() -> [TripLog.Entry]? {
        load(currentFile)
    }

    private func load(_ file: URL) -> [TripLog.Entry]? {
        guard let data = try? Data(contentsOf: file),
              let stored = try? JSONDecoder().decode([StoredEntry].self, from: data)
        else { return nil }
        return stored.map {
            TripLog.Entry(sequence: $0.sequence, encoded: $0.encoded, previousHash: $0.previousHash, hash: $0.hash)
        }
    }

    /// Moves the current trip into the archive, named by its final log hash.
    func archiveCurrent(head: String) throws {
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: currentFile, to: archive.appending(path: "\(head).json"))
    }

    // ponytail: replays every trip on each open; keep a summary index if history grows past a few thousand trips.
    /// Every settled trip, newest first. A trip whose file no longer verifies has no reading, so tampering shows.
    func archivedTrips() -> [PastTrip] {
        let files = (try? FileManager.default.contentsOfDirectory(at: archive, includingPropertiesForKeys: nil)) ?? []
        return files
            .map { file in
                let meter = load(file).flatMap { Meter.companion.restore(entries: $0) }
                // Reading at time zero clamps to the trip's last event, so it is the final fare.
                let reading = meter?.reading(nowMs: 0)
                return PastTrip(
                    id: file.lastPathComponent,
                    reading: reading.map(FareReading.init),
                    coreReading: reading
                )
            }
            .sorted { ($0.reading?.startedAt ?? .distantPast) > ($1.reading?.startedAt ?? .distantPast) }
    }

    func archivedTripCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: archive.path()).count) ?? 0
    }
}

struct PastTrip: Identifiable, Equatable {
    let id: String
    let reading: FareReading?
    /// The core's reading, for totals computed in the core.
    var coreReading: MeterReading?
}

/// A driver's shift (spec 2018 §8.3.1): who drove, for which dealer, and every metre driven.
struct Shift: Codable, Equatable, Identifiable {
    var id = UUID()
    let openedAt: Date
    var closedAt: Date?
    let taxiNumber: String
    let licenceNumber: String
    let dealerName: String
    let dealerNumber: String
    let driverName: String
    let driverId: String
    var drivenMetres: Int64 = 0

    func includes(_ trip: FareReading) -> Bool {
        guard let start = trip.startedAt else { return false }
        return start >= openedAt && start <= (closedAt ?? .distantFuture)
    }
}

extension TripStore {
    private var shifts: URL {
        directory.appending(path: "Shifts", directoryHint: .isDirectory)
    }

    private var currentShiftFile: URL {
        shifts.appending(path: "current.json")
    }

    func saveShift(_ shift: Shift) throws {
        try FileManager.default.createDirectory(at: shifts, withIntermediateDirectories: true)
        try JSONEncoder().encode(shift).write(
            to: currentShiftFile,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func loadShift() -> Shift? {
        (try? Data(contentsOf: currentShiftFile)).flatMap { try? JSONDecoder().decode(Shift.self, from: $0) }
    }

    /// Closed shifts are kept, never pruned: the spec asks for at least six months (§8.3.5).
    func closeShift(_ shift: Shift) throws {
        try JSONEncoder().encode(shift).write(
            to: shifts.appending(path: "\(shift.id.uuidString).json"),
            options: .atomic
        )
        try FileManager.default.removeItem(at: currentShiftFile)
    }

    /// Every shift, newest first, the open one included.
    func allShifts() -> [Shift] {
        let files = (try? FileManager.default.contentsOfDirectory(at: shifts, includingPropertiesForKeys: nil)) ?? []
        return files
            .compactMap { (try? Data(contentsOf: $0)).flatMap { try? JSONDecoder().decode(Shift.self, from: $0) } }
            .sorted { $0.openedAt > $1.openedAt }
    }
}

/// One change to what decides the fare or names the taxi (spec 2018 §7.3, Annex C).
struct SealEntry: Codable, Equatable {
    enum Kind: String, Codable {
        case tariff, licence
    }

    let recordedAt: Date
    let kind: Kind
    let value: String
}

extension TripStore {
    private var sealFile: URL {
        directory.appending(path: "seal.json")
    }

    /// Every change ever recorded, oldest first. There is no way to remove one.
    func sealLog() -> [SealEntry] {
        (try? Data(contentsOf: sealFile)).flatMap { try? JSONDecoder().decode([SealEntry].self, from: $0) } ?? []
    }

    /// Appends [value] unless it is already the latest of its kind.
    func recordSeal(_ kind: SealEntry.Kind, _ value: String, at date: Date) {
        var log = sealLog()
        guard log.last(where: { $0.kind == kind })?.value != value else { return }
        log.append(SealEntry(recordedAt: date, kind: kind, value: value))
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(log).write(
            to: sealFile,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
