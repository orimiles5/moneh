package moneh.core.fare

import moneh.core.Money
import moneh.core.tariff.BASIS_POINTS_PER_WHOLE
import moneh.core.tariff.Tariff
import moneh.core.trip.TripEvent
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Instant

/**
 * The fare as a pure function of the tariff and the trip's events, as of [asOf].
 * Time is charged while hired and not paused; each millisecond and each metre at the rate of the band it falls in.
 * Time and distance are additive. Distance tiers follow cumulative trip distance.
 */
fun computeFare(
    tariff: Tariff,
    events: List<TripEvent>,
    asOf: Instant,
): FareBreakdown {
    val hired = events.firstOrNull() as? TripEvent.Hired ?: throw IllegalArgumentException("A trip starts with Hired")
    require(hired.tariffVersion == tariff.id) { "Trip uses tariff ${hired.tariffVersion}, not ${tariff.id}" }

    val meter = Meter(tariff, asOf)
    events.takeWhile { it.at <= asOf }.forEach(meter::record)
    meter.chargeTimeUntil(asOf)

    val starting = tariff.rateAt(hired.at).startingFare * UNITS
    val time = meter.time
    val distance = meter.distance
    val extras = meter.extras
    val passThrough = meter.passThrough
    val subtotal = starting + time + distance + extras
    val vatBasisPoints = if (hired.vatExempt) 0 else tariff.vatBasisPoints
    val withVat = BASIS_POINTS_PER_WHOLE + vatBasisPoints
    val undiscounted = subtotal * withVat + passThrough * UNITS * BASIS_POINTS_PER_WHOLE
    val denominator = UNITS * BASIS_POINTS_PER_WHOLE
    val discounted = discount(subtotal * withVat, undiscounted, denominator, meter.discount, hired.agreedPriceMinorUnits)
    val numerator = undiscounted - discounted
    val exact = roundHalfUp(numerator, denominator)
    val total = roundToTenAgorot(numerator, denominator)
    val startingLine = roundHalfUp(starting, UNITS)
    val timeLine = roundHalfUp(time, UNITS)
    val distanceLine = roundHalfUp(distance, UNITS)
    val extrasLine = roundHalfUp(extras, UNITS)
    val discountLine = roundHalfUp(discounted, UNITS * withVat)

    return FareBreakdown(
        tariffId = tariff.id,
        startingFare = Money(startingLine),
        timeCharge = Money(timeLine),
        distanceCharge = Money(distanceLine),
        extras = Money(extrasLine),
        // Absorbs the line items' rounding (at most a few agorot) so a printed breakdown always adds up to the total.
        discount = Money(discountLine),
        vat = Money(exact - passThrough - startingLine - timeLine - distanceLine - extrasLine + discountLine),
        passThrough = Money(passThrough),
        rounding = Money(total - exact),
        total = Money(total),
        displayTotal = Money(numerator / (denominator * TEN_AGOROT) * TEN_AGOROT),
        agreedPrice = hired.agreedPriceMinorUnits?.let(::Money),
        displayFare = Money((starting + time + distance) * withVat / (denominator * TEN_AGOROT) * TEN_AGOROT),
        displayExtras = Money(roundHalfUp(extras * withVat, denominator) + passThrough),
        chargedTime = meter.chargedMs.milliseconds,
        distanceMetres = meter.metres,
    )
}

/**
 * The discount in [numerator] units: the latest discount (spec 2018 §9.10), then, if the fare still exceeds an agreed price,
 * the difference (§9.9). Neither takes off more than [fare], the VAT-inclusive charges before tolls.
 */
private fun discount(
    fare: Long,
    numerator: Long,
    denominator: Long,
    discount: TripEvent.DiscountSet?,
    agreedPrice: Long?,
): Long {
    val requested =
        when {
            discount?.basisPoints != null -> fare * discount.basisPoints / BASIS_POINTS_PER_WHOLE
            discount?.amountMinorUnits != null -> discount.amountMinorUnits * denominator
            else -> 0
        }
    var off = minOf(requested, fare)
    if (agreedPrice != null) off = maxOf(off, numerator - agreedPrice * denominator)
    return off.coerceIn(0, fare)
}

