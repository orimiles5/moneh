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
                return PastTrip(id: file.lastPathComponent, reading: meter.map { FareReading($0.reading(nowMs: 0)) })
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
}
