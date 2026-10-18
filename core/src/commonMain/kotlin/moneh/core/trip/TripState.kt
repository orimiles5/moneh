package moneh.core.trip

import kotlin.time.Instant

/**
 * idle → hired ⇄ paused → stopped → settled.
 * Each state exposes only its legal transitions, so an illegal one does not compile.
 * Events must arrive in time order; a transition dated before the last event is rejected.
 */
sealed interface TripState {
    val events: List<TripEvent>

    data object Idle : TripState {
        override val events: List<TripEvent> = emptyList()

        fun hire(
            at: Instant,
            tariffVersion: String,
        ) = Hired(listOf(TripEvent.Hired(at, tariffVersion)))
    }

    data class Hired internal constructor(
        override val events: List<TripEvent>,
    ) : TripState {
        fun move(
            at: Instant,
            metres: Long,
        ): Hired {
            require(metres >= 0) { "Distance cannot be negative" }
            return Hired(events.append(TripEvent.Moved(at, metres)))
        }

        fun addExtra(
            at: Instant,
            extraId: String,
            amountMinorUnits: Long? = null,
        ) = Hired(events.append(TripEvent.ExtraAdded(at, extraId, amountMinorUnits)))

        fun pause(at: Instant) = Paused(events.append(TripEvent.Paused(at)))

        fun stop(at: Instant) = Stopped(events.append(TripEvent.Stopped(at)))
    }

    data class Paused internal constructor(
        override val events: List<TripEvent>,
    ) : TripState {
        fun addExtra(
            at: Instant,
            extraId: String,
            amountMinorUnits: Long? = null,
        ) = Paused(events.append(TripEvent.ExtraAdded(at, extraId, amountMinorUnits)))

        fun resume(at: Instant) = Hired(events.append(TripEvent.Resumed(at)))

        fun stop(at: Instant) = Stopped(events.append(TripEvent.Stopped(at)))
    }

    /** The meter no longer runs, but extras such as a toll can still be added before payment. */
    data class Stopped internal constructor(
        override val events: List<TripEvent>,
    ) : TripState {
        fun addExtra(
            at: Instant,
            extraId: String,
            amountMinorUnits: Long? = null,
        ) = Stopped(events.append(TripEvent.ExtraAdded(at, extraId, amountMinorUnits)))

        fun settle(at: Instant) = Settled(events.append(TripEvent.Settled(at)))
    }

    data class Settled internal constructor(
        override val events: List<TripEvent>,
    ) : TripState
}

private fun List<TripEvent>.append(event: TripEvent): List<TripEvent> {
    require(event.at >= last().at) { "Event at ${event.at} is earlier than the previous event at ${last().at}" }
    return this + event
}
