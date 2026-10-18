package moneh.core

import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import moneh.core.log.TripLog
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class MeterTest {
    private val t0 = LocalDateTime.parse("2026-10-18T10:00").toInstant(TimeZone.of("Asia/Jerusalem")).toEpochMilliseconds()
    private val minute = 60_000L

    // 0.001 degrees of latitude is about 111 m.
    private fun drive(
        meter: Meter,
        fromMs: Long,
        seconds: Int,
        startLat: Double = 32.08,
    ) = (0..seconds).forEach { s ->
        meter.location(fromMs + s * 1_000L, startLat + s * 0.0001, 34.78, 5.0, 11.0)
    }

    @Test
    fun runsATripEndToEnd() {
        val meter = Meter("il-2026-04")
        assertEquals(MeterPhase.IDLE, meter.phase)
        assertTrue(meter.hire(t0, vatExempt = false))
        drive(meter, t0, 600)
        assertTrue(meter.stop(t0 + 10 * minute))
        val reading = meter.reading(t0 + 10 * minute)
        assertEquals(MeterPhase.STOPPED, reading.phase)
        assertEquals("A", reading.rateId)
        assertEquals(600, reading.chargedSeconds)
        assertTrue(reading.distanceMetres in 6_400..6_700, "${reading.distanceMetres} m")
        assertTrue(meter.settle(t0 + 11 * minute))
        assertEquals(MeterPhase.SETTLED, meter.phase)
    }

    @Test
    fun illegalCallsAreRefusedNotThrown() {
        val meter = Meter("il-2026-04")
        assertFalse(meter.stop(t0))
        assertFalse(meter.addExtra(t0, "booking"))
        meter.hire(t0, false)
        assertFalse(meter.hire(t0, false))
        assertFalse(meter.addExtra(t0, "noSuchExtra"))
        assertFalse(meter.addExtra(t0, "expressLane"), "needs an amount")
        assertFalse(meter.addExtraAmount(t0, "booking", 100), "has a fixed price")
        assertFalse(meter.addExtraAmount(t0, "expressLane", -1))
        assertTrue(meter.addExtraAmount(t0, "expressLane", 1200))
    }

    @Test
    fun listsExtrasByKind() {
        val meter = Meter("il-2026-04")
        assertEquals(listOf("expressLane"), meter.enteredAmountExtras)
        assertEquals(7, meter.fixedPriceExtras.size)
        assertTrue("booking" in meter.fixedPriceExtras)
    }

    @Test
    fun clockSteppingBackwardsDoesNotCrash() {
        val meter = Meter("il-2026-04")
        meter.hire(t0, false)
        assertTrue(meter.pause(t0 - minute))
        assertTrue(meter.resume(t0 - 2 * minute))
    }

    @Test
    fun distanceIsNotChargedWhilePaused() {
        val meter = Meter("il-2026-04")
        meter.hire(t0, false)
        meter.pause(t0)
        drive(meter, t0, 120)
        meter.resume(t0 + 2 * minute)
        assertEquals(0, meter.reading(t0 + 2 * minute).distanceMetres)
    }

    @Test
    fun restoresAnUnfinishedTripFromItsLog() {
        val meter = Meter("il-2026-04")
        meter.hire(t0, vatExempt = true)
        drive(meter, t0, 300)
        meter.addExtra(t0 + 5 * minute, "booking")
        val restored = assertNotNull(Meter.restore(meter.entries))
        assertEquals(meter.reading(t0 + 6 * minute), restored.reading(t0 + 6 * minute))
        assertTrue(restored.stop(t0 + 6 * minute))
    }

    @Test
    fun refusesToRestoreATamperedLog() {
        val meter = Meter("il-2026-04")
        meter.hire(t0, false)
        drive(meter, t0, 120)
        val tampered = meter.entries.toMutableList().apply { this[1] = this[1].copy(encoded = this[1].encoded + "x") }
        assertNull(Meter.restore(tampered))
        assertNull(Meter.restore(emptyList<TripLog.Entry>()))
    }
}
