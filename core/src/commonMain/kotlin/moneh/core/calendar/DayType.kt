package moneh.core.calendar

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.DayOfWeek
import kotlinx.datetime.LocalDate
import kotlinx.datetime.plus

/** How a tariff sees a civil date. Precedence: rest day, then eve of a rest day, then the plain weekday. */
sealed interface DayType {
    data object RestDay : DayType

    data object RestDayEve : DayType

    data class Ordinary(
        val dayOfWeek: DayOfWeek,
    ) : DayType
}

fun dayType(
    date: LocalDate,
    isRestDay: (LocalDate) -> Boolean,
): DayType =
    when {
        isRestDay(date) -> DayType.RestDay
        isRestDay(date.plus(1, DateTimeUnit.DAY)) -> DayType.RestDayEve
        else -> DayType.Ordinary(date.dayOfWeek)
    }
