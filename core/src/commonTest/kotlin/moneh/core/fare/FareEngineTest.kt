package moneh.core.fare

import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import moneh.core.tariff.Tariffs
import moneh.core.trip.TripState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Instant

/**
 * Expected totals are hand-computed from il-2026-04 (VAT-exclusive agorot, then x1.18 rounded half-up), e.g.
 * 1056 + 10 min x 165 + 5 km x 165 = 3531; 3531 x 1.18 = 4166.58 -> 4167.
 */
class FareEngineTest {
    private val tariff = Tariffs.bundled.getValue("il-2026-04")
    private val israel = TimeZone.of("Asia/Jerusalem")

    private fun at(local: String): Instant = LocalDateTime.parse(local).toInstant(israel)

    private fun hire(
        local: String,
        vatExempt: Boolean = false,
    ) = TripState.Idle.hire(at(local), tariff.id, vatExempt)

    private fun total(trip: TripState) = computeFare(tariff, trip.events, trip.events.last().at).total.minorUnits

    @Test
    fun shortDaytimeTrip() {
        val trip = hire("2026-10-18T10:00").move(at("2026-10-18T10:10"), 5_000).stop(at("2026-10-18T10:10"))
        assertEquals(4167, total(trip))
    }

    @Test
    fun beyondTenKmTheSecondDistanceTierApplies() {
        // 1056 + 20 x 165 + 10 x 165 + 5 x 321 = 7611 -> 8980.98
        val trip = hire("2026-10-18T10:00").move(at("2026-10-18T10:20"), 15_000).stop(at("2026-10-18T10:20"))
        assertEquals(8981, total(trip))
    }

    @Test
    fun saturdayNightIsTariffC() {
        // 1056 + 10 x 231 + 3 x 231 = 4059 -> 4789.62
        val trip = hire("2026-10-24T20:00").move(at("2026-10-24T20:10"), 3_000).stop(at("2026-10-24T20:10"))
        assertEquals(4790, total(trip))
    }

    @Test
    fun rateSwitchesAtTheBandBoundaryMidTrip() {
        // Sunday 20:55-21:01 at A (6 x 165), 21:01-21:05 at B (4 x 198): 1056 + 990 + 792 = 2838 -> 3348.84
        val trip = hire("2026-10-18T20:55").stop(at("2026-10-18T21:05"))
        assertEquals(3349, total(trip))
    }

    @Test
    fun distanceTierIsCumulativeAcrossBands() {
        // Time: 11 min A (1815) + 9 min B (1782). Distance: 6 km at A (990), then at B 4 km x 198 (792) + 2 km x 354 (708).
        // 1056 + 1815 + 1782 + 990 + 792 + 708 = 7143 -> 8428.74
        val trip =
            hire("2026-10-18T20:50")
                .move(at("2026-10-18T20:59"), 6_000)
                .move(at("2026-10-18T21:02"), 6_000)
                .stop(at("2026-10-18T21:10"))
        assertEquals(8429, total(trip))
    }

    @Test
    fun bookingAndAirportExtras() {
        // 1056 + 30 x 165 + 10 x 165 + 10 x 321 + 490 + 424 = 11780 -> 13900.4
        val trip =
            hire("2026-10-18T10:00")
                .addExtra(at("2026-10-18T10:00"), "booking")
                .addExtra(at("2026-10-18T10:00"), "airportBenGurion")
                .move(at("2026-10-18T10:30"), 20_000)
                .stop(at("2026-10-18T10:30"))
        assertEquals(13900, total(trip))
    }

    @Test
    fun eveOfShabbatAfternoonIsTariffB() {
        // 1056 + 10 x 198 = 3036 -> 3582.48
        assertEquals(3582, total(hire("2026-10-23T16:30").stop(at("2026-10-23T16:40"))))
    }

    @Test
    fun eilatPaysNoVat() {
        val trip = hire("2026-10-18T10:00", vatExempt = true).move(at("2026-10-18T10:10"), 5_000).stop(at("2026-10-18T10:10"))
        assertEquals(3531, total(trip))
    }

    @Test
    fun pausedTimeIsNotCharged() {
        // 10 charged minutes: 1056 + 1650 = 2706 -> 3193.08
        val trip =
            hire("2026-10-18T10:00")
                .pause(at("2026-10-18T10:05"))
                .resume(at("2026-10-18T10:15"))
                .stop(at("2026-10-18T10:20"))
        assertEquals(3193, total(trip))
        assertEquals(10.minutes, computeFare(tariff, trip.events, at("2026-10-18T10:20")).chargedTime)
    }

    @Test
    fun tollPassesThroughWithoutVat() {
        val trip =
            hire("2026-10-18T10:00")
                .move(at("2026-10-18T10:10"), 5_000)
                .stop(at("2026-10-18T10:10"))
                .addExtra(at("2026-10-18T10:10"), "expressLane", amountMinorUnits = 1200)
        assertEquals(4167 + 1200, total(trip))
    }

    @Test
    fun negativeTollIsRejected() {
        val trip = hire("2026-10-18T10:00").stop(at("2026-10-18T10:10")).addExtra(at("2026-10-18T10:10"), "expressLane", -500)
        assertFailsWith<IllegalArgumentException> { total(trip) }
    }

    @Test
    fun breakdownAddsUpToTotal() {
        val trip =
            hire("2026-10-18T20:50")
                .addExtra(at("2026-10-18T20:50"), "booking")
                .move(at("2026-10-18T21:02"), 12_345)
                .stop(at("2026-10-18T21:10"))
                .addExtra(at("2026-10-18T21:10"), "expressLane", amountMinorUnits = 777)
        val fare = computeFare(tariff, trip.events, at("2026-10-18T21:10"))
        val parts = fare.startingFare + fare.timeCharge + fare.distanceCharge + fare.extras + fare.vat + fare.passThrough
        // Line items are rounded individually, so they may differ from the exactly computed total by at most one agora each.
        assertEquals(fare.total.minorUnits.toDouble(), parts.minorUnits.toDouble(), absoluteTolerance = 4.0)
    }
}
