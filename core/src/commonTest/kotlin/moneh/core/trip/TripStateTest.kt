package moneh.core.trip

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Instant

class TripStateTest {
    private val start = Instant.parse("2026-10-18T10:00:00Z")

    @Test
    fun fullTripRecordsEveryEventInOrder() {
        val settled =
            TripState.Idle
                .hire(start, "il-2026-04")
                .move(start + 1.minutes, 500)
                .pause(start + 2.minutes)
                .addExtra(start + 3.minutes, "highway6")
                .resume(start + 4.minutes)
                .stop(start + 5.minutes)
                .addExtra(start + 5.minutes, "expressLane", amountMinorUnits = 1200)
                .settle(start + 6.minutes)

        assertEquals(
            listOf(
                TripEvent.Hired(start, "il-2026-04"),
                TripEvent.Moved(start + 1.minutes, 500),
                TripEvent.Paused(start + 2.minutes),
                TripEvent.ExtraAdded(start + 3.minutes, "highway6"),
                TripEvent.Resumed(start + 4.minutes),
                TripEvent.Stopped(start + 5.minutes),
                TripEvent.ExtraAdded(start + 5.minutes, "expressLane", 1200),
                TripEvent.Settled(start + 6.minutes),
            ),
            settled.events,
        )
    }

    @Test
    fun rejectsEventsOutOfTimeOrder() {
        val hired = TripState.Idle.hire(start, "il-2026-04")
        assertFailsWith<IllegalArgumentException> { hired.stop(start - 1.minutes) }
    }

    @Test
    fun rejectsNegativeDistance() {
        val hired = TripState.Idle.hire(start, "il-2026-04")
        assertFailsWith<IllegalArgumentException> { hired.move(start, -1) }
    }
}
