package moneh.core.shift

import moneh.core.MeterPhase
import moneh.core.MeterReading
import moneh.core.distance.DistanceTracker
import moneh.core.distance.LocationSample
import kotlin.time.Instant

/**
 * Every metre the taxi drives during a shift, hired or not, for the shift summary (spec 2018 §8.3.1).
 * Same filtering as the trip meter, so the two agree.
 */
class Odometer {
    private val tracker = DistanceTracker()

    /** Metres added by this fix; [speedMetresPerSecond] below zero means unknown. */
    fun add(
        atMs: Long,
        latitude: Double,
        longitude: Double,
        accuracyMetres: Double,
        speedMetresPerSecond: Double,
    ): Long =
        tracker.add(
            LocationSample(
                Instant.fromEpochMilliseconds(atMs),
                latitude,
                longitude,
                accuracyMetres,
                speedMetresPerSecond.takeIf { it >= 0 },
            ),
        )
}

/** Shift summary and cumulative totals (spec 2018 §8.3.1–8.3.2). Money in minor units, distance in metres. */
data class ShiftTotals(
    val trips: Int,
    val cash: Long,
    val card: Long,
    val income: Long,
    /** Extras as the passenger paid them: with VAT, plus tolls. */
    val extras: Long,
    val hiredMetres: Long,
    val drivenMetres: Long,
) {
    companion object {
        /** Totals over settled trips; [drivenMetres] comes from the [Odometer]. Trips not yet settled are left out. */
        fun of(
            trips: List<MeterReading>,
            drivenMetres: Long,
        ): ShiftTotals {
            val settled = trips.filter { it.phase == MeterPhase.SETTLED }
            return ShiftTotals(
                trips = settled.size,
                cash = settled.filter { it.paymentMethod == "cash" }.sumOf { it.total },
                card = settled.filter { it.paymentMethod == "card" }.sumOf { it.total },
                income = settled.sumOf { it.total },
                extras = settled.sumOf { it.displayExtras },
                hiredMetres = settled.sumOf { it.distanceMetres },
                // GPS noise can make the trips' sum exceed the odometer by a few metres; the odometer is never less.
                drivenMetres = maxOf(drivenMetres, settled.sumOf { it.distanceMetres }),
            )
        }
    }
}
