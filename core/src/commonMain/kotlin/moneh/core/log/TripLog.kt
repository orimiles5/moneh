package moneh.core.log

import moneh.core.trip.TripEvent
import org.kotlincrypto.hash.sha2.SHA256

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
            is TripEvent.Hired -> listOf("Hired", event.tariffVersion)
            is TripEvent.Moved -> listOf("Moved", event.metres.toString())
            is TripEvent.Paused -> listOf("Paused")
            is TripEvent.Resumed -> listOf("Resumed")
            is TripEvent.ExtraAdded -> listOf("ExtraAdded", event.extraId, event.amountMinorUnits?.toString() ?: "")
            is TripEvent.Stopped -> listOf("Stopped")
            is TripEvent.Settled -> listOf("Settled")
        }
    return (listOf(ENCODING_VERSION, event.at.toEpochMilliseconds().toString()) + fields).joinToString("") { "${it.length}:$it" }
}

private const val ENCODING_VERSION = "v1"
