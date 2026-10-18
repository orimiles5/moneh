package moneh.core.tariff

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.minus
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import moneh.core.calendar.DayType
import moneh.core.calendar.IsraeliRestDays
import moneh.core.calendar.dayType
import kotlin.time.Instant

/**
 * A versioned tariff. Prices are in minor units and exclude VAT; [vatBasisPoints] is added on top (1800 = 18%).
 * Time and distance charges are additive (the Israeli model); add a crossover mode when a country needs one.
 */
@Serializable
data class Tariff(
    val id: String,
    val country: String,
    val currency: String,
    val timeZone: String,
    val effectiveFrom: LocalDate,
    val effectiveUntil: LocalDate? = null,
    val sources: List<Source>,
    val vatBasisPoints: Int,
    val restDayCalendar: String,
    /** Tariff days run from this local time to the same time the next day, so 02:00 belongs to the previous day. */
    val dayStartsAt: LocalTime,
    val rates: Map<String, Rate>,
    val schedule: List<ScheduleRule>,
    val extras: Map<String, Extra>,
) {
    @Serializable
    data class Source(
        val title: String,
        val url: String,
    )

    @Serializable
    data class Rate(
        val startingFare: Long,
        val perMinute: Long,
        val perKm: List<DistanceTier>,
    )

    /** [price] per km applies from [fromKm] of cumulative trip distance until the next tier. */
    @Serializable
    data class DistanceTier(
        val fromKm: Int,
        val price: Long,
    )

    /** [days] holds weekday names (e.g. "THURSDAY"), "REST_DAY" or "REST_DAY_EVE". */
    @Serializable
    data class ScheduleRule(
        val days: Set<String>,
        val bands: List<Band>,
    )

    @Serializable
    data class Band(
        val from: LocalTime,
        val rate: String,
    )

    /** A fixed [price], or none for an amount entered at the time and passed through without VAT, such as a toll. */
    @Serializable
    data class Extra(
        val price: Long? = null,
    )

    @Transient
    private val zone = TimeZone.of(timeZone)

    private val isRestDay: (LocalDate) -> Boolean
        get() =
            when (restDayCalendar) {
                "IL" -> IsraeliRestDays::isRestDay
                else -> error("Unknown rest-day calendar $restDayCalendar")
            }

    init {
        require(vatBasisPoints in 0..BASIS_POINTS_PER_WHOLE) { "VAT out of range: $vatBasisPoints" }
        require(effectiveUntil == null || effectiveUntil >= effectiveFrom) { "Tariff ends before it starts" }
        require(sources.isNotEmpty()) { "A tariff must cite its legal source" }
        rates.forEach { (id, rate) ->
            require(rate.startingFare >= 0 && rate.perMinute >= 0) { "Negative price in rate $id" }
            require(rate.perKm.firstOrNull()?.fromKm == 0) { "Rate $id must have a distance tier from 0 km" }
            require(rate.perKm.zipWithNext().all { (a, b) -> a.fromKm < b.fromKm }) { "Rate $id tiers must ascend" }
            require(rate.perKm.all { it.price >= 0 }) { "Negative price in rate $id" }
        }
        schedule.forEach { rule ->
            require(rule.bands.firstOrNull()?.from == dayStartsAt) { "Bands for ${rule.days} must start at $dayStartsAt" }
            require(rule.bands.zipWithNext().all { (a, b) -> offset(a.from) < offset(b.from) }) { "Bands for ${rule.days} must ascend" }
            rule.bands.forEach { require(it.rate in rates) { "Unknown rate ${it.rate}" } }
        }
        require(extras.values.all { (it.price ?: 0) >= 0 }) { "Negative extra price" }
    }

    /** The rate id that applies at [instant]. */
    fun rateIdAt(instant: Instant): String {
        val local = instant.toLocalDateTime(zone)
        val tariffDate = if (local.time < dayStartsAt) local.date.minus(1, DateTimeUnit.DAY) else local.date
        val key =
            when (val type = dayType(tariffDate, isRestDay)) {
                DayType.RestDay -> "REST_DAY"
                DayType.RestDayEve -> "REST_DAY_EVE"
                is DayType.Ordinary -> type.dayOfWeek.name
            }
        val rule = schedule.firstOrNull { key in it.days } ?: error("Tariff $id has no schedule for $key")
        val sinceDayStart = offset(local.time)
        return rule.bands.last { offset(it.from) <= sinceDayStart }.rate
    }

    fun rateAt(instant: Instant): Rate = rates.getValue(rateIdAt(instant))

    private fun offset(time: LocalTime) = (time.toSecondOfDay() - dayStartsAt.toSecondOfDay()).mod(SECONDS_PER_DAY)
}

private const val SECONDS_PER_DAY = 86_400
const val BASIS_POINTS_PER_WHOLE = 10_000
