package moneh.core

import moneh.core.distance.DistanceTracker
import moneh.core.distance.LocationSample
import moneh.core.fare.computeFare
import moneh.core.log.TripLog
import moneh.core.log.decode
import moneh.core.tariff.Tariff
import moneh.core.tariff.Tariffs
import moneh.core.trip.TripEvent
import moneh.core.trip.TripState
import moneh.core.trip.replay
import kotlin.time.Instant

enum class MeterPhase { IDLE, HIRED, PAUSED, STOPPED, SETTLED }

/** Everything a screen needs, in plain types. Money is in minor units. */
data class MeterReading(
    val phase: MeterPhase,
    val currency: String,
    val rateId: String,
    val displayTotal: Long,
    val total: Long,
    val startingFare: Long,
    val timeCharge: Long,
    val distanceCharge: Long,
    val extras: Long,
    val vat: Long,
    val passThrough: Long,
    val chargedSeconds: Long,
    val distanceMetres: Long,
    val vatExempt: Boolean,
    val logHead: String,
)

/**
 * The single entry point the apps use: one trip, driven by plain timestamps (epoch milliseconds) and location fixes.
 * Every event is appended to the hash-chained [entries], which the app persists after each call that returns true.
 *
 * Not thread-safe: call from one thread (the main thread on iOS).
 */
class Meter private constructor(
    private val tariff: Tariff,
    private var state: TripState,
    private var log: TripLog,
) {
    constructor(tariffId: String) : this(Tariffs.bundled.getValue(tariffId), TripState.Idle, TripLog.EMPTY)

    private var tracker = DistanceTracker()

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

    fun hire(
        atMs: Long,
        vatExempt: Boolean,
    ): Boolean = transition { (it as? TripState.Idle)?.hire(at(atMs), tariff.id, vatExempt) }.also { if (it) tracker = DistanceTracker() }

    fun pause(atMs: Long) = transition { (it as? TripState.Hired)?.pause(at(atMs)) }

    fun resume(atMs: Long) = transition { (it as? TripState.Paused)?.resume(at(atMs)) }

    fun stop(atMs: Long) =
        transition {
            when (it) {
                is TripState.Hired -> it.stop(at(atMs))
                is TripState.Paused -> it.stop(at(atMs))
                else -> null
            }
        }

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
        return metres > 0 && transition { (it as? TripState.Hired)?.move(sample.at, metres) }
    }

    fun rateIdAt(nowMs: Long): String = tariff.rateIdAt(Instant.fromEpochMilliseconds(nowMs))

    fun reading(nowMs: Long): MeterReading {
        val hired = state.events.firstOrNull() as? TripEvent.Hired
        val fare = hired?.let { computeFare(tariff, state.events, maxOf(at(nowMs), state.events.last().at)) }
        return MeterReading(
            phase = phase,
            currency = tariff.currency,
            rateId = rateIdAt(nowMs),
            displayTotal = fare?.displayTotal?.minorUnits ?: 0,
            total = fare?.total?.minorUnits ?: 0,
            startingFare = fare?.startingFare?.minorUnits ?: 0,
            timeCharge = fare?.timeCharge?.minorUnits ?: 0,
            distanceCharge = fare?.distanceCharge?.minorUnits ?: 0,
            extras = fare?.extras?.minorUnits ?: 0,
            vat = fare?.vat?.minorUnits ?: 0,
            passThrough = fare?.passThrough?.minorUnits ?: 0,
            chargedSeconds = fare?.chargedTime?.inWholeSeconds ?: 0,
            distanceMetres = fare?.distanceMetres ?: 0,
            vatExempt = hired?.vatExempt ?: false,
            logHead = log.head,
        )
    }

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
