package moneh.core.log

import moneh.core.trip.TripEvent
import moneh.core.trip.TripState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Instant

class TripLogTest {
    private val start = Instant.parse("2026-10-18T10:00:00Z")
    private val events =
        TripState.Idle
            .hire(start, "il-2026-04")
            .move(start + 1.minutes, 800)
            .addExtra(start + 2.minutes, "expressLane", 1200)
            .stop(start + 3.minutes)
            .settle(start + 4.minutes)
            .events
    private val log = events.fold(TripLog.EMPTY, TripLog::append)

    @Test
    fun intactChainVerifies() {
        assertNull(TripLog.firstBrokenEntry(log.entries))
        assertEquals(log.entries.last().hash, log.head)
    }

    @Test
    fun encodingIsStable() {
        // Pinned: a change here means old logs would no longer verify.
        assertEquals("2:v113:17923176000005:Hired10:il-2026-041:0", log.entries[0].encoded)
        assertEquals("2:v113:179231772000010:ExtraAdded11:expressLane4:1200", log.entries[2].encoded)
    }

    @Test
    fun knownHash() {
        // SHA-256 of 64 zeros followed by the first encoded entry, computed independently with shasum.
        assertEquals(GENESIS_HASH_OF_FIRST, log.entries[0].hash)
    }

    @Test
    fun decodeInvertsEncode() {
        assertEquals(events, log.entries.map { decode(it.encoded) })
        val eilat = TripEvent.Hired(start, "il-2026-04", vatExempt = true)
        assertEquals(eilat, decode(encode(eilat)))
        val removed = TripEvent.ExtraRemoved(start, "booking")
        assertEquals(removed, decode(encode(removed)))
    }

    @Test
    fun decodeRejectsMalformedInput() {
        listOf("", "2:v2", "2:v113:17923176000005:Bogus", "2:v113:179231760000099:Hired", "2:v113:17923176000005:Hired", "x").forEach {
            assertFailsWith<IllegalArgumentException>(it) { decode(it) }
        }
    }

    @Test
    fun alteredEventIsDetected() {
        val tampered = log.entries.toMutableList()
        tampered[1] = tampered[1].copy(encoded = tampered[1].encoded.replace("3:800", "3:100"))
        assertEquals(1, TripLog.firstBrokenEntry(tampered))
    }

    @Test
    fun removedEventIsDetected() {
        assertEquals(1, TripLog.firstBrokenEntry(log.entries - log.entries[1]))
    }

    @Test
    fun forgedEntryWithAValidHashBreaksTheNextLink() {
        val forgedEvents = events.toMutableList().apply { this[1] = TripEvent.Moved(start + 1.minutes, 100) }
        val forgedEntry = forgedEvents.fold(TripLog.EMPTY, TripLog::append).entries[1]
        val tampered = log.entries.toMutableList().apply { this[1] = forgedEntry }
        assertEquals(2, TripLog.firstBrokenEntry(tampered))
    }

    @Test
    fun reorderedEventsAreDetected() {
        val swapped = log.entries.toMutableList().apply { add(1, removeAt(2)) }
        assertEquals(1, TripLog.firstBrokenEntry(swapped))
    }

    private companion object {
        const val GENESIS_HASH_OF_FIRST = "def26a6904b73785e3cc089b57963be715af29d86585725edb8f515f4ce4e41e"
    }
}
