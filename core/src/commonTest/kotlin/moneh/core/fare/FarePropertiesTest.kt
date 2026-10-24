package moneh.core.fare

import moneh.core.tariff.Tariffs
import moneh.core.trip.TripEvent
import moneh.core.trip.TripState
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant

class FarePropertiesTest {
    private val tariff = Tariffs.bundled.getValue("il-2026-04")
    private val periodStart = Instant.parse("2026-04-01T00:00:00Z").epochSeconds
    private val periodEnd = Instant.parse("2027-03-30T00:00:00Z").epochSeconds

    private fun randomTrip(random: Random): TripState.Stopped {
        var now = Instant.fromEpochSeconds(random.nextLong(periodStart, periodEnd))
        var hired: TripState.Hired = TripState.Idle.hire(now, tariff.id)
        repeat(random.nextInt(1, 40)) {
            now += random.nextLong(1, 600).seconds
            hired =
                when (random.nextInt(4)) {
                    0 -> hired.pause(now).also { now += random.nextLong(1, 600).seconds }.resume(now)
                    1 -> hired.addExtra(now, "highway6")
                    else -> hired.move(now, random.nextLong(0, 3_000))
                }
        }
        return hired.stop(now + random.nextLong(0, 600).seconds)
    }

    @Test
    fun fareNeverDecreasesAsTheTripProgresses() {
        val random = Random(42)
        repeat(200) {
            val trip = randomTrip(random)
            val start = trip.events.first().at
            val end = trip.events.last().at
            var previous = -1L
            var asOf = start
            while (asOf <= end) {
                val fare = computeFare(tariff, trip.events, asOf)
                assertTrue(fare.displayTotal.minorUnits >= previous, "Fare dropped at $asOf")
                assertTrue(fare.displayTotal <= fare.total)
                previous = fare.displayTotal.minorUnits
                asOf += 37.seconds
            }
        }
    }

    @Test
    fun splittingDistanceDoesNotChangeTheFare() {
        val random = Random(7)
        repeat(200) {
            val trip = randomTrip(random)
            val split =
                trip.events.flatMap { event ->
                    if (event is TripEvent.Moved && event.metres > 1) {
                        val part = event.metres / 3
                        listOf(event.copy(metres = part), event.copy(metres = event.metres - part))
                    } else {
                        listOf(event)
                    }
                }
            val end = trip.events.last().at
            assertEquals(computeFare(tariff, trip.events, end).total, computeFare(tariff, split, end).total)
        }
    }

    @Test
    fun breakdownAlwaysAddsUpAndVatStaysWithinAFewAgorotOfTheRate() {
        val random = Random(11)
        repeat(300) {
            val trip = randomTrip(random)
            val fare = computeFare(tariff, trip.events, trip.events.last().at)
            val lines = fare.startingFare + fare.timeCharge + fare.distanceCharge + fare.extras
            assertEquals(fare.total, lines + fare.vat + fare.passThrough + fare.rounding)
            assertTrue(fare.total.minorUnits % 10 == 0L && kotlin.math.abs(fare.rounding.minorUnits) <= 5)
            val exactVat = lines.minorUnits * tariff.vatBasisPoints / 10_000.0
            assertTrue(kotlin.math.abs(fare.vat.minorUnits - exactVat) <= 4, "VAT ${fare.vat} vs $exactVat")
        }
    }

    @Test
    fun nothingIsChargedAfterTheMeterStops() {
        val random = Random(3)
        repeat(100) {
            val trip = randomTrip(random)
            val end = trip.events.last().at
            assertEquals(computeFare(tariff, trip.events, end), computeFare(tariff, trip.events, end + 3_600.seconds))
        }
    }
}
