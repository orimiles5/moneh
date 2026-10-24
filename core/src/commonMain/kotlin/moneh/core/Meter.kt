package moneh.core

import moneh.core.distance.DistanceTracker
import moneh.core.distance.LocationSample
import moneh.core.fare.computeFare
import moneh.core.log.TripLog
import moneh.core.log.decode
import moneh.core.tariff.BASIS_POINTS_PER_WHOLE
import moneh.core.tariff.Tariff
import moneh.core.tariff.Tariffs
import moneh.core.trip.TripEvent
import moneh.core.trip.TripState
import moneh.core.trip.extraCount
import moneh.core.trip.replay
import kotlin.time.Instant

enum class MeterPhase { IDLE, HIRED, PAUSED, STOPPED, SETTLED }

/** Everything a screen needs, in plain types. Money is in minor units. */
data class MeterReading(
    val phase: MeterPhase,
    val currency: String,
    val rateId: String,
    val displayTotal: Long,
    val displayFare: Long,
    val displayExtras: Long,
    val total: Long,
    val startingFare: Long,
    val timeCharge: Long,
    val distanceCharge: Long,
    val extras: Long,
    val vat: Long,
    val passThrough: Long,
    /** Final rounding to 0.10 ₪, so the receipt's lines add up to [total]. */
    val rounding: Long,
    val chargedSeconds: Long,
    val distanceMetres: Long,
    val vatExempt: Boolean,
    /** VAT rate applied, in basis points (1800 = 18%); 0 when exempt. */
    val vatBasisPoints: Int,
    /** Epoch milliseconds; 0 until the trip starts or stops. */
    val startedAtMs: Long,
    val stoppedAtMs: Long,
    val logHead: String,
)

/**
 * The single entry point the apps use: one trip, driven by plain timestamps (epoch milliseconds) and location fixes.
 * Every event is appended to the hash-chained [entries], which the app persists after each call that returns true.
 *
 * Not thread-safe: call from one thread (the main thread on iOS).
 */
