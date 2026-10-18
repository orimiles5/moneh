package moneh.core.distance

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertTrue

class DistanceTrackerTest {
    private fun measure(trace: SyntheticTraces.Trace): Long {
        val tracker = DistanceTracker()
        return trace.samples.sumOf(tracker::add)
    }

    private fun assertWithin(
        trace: SyntheticTraces.Trace,
        underPercent: Double,
        overPercent: Double,
    ) {
        val measured = measure(trace)
        val error = (measured - trace.trueMetres) / trace.trueMetres * 100
        assertTrue(error >= -underPercent && error <= overPercent, "measured $measured m vs true ${trace.trueMetres} m ($error%)")
    }

    // A city block loop with four right-angle turns.
    private val cityRoute = listOf(0.0 to 0.0, 400.0 to 0.0, 400.0 to 300.0, 0.0 to 300.0, 0.0 to 600.0, 500.0 to 600.0)

    @Test
    fun highway() {
        repeat(5) { seed ->
            assertWithin(SyntheticTraces.drive(listOf(0.0 to 0.0, 10_000.0 to 0.0), 30.0, 3.0, 5.0, seed), 2.0, 1.0)
        }
    }

    @Test
    fun cityDriving() {
        repeat(5) { seed -> assertWithin(SyntheticTraces.drive(cityRoute, 10.0, 4.0, 8.0, seed), 4.0, 2.0) }
    }

    @Test
    fun urbanCanyonWithMultipathJumps() {
        repeat(5) { seed ->
            assertWithin(SyntheticTraces.drive(cityRoute, 8.0, 12.0, 25.0, seed, outlierEvery = 23), 8.0, 3.0)
        }
    }

    @Test
    fun tunnelIsBridged() {
        repeat(5) { seed ->
            val trace = SyntheticTraces.drive(listOf(0.0 to 0.0, 3_000.0 to 0.0), 20.0, 3.0, 5.0, seed, dropSeconds = 40..110)
            assertWithin(trace, 2.0, 1.0)
        }
    }

    @Test
    fun standingAtALightAddsAlmostNothing() {
        repeat(5) { seed ->
            val measured = measure(SyntheticTraces.stationary(180, 4.0, 8.0, seed))
            assertTrue(measured <= 10, "Standing still for 3 minutes counted $measured m")
        }
    }

    @Test
    fun withoutDopplerSpeedJitterStaysSmall() {
        repeat(5) { seed ->
            val trace = SyntheticTraces.stationary(180, 4.0, 8.0, seed)
            val measured = measure(trace.copy(samples = trace.samples.map { it.copy(speedMetresPerSecond = null) }))
            assertTrue(measured <= 60, "Standing still for 3 minutes without speed counted $measured m")
        }
    }

    @Test
    fun inaccurateFixesAreIgnored() {
        val trace = SyntheticTraces.drive(listOf(0.0 to 0.0, 1_000.0 to 0.0), 10.0, 3.0, 80.0, seed = 1)
        assertTrue(measure(trace) == 0L)
    }

    @Test
    fun metresBetweenMatchesOneDegreeOfLatitude() {
        // One degree along a meridian is pi * R / 180 = 111,195.08 m for the mean Earth radius.
        val a = SyntheticTraces.stationary(1, 0.0, 1.0, 0).samples[0].copy(latitude = 31.0, longitude = 35.0)
        assertTrue(abs(metresBetween(a, a.copy(latitude = 32.0)) - 111_195.08) < 0.01)
    }
}
