package moneh.core.trip

import kotlin.time.Instant

/** Everything that happens on a trip, in order. The fare is a pure function of these. */
sealed interface TripEvent {
    val at: Instant

    /** [vatExempt] marks a trip in a zone without VAT, such as Eilat; recorded so the fare is reproducible. */
    data class Hired(
        override val at: Instant,
        val tariffVersion: String,
        val vatExempt: Boolean = false,
    ) : TripEvent

    /** Distance travelled since the previous [Moved], in metres, as measured by the distance pipeline. */
    data class Moved(
        override val at: Instant,
        val metres: Long,
    ) : TripEvent

    data class Paused(
        override val at: Instant,
    ) : TripEvent

    data class Resumed(
        override val at: Instant,
    ) : TripEvent

    /** [amountMinorUnits] is set only for extras without a fixed tariff price, such as a toll read off a sign. */
    data class ExtraAdded(
        override val at: Instant,
        val extraId: String,
        val amountMinorUnits: Long? = null,
    ) : TripEvent

    /** Cancels the latest addition of [extraId] still in force. The log is append-only, so a mistake is corrected, not erased. */
    data class ExtraRemoved(
        override val at: Instant,
        val extraId: String,
    ) : TripEvent

    data class Stopped(
        override val at: Instant,
    ) : TripEvent

    data class Settled(
        override val at: Instant,
    ) : TripEvent
}