@Suppress("TooManyFunctions") // The one facade the apps call; splitting it would only move the surface around.
class Meter private constructor(
    private val tariff: Tariff,
    private var state: TripState,
    private var log: TripLog,
) {
    constructor(tariffId: String) : this(Tariffs.bundled.getValue(tariffId), TripState.Idle, TripLog.EMPTY)

    private var tracker = DistanceTracker()

    /** Distance driven since payment began; past [RESUME_AFTER_METRES] the trip goes back to hired. */
    private var metresSinceStop = 0L

    val phase: MeterPhase
        get() =
            when (state) {
                TripState.Idle -> MeterPhase.IDLE
                is TripState.Hired -> MeterPhase.HIRED
                is TripState.Paused -> MeterPhase.PAUSED
                is TripState.Stopped -> MeterPhase.STOPPED
                is TripState.Settled -> MeterPhase.SETTLED
            }

    val entries: List<TripLog.Entry> get() = log.entries

    val tariffId: String get() = tariff.id

    /** Legal sources the tariff was transcribed from, for display. */
    val tariffSources: List<Tariff.Source> get() = tariff.sources

    /** Extras with a tariff price, for [addExtra]. */
    val fixedPriceExtras: List<String> get() =
        tariff.extras
            .filterValues { it.price != null }
            .keys
            .toList()

    /** Extras charged at an amount entered at the time, for [addExtraAmount]. */
    val enteredAmountExtras: List<String> get() =
        tariff.extras
            .filterValues { it.price == null }
            .keys
            .toList()

    /**
     * What the passenger pays for a fixed-price extra, VAT included at the current trip's rate, for display.
     * The fare applies VAT once to the whole total, so the sum of these can differ from the receipt by an agora.
     */
    fun extraPassengerPrice(extraId: String): Long? {
        val price = tariff.extras[extraId]?.price ?: return null
        val vatExempt = (state.events.firstOrNull() as? TripEvent.Hired)?.vatExempt ?: false
        val multiplier = BASIS_POINTS_PER_WHOLE + if (vatExempt) 0 else tariff.vatBasisPoints
        return (price * multiplier + BASIS_POINTS_PER_WHOLE / 2) / BASIS_POINTS_PER_WHOLE
    }

    /** How many times [extraId] was added to the current trip. */
    fun extraCount(extraId: String): Int = state.events.extraCount(extraId)

    fun hire(
        atMs: Long,
        vatExempt: Boolean,
    ): Boolean = transition { (it as? TripState.Idle)?.hire(at(atMs), tariff.id, vatExempt) }.also { if (it) tracker = DistanceTracker() }

    /** Only for a trip paused by an earlier version; the meter states are free, hired and payment, with no pause. */
    fun resume(atMs: Long) = transition { (it as? TripState.Paused)?.resume(at(atMs)) }

    /** Hired to payment (תפוס → תשלום). */
    fun stop(atMs: Long) =
        transition {
            when (it) {
                is TripState.Hired -> it.stop(at(atMs))
                is TripState.Paused -> it.stop(at(atMs))
                else -> null
            }
        }.also { if (it) metresSinceStop = 0 }

    fun settle(atMs: Long) = transition { (it as? TripState.Stopped)?.settle(at(atMs)) }

    /** A fixed-price extra from the tariff. */
    fun addExtra(
        atMs: Long,
        extraId: String,
    ) = addExtra(atMs, extraId, null)

    /** An extra without a tariff price, such as a toll, charged at [amountMinorUnits]. */
    fun addExtraAmount(
        atMs: Long,
        extraId: String,
        amountMinorUnits: Long,
    ) = amountMinorUnits >= 0 && addExtra(atMs, extraId, amountMinorUnits)

    /** Cancels the latest addition of [extraId], for a mistaken tap. False if there is none. */
    fun removeExtra(
        atMs: Long,
        extraId: String,
    ) = state.events.extraCount(extraId) > 0 &&
        transition {
            when (it) {
                is TripState.Hired -> it.removeExtra(at(atMs), extraId)
                is TripState.Paused -> it.removeExtra(at(atMs), extraId)
                is TripState.Stopped -> it.removeExtra(at(atMs), extraId)
                else -> null
            }
        }

    /** [speedMetresPerSecond] below zero means unknown, as CoreLocation reports it. */
    fun location(
        atMs: Long,
        latitude: Double,
        longitude: Double,
        accuracyMetres: Double,
        speedMetresPerSecond: Double,
    ): Boolean {
        val sample = LocationSample(at(atMs), latitude, longitude, accuracyMetres, speedMetresPerSecond.takeIf { it >= 0 })
        val metres = tracker.add(sample)
        if (metres <= 0) return false
        return when (val current = state) {
            is TripState.Hired -> transition { current.move(sample.at, metres) }
            // Spec 2018 §8.1.7: driving on more than 10 m after payment began returns to hired and charges that distance.
            is TripState.Stopped -> {
                metresSinceStop += metres
                metresSinceStop > RESUME_AFTER_METRES && transition { current.resume(sample.at).move(sample.at, metresSinceStop) }
            }
            else -> false
        }
    }

    fun rateIdAt(nowMs: Long): String = tariff.rateIdAt(Instant.fromEpochMilliseconds(nowMs))

    fun reading(nowMs: Long): MeterReading {
        val hired = state.events.firstOrNull() as? TripEvent.Hired ?: return idleReading(nowMs)
        val fare = computeFare(tariff, state.events, maxOf(at(nowMs), state.events.last().at))
        return MeterReading(
            phase = phase,
            currency = tariff.currency,
            rateId = rateIdAt(nowMs),
            displayTotal = fare.displayTotal.minorUnits,
            displayFare = fare.displayFare.minorUnits,
            displayExtras = fare.displayExtras.minorUnits,
            total = fare.total.minorUnits,
            startingFare = fare.startingFare.minorUnits,
            timeCharge = fare.timeCharge.minorUnits,
            distanceCharge = fare.distanceCharge.minorUnits,
            extras = fare.extras.minorUnits,
            vat = fare.vat.minorUnits,
            passThrough = fare.passThrough.minorUnits,
            rounding = fare.rounding.minorUnits,
            chargedSeconds = fare.chargedTime.inWholeSeconds,
            distanceMetres = fare.distanceMetres,
            vatExempt = hired.vatExempt,
            vatBasisPoints = if (hired.vatExempt) 0 else tariff.vatBasisPoints,
            startedAtMs = hired.at.toEpochMilliseconds(),
            stoppedAtMs =
                state.events
                    .lastOrNull { it is TripEvent.Stopped }
                    ?.at
                    ?.toEpochMilliseconds() ?: 0,
            logHead = log.head,
        )
    }

    private fun idleReading(nowMs: Long) =
        MeterReading(
            phase = phase,
            currency = tariff.currency,
            rateId = rateIdAt(nowMs),
            displayTotal = 0,
            displayFare = 0,
            displayExtras = 0,
            total = 0,
            startingFare = 0,
            timeCharge = 0,
            distanceCharge = 0,
            extras = 0,
            vat = 0,
            passThrough = 0,
            rounding = 0,
            chargedSeconds = 0,
            distanceMetres = 0,
            vatExempt = false,
            vatBasisPoints = tariff.vatBasisPoints,
            startedAtMs = 0,
            stoppedAtMs = 0,
            logHead = log.head,
        )

    private fun addExtra(
        atMs: Long,
        extraId: String,
        amount: Long?,
    ): Boolean {
        if (extraId !in tariff.extras || (tariff.extras.getValue(extraId).price == null) != (amount != null)) return false
        return transition {
            when (it) {
                is TripState.Hired -> it.addExtra(at(atMs), extraId, amount)
                is TripState.Paused -> it.addExtra(at(atMs), extraId, amount)
                is TripState.Stopped -> it.addExtra(at(atMs), extraId, amount)
                else -> null
            }
        }
    }

    /** Applies [next] if it is legal from the current state and appends the new events to the log. */
    private fun transition(next: (TripState) -> TripState?): Boolean {
        val updated = next(state) ?: return false
        updated.events.drop(state.events.size).forEach { log = log.append(it) }
        state = updated
        return true
    }

    /** The device clock can step backwards; events must not, so they are clamped to the last event's time. */
    private fun at(epochMs: Long): Instant {
        val instant = Instant.fromEpochMilliseconds(epochMs)
        val last = state.events.lastOrNull()?.at ?: return instant
        return maxOf(instant, last)
    }

    companion object {
        /** Rebuilds an unfinished trip from its persisted log, or returns null if it does not verify or replay. */
        fun restore(entries: List<TripLog.Entry>): Meter? =
            runCatching {
                require(entries.isNotEmpty() && TripLog.firstBrokenEntry(entries) == null)
                val events = entries.map { decode(it.encoded) }
                val hired = events.first() as TripEvent.Hired
                Meter(Tariffs.bundled.getValue(hired.tariffVersion), replay(events), events.fold(TripLog.EMPTY, TripLog::append))
            }.getOrNull()
    }
}

private const val RESUME_AFTER_METRES = 10L
