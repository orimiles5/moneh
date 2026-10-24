package moneh.core.trip

import kotlin.time.Instant

/** Everything that happens on a trip, in order. The fare is a pure function of these. */
sealed interface TripEvent {
    val at: Instant

    /**
     * [vatExempt] marks a trip in a zone without VAT, such as Eilat; recorded so the fare is reproducible.
     * [agreedPriceMinorUnits] is a price agreed before the trip (spec 2018 §9.9): the passenger pays the lower of it and the fare.
     */
    data class Hired(
        override val at: Instant,
        val tariffVersion: String,
        val vatExempt: Boolean = false,
        val agreedPriceMinorUnits: Long? = null,
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

    /** A discount off the fare (spec 2018 §9.10), as [basisPoints] (1000 = 10%) or [amountMinorUnits]. The latest one counts. */
    data class DiscountSet(
        override val at: Instant,
        val basisPoints: Int? = null,
        val amountMinorUnits: Long? = null,
    ) : TripEvent

    data class Stopped(
        override val at: Instant,
    ) : TripEvent

    /** [paymentMethod] is "cash" or "card", for the shift summary (spec 2018 §8.3.1); null if not recorded. */
    data class Settled(
        override val at: Instant,
        val paymentMethod: String? = null,
    ) : TripEvent

    /** What the tax invoice needs beyond the fare (spec 2018 Annex A), fixed in the log when it is issued on entering payment. */
    data class InvoiceIssued(
        override val at: Instant,
        val number: Long,
        val taxiNumber: String,
        val licenceNumber: String,
        val dealerName: String,
        val dealerNumber: String,
        val driverName: String,
        val driverId: String,
    ) : TripEvent
}
