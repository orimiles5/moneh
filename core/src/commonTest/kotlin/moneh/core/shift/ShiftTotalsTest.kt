package moneh.core.shift

import moneh.core.Meter
import moneh.core.MeterPhase
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ShiftTotalsTest {
    private val t0 = 1_792_317_600_000L
    private val minute = 60_000L

    private fun trip(
        start: Long,
        payment: String,
        withBooking: Boolean = false,
    ) = Meter("il-2026-04").run {
        hire(start, vatExempt = false)
        (0..120).forEach { location(start + it * 1_000L, 32.08 + it * 0.0001, 34.78, 5.0, 11.0) }
        if (withBooking) addExtra(start + 2 * minute, "booking")
        stop(start + 2 * minute)
        settlePaid(start + 2 * minute, payment)
        reading(start + 3 * minute)
    }

    @Test
    fun sumsSettledTripsByPaymentMethod() {
        val cash = trip(t0, "cash", withBooking = true)
        val card = trip(t0 + 10 * minute, "card")
        val running = Meter("il-2026-04").apply { hire(t0 + 20 * minute, false) }.reading(t0 + 21 * minute)
        val totals = ShiftTotals.of(listOf(cash, card, running), drivenMetres = 50_000)
        assertEquals(MeterPhase.SETTLED, cash.phase)
        assertEquals(2, totals.trips)
        assertEquals(cash.total, totals.cash)
        assertEquals(card.total, totals.card)
        assertEquals(cash.total + card.total, totals.income)
        assertEquals(578, totals.extras)
        assertEquals(cash.distanceMetres + card.distanceMetres, totals.hiredMetres)
        assertEquals(50_000, totals.drivenMetres)
    }

    @Test
    fun odometerCountsDrivingOutsideTrips() {
        val odometer = Odometer()
        val metres = (0..60).sumOf { odometer.add(t0 + it * 1_000L, 32.08 + it * 0.0001, 34.78, 5.0, 11.0) }
        assertTrue(metres in 600..700, "$metres m")
        assertEquals(0, odometer.add(t0 + 61_000, 32.08 + 60 * 0.0001, 34.78, 5.0, 0.0), "standing still adds nothing")
    }
}
