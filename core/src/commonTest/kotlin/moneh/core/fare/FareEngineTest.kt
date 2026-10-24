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
 * [total] checks that agora-exact sum; the final rounding to 0.10 ₪ has its own tests.
 */
class FareEngineTest {
    private val tariff = Tariffs.bundled.getValue("il-2026-04")
    private val israel = TimeZone.of("Asia/Jerusalem")

    private fun at(local: String): Instant = LocalDateTime.parse(local).toInstant(israel)

    private fun hire(
        local: String,
        vatExempt: Boolean = false,
    ) = TripState.Idle.hire(at(local), tariff.id, vatExempt)

    private fun fare(trip: TripState) = computeFare(tariff, trip.events, trip.events.last().at)

    private fun total(trip: TripState) = fare(trip).let { it.total.minorUnits - it.rounding.minorUnits }

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
    fun removingAnExtraCancelsItsLatestCharge() {
        val trip =
            hire("2026-10-18T10:00")
                .move(at("2026-10-18T10:10"), 5_000)
                .stop(at("2026-10-18T10:10"))
                .addExtra(at("2026-10-18T10:10"), "expressLane", amountMinorUnits = 1200)
                .addExtra(at("2026-10-18T10:10"), "expressLane", amountMinorUnits = 900)
                .addExtra(at("2026-10-18T10:10"), "booking")
                .removeExtra(at("2026-10-18T10:11"), "expressLane")
                .removeExtra(at("2026-10-18T10:11"), "booking")
        assertEquals(4167 + 1200, total(trip))
        assertFailsWith<IllegalArgumentException> { trip.removeExtra(at("2026-10-18T10:11"), "booking") }
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
        val parts = fare.startingFare + fare.timeCharge + fare.distanceCharge + fare.extras + fare.vat + fare.passThrough + fare.rounding
        assertEquals(fare.total, parts)
    }

    @Test
    fun fareAndExtrasAreDisplayedSeparately() {
        // Fare 3531 x 1.18 = 4166.58 -> 41.60 shown; booking 490 x 1.18 = 578.2 -> 5.78, plus a 12.00 toll.
        val trip =
            hire("2026-10-18T10:00")
                .addExtra(at("2026-10-18T10:00"), "booking")
                .move(at("2026-10-18T10:10"), 5_000)
                .stop(at("2026-10-18T10:10"))
                .addExtra(at("2026-10-18T10:10"), "expressLane", amountMinorUnits = 1200)
        assertEquals(4160, fare(trip).displayFare.minorUnits)
        assertEquals(578 + 1200, fare(trip).displayExtras.minorUnits)
    }

    private fun assertAddsUp(fare: moneh.core.fare.FareBreakdown) {
        val lines = fare.startingFare + fare.timeCharge + fare.distanceCharge + fare.extras + fare.vat + fare.passThrough + fare.rounding
        assertEquals(fare.total.minorUnits, lines.minorUnits - fare.discount.minorUnits)
    }

    private val tenMinutesFiveKm get() = hire("2026-10-18T10:00").move(at("2026-10-18T10:10"), 5_000)

    @Test
    fun percentDiscountComesOffTheFare() {
        // 4166.58 less 10% = 3749.92 -> 37.50; the discount line is before VAT: 353.1 -> 3.53.
        val fare = fare(tenMinutesFiveKm.setDiscount(at("2026-10-18T10:10"), basisPoints = 1000).stop(at("2026-10-18T10:10")))
        assertEquals(3750, fare.total.minorUnits)
        assertEquals(353, fare.discount.minorUnits)
        assertAddsUp(fare)
    }

    @Test
    fun latestDiscountCountsAndNeverExceedsTheFare() {
        val trip =
            tenMinutesFiveKm
                .stop(at("2026-10-18T10:10"))
                .setDiscount(at("2026-10-18T10:10"), basisPoints = 1000)
                .setDiscount(at("2026-10-18T10:10"), amountMinorUnits = 100_000)
                .addExtra(at("2026-10-18T10:10"), "expressLane", amountMinorUnits = 1200)
        // The fare is fully discounted, the toll is still paid.
        assertEquals(1200, fare(trip).total.minorUnits)
        assertAddsUp(fare(trip))
    }

    @Test
    fun agreedPriceCapsTheFare() {
        val capped = TripState.Idle.hire(at("2026-10-18T10:00"), tariff.id, agreedPriceMinorUnits = 3000)
        val cappedFare = fare(capped.move(at("2026-10-18T10:10"), 5_000).stop(at("2026-10-18T10:10")))
        assertEquals(3000, cappedFare.total.minorUnits)
        assertEquals(3000, cappedFare.agreedPrice?.minorUnits)
        assertAddsUp(cappedFare)
        // Agreed above the fare: the passenger pays the computed fare.
        val above = TripState.Idle.hire(at("2026-10-18T10:00"), tariff.id, agreedPriceMinorUnits = 5000)
        assertEquals(4170, fare(above.move(at("2026-10-18T10:10"), 5_000).stop(at("2026-10-18T10:10"))).total.minorUnits)
    }

    @Test
    fun invalidDiscountsAreRejected() {
        val trip = hire("2026-10-18T10:00")
        assertFailsWith<IllegalArgumentException> { trip.setDiscount(at("2026-10-18T10:00")) }
        assertFailsWith<IllegalArgumentException> { trip.setDiscount(at("2026-10-18T10:00"), basisPoints = 0) }
        assertFailsWith<IllegalArgumentException> { trip.setDiscount(at("2026-10-18T10:00"), basisPoints = 10, amountMinorUnits = 10) }
    }

    @Test
    fun finalSumGoesToTenAgorot() {
        // 4166.58 -> 4170 (6.58 agorot above 4160 is more than 5); 3193.08 -> 3190; 3531 (Eilat) -> 3530.
        val shortTrip = hire("2026-10-18T10:00").move(at("2026-10-18T10:10"), 5_000).stop(at("2026-10-18T10:10"))
        assertEquals(4170, fare(shortTrip).total.minorUnits)
        assertEquals(3, fare(shortTrip).rounding.minorUnits)
        assertEquals(3190, fare(hire("2026-10-18T10:00").stop(at("2026-10-18T10:10"))).total.minorUnits)
        val eilat = hire("2026-10-18T10:00", vatExempt = true).move(at("2026-10-18T10:10"), 5_000).stop(at("2026-10-18T10:10"))
        assertEquals(3530, fare(eilat).total.minorUnits)
        // Exactly 5 agorot goes down: 1056 + 1 km at 165 = 1221 VAT-free, plus a 4.94 toll = 1715.
        val five =
            hire("2026-10-18T10:00", vatExempt = true)
                .move(at("2026-10-18T10:00"), 1_000)
                .stop(at("2026-10-18T10:00"))
                .addExtra(at("2026-10-18T10:00"), "expressLane", amountMinorUnits = 494)
        assertEquals(1710, fare(five).total.minorUnits)
    }
}
