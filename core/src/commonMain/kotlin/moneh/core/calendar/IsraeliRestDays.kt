package moneh.core.calendar

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.DayOfWeek
import kotlinx.datetime.LocalDate
import kotlinx.datetime.plus

/**
 * Rest days per Government and Law Procedure Ordinance §18A(a) plus Independence Day,
 * as referenced by the taxi fare order.
 */
object IsraeliRestDays {
    fun isRestDay(date: LocalDate): Boolean = date.dayOfWeek == DayOfWeek.SATURDAY || date in holidays(HebrewCalendar.yearOf(date))

    private fun holidays(hebrewYear: Int): Set<LocalDate> {
        val roshHashana = HebrewCalendar.roshHashana(hebrewYear)
        val pesach = HebrewCalendar.pesach(hebrewYear)
        return setOf(
            roshHashana,
            roshHashana + 1,
            roshHashana + 9, // Yom Kippur
            roshHashana + 14, // Sukkot
            roshHashana + 21, // Shemini Atzeret
            pesach,
            pesach + 6, // Seventh day of Pesach
            pesach + 50, // Shavuot
            independenceDay(pesach + 20),
        )
    }

    /** 5 Iyar moves off Shabbat and its neighbours (Independence Day Law, as amended in 2004). */
    private fun independenceDay(fifthOfIyar: LocalDate): LocalDate =
        when (fifthOfIyar.dayOfWeek) {
            DayOfWeek.FRIDAY -> fifthOfIyar + -1
            DayOfWeek.SATURDAY -> fifthOfIyar + -2
            DayOfWeek.MONDAY -> fifthOfIyar + 1
            else -> fifthOfIyar
        }

    private operator fun LocalDate.plus(days: Int) = plus(days, DateTimeUnit.DAY)
}
