package moneh.core.trip

/** Rebuilds a trip's state from its events, enforcing the same transitions as live use. */
internal fun replay(events: List<TripEvent>): TripState =
    events.fold(TripState.Idle as TripState) { state, event ->
        val next =
            when (state) {
                is TripState.Idle ->
                    (event as? TripEvent.Hired)?.let { state.hire(it.at, it.tariffVersion, it.vatExempt, it.agreedPriceMinorUnits) }
                is TripState.Hired -> state.apply(event)
                is TripState.Paused -> state.apply(event)
                is TripState.Stopped -> state.apply(event)
                is TripState.Settled -> null
            }
        next ?: throw IllegalArgumentException("$event cannot follow $state")
    }

private fun TripState.Hired.apply(event: TripEvent): TripState? =
    when (event) {
        is TripEvent.Moved -> move(event.at, event.metres)
        is TripEvent.Paused -> pause(event.at)
        is TripEvent.Stopped -> stop(event.at)
        is TripEvent.ExtraAdded -> addExtra(event.at, event.extraId, event.amountMinorUnits)
        is TripEvent.ExtraRemoved -> removeExtra(event.at, event.extraId)
        is TripEvent.DiscountSet -> setDiscount(event.at, event.basisPoints, event.amountMinorUnits)
        else -> null
    }

private fun TripState.Paused.apply(event: TripEvent): TripState? =
    when (event) {
        is TripEvent.Resumed -> resume(event.at)
        is TripEvent.Stopped -> stop(event.at)
        is TripEvent.ExtraAdded -> addExtra(event.at, event.extraId, event.amountMinorUnits)
        is TripEvent.ExtraRemoved -> removeExtra(event.at, event.extraId)
        else -> null
    }

private fun TripState.Stopped.apply(event: TripEvent): TripState? =
    when (event) {
        is TripEvent.Settled -> settle(event.at, event.paymentMethod)
        is TripEvent.InvoiceIssued -> issueInvoice(event)
        is TripEvent.Resumed -> resume(event.at)
        is TripEvent.ExtraAdded -> addExtra(event.at, event.extraId, event.amountMinorUnits)
        is TripEvent.ExtraRemoved -> removeExtra(event.at, event.extraId)
        is TripEvent.DiscountSet -> setDiscount(event.at, event.basisPoints, event.amountMinorUnits)
        else -> null
    }