/** Accumulates exact charges event by event. */
private class Meter(
    private val tariff: Tariff,
    private val asOf: Instant,
) {
    var time = 0L
    var distance = 0L
    var extras = 0L
    var passThrough = 0L
    var chargedMs = 0L
    var metres = 0L
    private var runningSince: Instant? = null
    var discount: TripEvent.DiscountSet? = null

    /** Per extra, the charges in force, latest last, so a removal cancels exactly what the latest addition charged. */
    private val charged = mutableMapOf<String, ArrayDeque<Charge>>()

    private class Charge(
        val exact: Long,
        val passThrough: Long,
    )

    fun record(event: TripEvent) {
        when (event) {
            is TripEvent.Hired, is TripEvent.Resumed -> runningSince = event.at
            is TripEvent.Paused, is TripEvent.Stopped -> chargeTimeUntil(event.at)
            is TripEvent.Moved -> {
                distance += distanceCharge(tariff.rateAt(event.at), metres, event.metres)
                metres += event.metres
            }
            is TripEvent.ExtraAdded -> addExtra(event)
            is TripEvent.ExtraRemoved -> removeExtra(event)
            is TripEvent.DiscountSet -> discount = event
            is TripEvent.Settled, is TripEvent.InvoiceIssued, is TripEvent.Shared -> Unit
        }
    }

    fun chargeTimeUntil(end: Instant) {
        val start = runningSince ?: return
        val (charge, ms) = timeCharge(tariff, start, minOf(end, asOf))
        time += charge
        chargedMs += ms
        runningSince = null
    }

    private fun addExtra(event: TripEvent.ExtraAdded) {
        val extra = tariff.extras[event.extraId] ?: throw IllegalArgumentException("Unknown extra ${event.extraId}")
        val charge =
            when (val price = extra.price) {
                null -> {
                    val amount = requireNotNull(event.amountMinorUnits) { "Extra ${event.extraId} needs an amount" }
                    require(amount >= 0) { "Extra ${event.extraId} cannot be negative" }
                    Charge(exact = 0, passThrough = amount)
                }
                else -> Charge(exact = price * UNITS, passThrough = 0)
            }
        charged.getOrPut(event.extraId) { ArrayDeque() }.addLast(charge)
        extras += charge.exact
        passThrough += charge.passThrough
    }

    private fun removeExtra(event: TripEvent.ExtraRemoved) {
        val charge = requireNotNull(charged[event.extraId]?.removeLastOrNull()) { "No ${event.extraId} to remove" }
        extras -= charge.exact
        passThrough -= charge.passThrough
    }
}

/** Exact sub-units per minor unit: lets per-millisecond time (rate/60,000) and per-metre distance (rate/1,000) stay integral. */
private const val UNITS = 60_000L
private const val METRES_PER_KM = 1_000L
private const val UNITS_PER_METRE_PRICE = UNITS / METRES_PER_KM

// ponytail: steps minute by minute (band edges are whole local minutes), O(trip minutes) per call;
// compute band edges directly if this shows up in profiles.
private fun timeCharge(
    tariff: Tariff,
    from: Instant,
    until: Instant,
): Pair<Long, Long> {
    var charge = 0L
    var ms = 0L
    var cursor = from
    while (cursor < until) {
        val nextMinute = Instant.fromEpochMilliseconds((cursor.toEpochMilliseconds() / MS_PER_MINUTE + 1) * MS_PER_MINUTE)
        val pieceEnd = minOf(nextMinute, until)
        val pieceMs = (pieceEnd - cursor).inWholeMilliseconds
        charge += pieceMs * tariff.rateAt(cursor).perMinute
        ms += pieceMs
        cursor = pieceEnd
    }
    return charge to ms
}

private val MS_PER_MINUTE = 1.minutes.inWholeMilliseconds

private fun distanceCharge(
    rate: Tariff.Rate,
    metresBefore: Long,
    metres: Long,
): Long {
    var charge = 0L
    rate.perKm.forEachIndexed { index, tier ->
        val tierStart = tier.fromKm * METRES_PER_KM
        val tierEnd =
            rate.perKm
                .getOrNull(index + 1)
                ?.fromKm
                ?.times(METRES_PER_KM) ?: Long.MAX_VALUE
        val overlap = minOf(metresBefore + metres, tierEnd) - maxOf(metresBefore, tierStart)
        if (overlap > 0) charge += overlap * tier.price * UNITS_PER_METRE_PRICE
    }
    return charge
}

/** Spec 2018 §8.2.3: the final sum goes to 0.10 ₪, up to 5 agorot down and above 5 up (24.67 → 24.70, 24.23 → 24.20). */
private fun roundToTenAgorot(
    numerator: Long,
    denominator: Long,
): Long {
    val step = denominator * TEN_AGOROT
    val tens = numerator / step
    return (if (numerator % step > denominator * TEN_AGOROT / 2) tens + 1 else tens) * TEN_AGOROT
}

private const val TEN_AGOROT = 10L

private fun roundHalfUp(
    numerator: Long,
    denominator: Long,
) = (numerator + denominator / 2) / denominator
