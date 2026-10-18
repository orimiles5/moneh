package moneh.core.distance

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.time.Instant

data class LocationSample(
    val at: Instant,
    val latitude: Double,
    val longitude: Double,
    /** Radius of 68% confidence, in metres, as reported by the platform. */
    val accuracyMetres: Double,
    /** Doppler speed reported by the platform; far steadier than position when standing still. Null if unavailable. */
    val speedMetresPerSecond: Double? = null,
)

/**
 * Turns raw GPS fixes into chargeable distance. Errs towards undercounting, never overcharging the passenger:
 * - drops fixes less accurate than [maxAccuracyMetres];
 * - rejects fixes implying a speed above [maxSpeedMetresPerSecond] (multipath jumps);
 * - smooths position exponentially ([smoothing] is the weight of each new fix), which shrinks jitter;
 * - counts distance only once the smoothed position has moved [minMoveMetres], or 1.5x the fix's accuracy
 *   if larger, from the last counted point;
 * - counts nothing while the reported speed is below [stationaryMetresPerSecond], so standing at a light adds nothing;
 * - bridges gaps longer than [gapSeconds] (tunnels) with the straight line between the fixes on either side.
 */
class DistanceTracker(
    private val maxAccuracyMetres: Double = 40.0,
    private val maxSpeedMetresPerSecond: Double = 55.0,
    private val minMoveMetres: Double = 8.0,
    private val rejectionsBeforeReanchor: Int = 5,
    private val smoothing: Double = 0.5,
    private val gapSeconds: Double = 10.0,
    private val stationaryMetresPerSecond: Double = 0.5,
) {
    private var anchor: LocationSample? = null
    private var smoothed: LocationSample? = null
    private var lastAccepted: LocationSample? = null
    private var consecutiveRejections = 0
    private var uncountedFraction = 0.0

    /** Whole metres travelled since the previous call, to feed [moneh.core.trip.TripState.Hired.move]. */
    fun add(sample: LocationSample): Long {
        val previous = lastAccepted
        when {
            sample.accuracyMetres > maxAccuracyMetres -> Unit
            previous == null -> start(sample)
            sample.at <= previous.at -> Unit
            impliedSpeed(previous, sample) > maxSpeedMetresPerSecond -> reject(sample)
            else -> return count(sample, secondsBetween(previous, sample))
        }
        return 0
    }

    // A run of "impossible" fixes means the earlier position was the wrong one: restart there without charging.
    private fun reject(sample: LocationSample) {
        if (++consecutiveRejections >= rejectionsBeforeReanchor) start(sample)
    }

    private fun count(
        sample: LocationSample,
        secondsSincePrevious: Double,
    ): Long {
        consecutiveRejections = 0
        lastAccepted = sample
        val position = smooth(sample, afterGap = secondsSincePrevious > gapSeconds)
        val stationary = (sample.speedMetresPerSecond ?: Double.MAX_VALUE) < stationaryMetresPerSecond
        val moved = metresBetween(checkNotNull(anchor), position)
        val threshold = maxOf(minMoveMetres, sample.accuracyMetres * ACCURACY_TO_THRESHOLD)
        return when {
            stationary -> {
                anchor = position
                0
            }
            moved < threshold -> 0
            else -> {
                anchor = position
                val total = moved + uncountedFraction
                total.toLong().also { uncountedFraction = total - it }
            }
        }
    }

    private fun secondsBetween(
        a: LocationSample,
        b: LocationSample,
    ) = (b.at - a.at).inWholeMilliseconds / MS_PER_SECOND

    private fun impliedSpeed(
        a: LocationSample,
        b: LocationSample,
    ) = metresBetween(a, b) / secondsBetween(a, b)

    private fun smooth(
        sample: LocationSample,
        afterGap: Boolean,
    ): LocationSample {
        val previous = smoothed
        val next =
            if (previous == null || afterGap) {
                sample
            } else {
                sample.copy(
                    latitude = previous.latitude + smoothing * (sample.latitude - previous.latitude),
                    longitude = previous.longitude + smoothing * (sample.longitude - previous.longitude),
                )
            }
        smoothed = next
        return next
    }

    private fun start(sample: LocationSample) {
        anchor = sample
        smoothed = sample
        lastAccepted = sample
        consecutiveRejections = 0
    }
}

/** Great-circle distance (haversine); accurate to well under 0.5% at taxi scales. */
fun metresBetween(
    a: LocationSample,
    b: LocationSample,
): Double {
    val lat1 = a.latitude.toRadians()
    val lat2 = b.latitude.toRadians()
    val dLat = lat2 - lat1
    val dLon = (b.longitude - a.longitude).toRadians()
    val h = sin(dLat / 2).let { it * it } + cos(lat1) * cos(lat2) * sin(dLon / 2).let { it * it }
    return 2 * EARTH_RADIUS_METRES * asin(sqrt(h))
}

private fun Double.toRadians() = this * kotlin.math.PI / DEGREES_PER_HALF_TURN

private const val EARTH_RADIUS_METRES = 6_371_008.8
private const val MS_PER_SECOND = 1_000.0
private const val ACCURACY_TO_THRESHOLD = 1.5
private const val DEGREES_PER_HALF_TURN = 180
