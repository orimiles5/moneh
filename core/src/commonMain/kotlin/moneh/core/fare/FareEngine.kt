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
    val numerator = subtotal * (BASIS_POINTS_PER_WHOLE + vatBasisPoints) + passThrough * UNITS * BASIS_POINTS_PER_WHOLE
    val denominator = UNITS * BASIS_POINTS_PER_WHOLE
    val total = roundHalfUp(numerator, denominator)

    return FareBreakdown(
        tariffId = tariff.id,
        startingFare = Money(roundHalfUp(starting, UNITS)),
        timeCharge = Money(roundHalfUp(time, UNITS)),
        distanceCharge = Money(roundHalfUp(distance, UNITS)),
        extras = Money(roundHalfUp(extras, UNITS)),
        vat = Money(total - passThrough - roundHalfUp(subtotal, UNITS)),
        passThrough = Money(passThrough),
        total = Money(total),
        displayTotal = Money(numerator / denominator),
        chargedTime = meter.chargedMs.milliseconds,
        distanceMetres = meter.metres,
    )
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

    fun record(event: TripEvent) {
        when (event) {
            is TripEvent.Hired, is TripEvent.Resumed -> runningSince = event.at
            is TripEvent.Paused, is TripEvent.Stopped -> chargeTimeUntil(event.at)
            is TripEvent.Moved -> {
                distance += distanceCharge(tariff.rateAt(event.at), metres, event.metres)
                metres += event.metres
            }
            is TripEvent.ExtraAdded -> addExtra(event)
            is TripEvent.Settled -> Unit
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
        when (val price = extra.price) {
            null -> {
                val amount = requireNotNull(event.amountMinorUnits) { "Extra ${event.extraId} needs an amount" }
                require(amount >= 0) { "Extra ${event.extraId} cannot be negative" }
                passThrough += amount
            }
            else -> extras += price * UNITS
        }
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

private fun roundHalfUp(
    numerator: Long,
    denominator: Long,
) = (numerator + denominator / 2) / denominator
