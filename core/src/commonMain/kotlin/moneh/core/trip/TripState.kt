package moneh.core.trip

import moneh.core.tariff.BASIS_POINTS_PER_WHOLE
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
            vatExempt: Boolean = false,
            agreedPriceMinorUnits: Long? = null,
            source: String? = null,
        ): Hired {
            require(agreedPriceMinorUnits == null || agreedPriceMinorUnits > 0) { "Agreed price must be positive" }
            require(source == null || source in TRIP_SOURCES) { "Unknown trip source $source" }
            return Hired(listOf(TripEvent.Hired(at, tariffVersion, vatExempt, agreedPriceMinorUnits, source)))
        }
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

        fun removeExtra(
            at: Instant,
            extraId: String,
        ) = Hired(events.appendRemoval(at, extraId))

        fun setDiscount(
            at: Instant,
            basisPoints: Int? = null,
            amountMinorUnits: Long? = null,
        ) = Hired(events.appendDiscount(TripEvent.DiscountSet(at, basisPoints, amountMinorUnits)))

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

        fun removeExtra(
            at: Instant,
            extraId: String,
        ) = Paused(events.appendRemoval(at, extraId))

        fun resume(at: Instant) = Hired(events.append(TripEvent.Resumed(at)))

        fun stop(at: Instant) = Stopped(events.append(TripEvent.Stopped(at)))
    }

    /** Payment (תשלום): the meter no longer runs, but extras such as a toll can still be added before payment. */
    data class Stopped internal constructor(
        override val events: List<TripEvent>,
    ) : TripState {
        fun addExtra(
            at: Instant,
            extraId: String,
            amountMinorUnits: Long? = null,
        ) = Stopped(events.append(TripEvent.ExtraAdded(at, extraId, amountMinorUnits)))

        fun removeExtra(
            at: Instant,
            extraId: String,
        ) = Stopped(events.appendRemoval(at, extraId))

        fun setDiscount(
            at: Instant,
            basisPoints: Int? = null,
            amountMinorUnits: Long? = null,
        ) = Stopped(events.appendDiscount(TripEvent.DiscountSet(at, basisPoints, amountMinorUnits)))

        fun settle(
            at: Instant,
            paymentMethod: String? = null,
        ): Settled {
            require(paymentMethod == null || paymentMethod in PAYMENT_METHODS) { "Unknown payment method $paymentMethod" }
            return Settled(events.append(TripEvent.Settled(at, paymentMethod)))
        }

        /** One invoice per trip, issued on first entering payment. */
        fun issueInvoice(invoice: TripEvent.InvoiceIssued): Stopped {
            require(events.none { it is TripEvent.InvoiceIssued }) { "Invoice already issued" }
            require(invoice.number > 0) { "Invoice numbers start at 1" }
            return Stopped(events.append(invoice))
        }

        /** The passenger rides on: back to hired at the same tariff (spec 2018 §8.1.7). */
        fun resume(at: Instant) = Hired(events.append(TripEvent.Resumed(at)))
    }

    data class Settled internal constructor(
        override val events: List<TripEvent>,
    ) : TripState
}

/** Additions of [extraId] still in force: those added minus those removed. */
fun List<TripEvent>.extraCount(extraId: String): Int =
    count { it is TripEvent.ExtraAdded && it.extraId == extraId } - count { it is TripEvent.ExtraRemoved && it.extraId == extraId }

private fun List<TripEvent>.appendRemoval(
    at: Instant,
    extraId: String,
): List<TripEvent> {
    require(extraCount(extraId) > 0) { "No $extraId to remove" }
    return append(TripEvent.ExtraRemoved(at, extraId))
}

val PAYMENT_METHODS = setOf("cash", "card")

val TRIP_SOURCES = setOf("street", "booking", "institutional")

private fun List<TripEvent>.appendDiscount(discount: TripEvent.DiscountSet): List<TripEvent> {
    val percent = discount.basisPoints
    val amount = discount.amountMinorUnits
    require((percent == null) != (amount == null)) { "A discount is a percentage or an amount" }
    require(percent == null || percent in 1..BASIS_POINTS_PER_WHOLE) { "Discount out of range: $percent" }
    require(amount == null || amount > 0) { "Discount must be positive" }
    return append(discount)
}

private fun List<TripEvent>.append(event: TripEvent): List<TripEvent> {
    require(event.at >= last().at) { "Event at ${event.at} is earlier than the previous event at ${last().at}" }
    return this + event
}
