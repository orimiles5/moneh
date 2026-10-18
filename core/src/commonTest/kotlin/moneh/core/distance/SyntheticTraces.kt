package moneh.core.distance

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.sqrt
import kotlin.random.Random
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant

/**
 * Synthetic GPS traces with known true distance, standing in for recorded drives until the app can record them (M3).
 * Positions are in metres east/north of a Tel Aviv origin; noise is Gaussian per axis.
 */
internal object SyntheticTraces {
    private const val ORIGIN_LAT = 32.08
    private const val ORIGIN_LON = 34.78
    private const val METRES_PER_DEGREE_LAT = 111_320.0
    private const val DOPPLER_SIGMA = 0.2
    private val start = Instant.parse("2026-10-18T10:00:00Z")

    data class Trace(
        val samples: List<LocationSample>,
        val trueMetres: Double,
    )

    /** Drives [route] (metres east/north) at [speed] m/s, one fix per second. */
    fun drive(
        route: List<Pair<Double, Double>>,
        speed: Double,
        noiseSigma: Double,
        accuracy: Double,
        seed: Int,
        dropSeconds: IntRange? = null,
        outlierEvery: Int? = null,
    ): Trace {
        val random = Random(seed)
        val legs = route.zipWithNext()
        val length = legs.sumOf { (a, b) -> hypot(b.first - a.first, b.second - a.second) }
        val samples = mutableListOf<LocationSample>()
        var second = 0
        while (second * speed <= length) {
            val (x, y) = pointAt(legs, second * speed)
            val dropped = dropSeconds?.contains(second) == true
            if (!dropped) {
                val jump = if (outlierEvery != null && second > 0 && second % outlierEvery == 0) 250.0 else 0.0
                samples +=
                    sample(second, x + gaussian(random) * noiseSigma + jump, y + gaussian(random) * noiseSigma, accuracy, speed, random)
            }
            second++
        }
        return Trace(samples, length)
    }

    fun stationary(
        seconds: Int,
        noiseSigma: Double,
        accuracy: Double,
        seed: Int,
    ): Trace {
        val random = Random(seed)
        return Trace(
            (0 until seconds).map { sample(it, gaussian(random) * noiseSigma, gaussian(random) * noiseSigma, accuracy, 0.0, random) },
            0.0,
        )
    }

    private fun pointAt(
        legs: List<Pair<Pair<Double, Double>, Pair<Double, Double>>>,
        distance: Double,
    ): Pair<Double, Double> {
        var remaining = distance
        for ((a, b) in legs) {
            val leg = hypot(b.first - a.first, b.second - a.second)
            if (remaining <= leg) {
                val t = remaining / leg
                return a.first + t * (b.first - a.first) to a.second + t * (b.second - a.second)
            }
            remaining -= leg
        }
        return legs.last().second
    }

    private fun sample(
        second: Int,
        east: Double,
        north: Double,
        accuracy: Double,
        trueSpeed: Double,
        random: Random,
    ) = LocationSample(
        at = start + second.seconds,
        // Doppler speed: noise of about 0.2 m/s, never negative.
        speedMetresPerSecond = maxOf(0.0, trueSpeed + gaussian(random) * DOPPLER_SIGMA),
        latitude = ORIGIN_LAT + north / METRES_PER_DEGREE_LAT,
        longitude = ORIGIN_LON + east / (METRES_PER_DEGREE_LAT * cos(ORIGIN_LAT * PI / 180)),
        accuracyMetres = accuracy,
    )

    private fun gaussian(random: Random) = sqrt(-2 * ln(1 - random.nextDouble())) * cos(2 * PI * random.nextDouble())

    private fun hypot(
        dx: Double,
        dy: Double,
    ) = sqrt(dx * dx + dy * dy)
}
