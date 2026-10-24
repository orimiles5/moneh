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
        assertTrue(meter.addExtra(t0 - minute, "booking"))
        assertTrue(meter.stop(t0 - 2 * minute))
    }

    @Test
    fun reportsRatesWithVat() {
        val tariffA = Meter("il-2026-04").rateReport.single { it.rateId == "A" }
        // 10.56 x 1.18 = 12.4608; 1.65 x 1.18 = 1.947; 3.21 x 1.18 = 3.7878.
        assertEquals(1246, tariffA.startingFare)
        assertEquals(195, tariffA.perMinute)
        assertEquals(listOf(195L, 379L), tariffA.perKm)
        assertEquals(listOf(0, 10), tariffA.perKmFromKm)
    }

    @Test
    fun issuesOneInvoicePerTripAndRecordsPayment() {
        val meter = Meter("il-2026-04")
        meter.hire(t0, false)
        assertFalse(meter.issueInvoice(t0, 1, "1234", "12-345-67", "Dealer", "512345678", "Driver", "000000018"), "only in payment")
        meter.stop(t0 + 10 * minute)
        assertTrue(meter.issueInvoice(t0 + 10 * minute, 7, "1234", "12-345-67", "Dealer", "512345678", "Driver", "000000018"))
        assertFalse(meter.issueInvoice(t0 + 10 * minute, 8, "1234", "12-345-67", "Dealer", "512345678", "Driver", "000000018"))
        assertEquals(7, meter.reading(t0 + 20 * minute).invoice?.number)
        assertEquals("A", meter.reading(t0 + 20 * 60 * minute).rateId, "the tariff stays the one in force at stop")
        assertFalse(meter.settlePaid(t0 + 11 * minute, "cheque"))
        assertTrue(meter.settlePaid(t0 + 11 * minute, "card"))
        val restored = assertNotNull(Meter.restore(meter.entries))
        assertEquals("card", restored.reading(t0 + 11 * minute).paymentMethod)
        assertEquals("Driver", restored.reading(t0 + 11 * minute).invoice?.driverName)
    }

    @Test
    fun drivingOnDuringPaymentReturnsToHired() {
        val meter = Meter("il-2026-04")
        meter.hire(t0, false)
        drive(meter, t0, 60)
        meter.stop(t0 + minute)
        val atStop = meter.reading(t0 + minute).distanceMetres
        // A few metres of creep (well under 10 m) keep the meter in payment.
        meter.location(t0 + minute + 1_000, 32.08 + 61 * 0.0001, 34.78, 5.0, 0.0)
        assertEquals(MeterPhase.STOPPED, meter.phase)
        drive(meter, t0 + 2 * minute, 30, startLat = 32.08 + 61 * 0.0001)
        assertEquals(MeterPhase.HIRED, meter.phase)
        assertTrue(meter.reading(t0 + 3 * minute).distanceMetres > atStop + 10)
        assertNotNull(Meter.restore(meter.entries))
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

    @Test
    fun pricesAndCountsExtras() {
        val meter = Meter("il-2026-04")
        // Booking is 4.90 before VAT: 5.782 rounds to 5.78; Eilat trips pay 4.90.
        assertEquals(578, meter.extraPassengerPrice("booking"))
        assertNull(meter.extraPassengerPrice("expressLane"))
        assertNull(meter.extraPassengerPrice("nope"))
        assertTrue(meter.hire(t0, vatExempt = true))
        assertEquals(490, meter.extraPassengerPrice("booking"))
        assertEquals(0, meter.extraCount("booking"))
        meter.addExtra(t0 + minute, "booking")
        meter.addExtra(t0 + minute, "booking")
        meter.addExtraAmount(t0 + minute, "expressLane", 1_000)
        assertEquals(2, meter.extraCount("booking"))
        assertEquals(1, meter.extraCount("expressLane"))
        val withBoth = meter.reading(t0 + minute).total
        assertTrue(meter.removeExtra(t0 + minute, "booking"))
        assertEquals(1, meter.extraCount("booking"))
        assertEquals(withBoth - 490, meter.reading(t0 + minute).total)
        assertTrue(meter.removeExtra(t0 + minute, "booking"))
        assertFalse(meter.removeExtra(t0 + minute, "booking"))
        assertEquals(0, Meter.restore(meter.entries)?.extraCount("booking"))
        assertFalse(meter.addExtraAmount(t0 + minute, "expressLane", 10_000), "a single extra is at most 99.99")
        assertFalse(meter.discountPercent(t0 + minute, 0))
        assertTrue(meter.discountAmount(t0 + minute, 300))
        assertEquals(300, Meter.restore(meter.entries)?.reading(t0 + minute)?.discount, "Eilat: no VAT to take out")
    }
}
