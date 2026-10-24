package moneh.core.log

import moneh.core.trip.TripEvent
import org.kotlincrypto.hash.sha2.SHA256
import kotlin.time.Instant

/**
 * Append-only, tamper-evident record of a trip: each entry's hash covers the previous hash and the event's
 * canonical encoding, so altering, removing or reordering any entry breaks every hash after it.
 */
class TripLog private constructor(
    val entries: List<Entry>,
) {
    data class Entry(
        val sequence: Int,
        val encoded: String,
        val previousHash: String,
        val hash: String,
    )

    /** Hash of the latest entry; printing a prefix of it on the receipt ties the receipt to this log. */
    val head: String get() = entries.lastOrNull()?.hash ?: GENESIS

    fun append(event: TripEvent): TripLog {
        val encoded = encode(event)
        return TripLog(entries + Entry(entries.size, encoded, head, hash(head, encoded)))
    }

    companion object {
        val EMPTY = TripLog(emptyList())

        /** Index of the first entry that fails verification, or null if the whole chain is intact. */
        fun firstBrokenEntry(entries: List<Entry>): Int? {
            var previous = GENESIS
            entries.forEachIndexed { index, entry ->
                if (entry.sequence != index || entry.previousHash != previous || entry.hash != hash(previous, entry.encoded)) {
                    return index
                }
                previous = entry.hash
            }
            return null
        }

        private val GENESIS = "0".repeat(64)

        private fun hash(
            previousHash: String,
            encoded: String,
        ): String = SHA256().digest((previousHash + encoded).encodeToByteArray()).toHexString()
    }
}

/**
 * Canonical, versioned encoding. Never change an existing version's format: logs must verify forever.
 * Fields are length-prefixed ("<length>:<value>"), so no value can be confused with a separator.
 */
internal fun encode(event: TripEvent): String {
    val fields =
        when (event) {
            // The agreed price is appended only when set, so logs written before it existed keep their encoding.
            is TripEvent.Hired ->
                listOf("Hired", event.tariffVersion, if (event.vatExempt) "1" else "0") +
                    listOfNotNull(event.agreedPriceMinorUnits?.toString())
            is TripEvent.Moved -> listOf("Moved", event.metres.toString())
            is TripEvent.Paused -> listOf("Paused")
            is TripEvent.Resumed -> listOf("Resumed")
            is TripEvent.ExtraAdded -> listOf("ExtraAdded", event.extraId, event.amountMinorUnits?.toString() ?: "")
            is TripEvent.ExtraRemoved -> listOf("ExtraRemoved", event.extraId)
            is TripEvent.DiscountSet ->
                listOf("DiscountSet", event.basisPoints?.toString() ?: "", event.amountMinorUnits?.toString() ?: "")
            is TripEvent.Stopped -> listOf("Stopped")
            is TripEvent.Settled -> listOf("Settled")
        }
    return (listOf(ENCODING_VERSION, event.at.toEpochMilliseconds().toString()) + fields).joinToString("") { "${it.length}:$it" }
}

/** Inverse of [encode]. Throws [IllegalArgumentException] for anything [encode] could not have produced. */
internal fun decode(encoded: String): TripEvent {
    val fields = splitFields(encoded)
    require(fields.size > HEADER_FIELDS - 1 && fields[0] == ENCODING_VERSION) { "Unsupported encoding: $encoded" }
    val (_, epochMs, type) = fields
    val at = Instant.fromEpochMilliseconds(epochMs.toLong())
    val args = fields.drop(HEADER_FIELDS)

    fun arg(index: Int) = requireNotNull(args.getOrNull(index)) { "Missing field $index: $encoded" }
    return when (type) {
        "Hired" -> TripEvent.Hired(at, arg(0), arg(1) == "1", args.getOrNull(2)?.toLong())
        "Moved" -> TripEvent.Moved(at, arg(0).toLong())
        "Paused" -> TripEvent.Paused(at)
        "Resumed" -> TripEvent.Resumed(at)
        "ExtraAdded" -> TripEvent.ExtraAdded(at, arg(0), arg(1).ifEmpty { null }?.toLong())
        "ExtraRemoved" -> TripEvent.ExtraRemoved(at, arg(0))
        "DiscountSet" -> TripEvent.DiscountSet(at, arg(0).ifEmpty { null }?.toInt(), arg(1).ifEmpty { null }?.toLong())
        "Stopped" -> TripEvent.Stopped(at)
        "Settled" -> TripEvent.Settled(at)
        else -> throw IllegalArgumentException("Unknown event $type")
    }.also { require(encode(it) == encoded) { "Non-canonical encoding: $encoded" } }
}

private fun splitFields(encoded: String): List<String> {
    val fields = mutableListOf<String>()
    var index = 0
    while (index < encoded.length) {
        val colon = encoded.indexOf(':', index)
        require(colon > index) { "Malformed encoding: $encoded" }
        val end = colon + 1 + encoded.substring(index, colon).toInt()
        require(end <= encoded.length) { "Malformed encoding: $encoded" }
        fields += encoded.substring(colon + 1, end)
        index = end
    }
    return fields
}

private const val ENCODING_VERSION = "v1"

/** Version, timestamp and event type precede each event's own fields. */
private const val HEADER_FIELDS = 3
