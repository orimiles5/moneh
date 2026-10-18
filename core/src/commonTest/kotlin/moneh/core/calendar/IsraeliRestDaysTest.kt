package moneh.core.calendar

import kotlinx.datetime.DayOfWeek
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class IsraeliRestDaysTest {
    @Test
    fun knownHolidays() {
        listOf(
            "2026-09-12", // Rosh Hashana 5787, day 1
            "2026-09-13", // Rosh Hashana, day 2
            "2026-09-21", // Yom Kippur
            "2026-09-26", // Sukkot
            "2026-10-03", // Shemini Atzeret
            "2026-04-02", // Pesach
            "2026-04-08", // Seventh day of Pesach
            "2026-05-22", // Shavuot
            "2026-04-22", // Independence Day, 5 Iyar on a Wednesday
            "2025-05-01", // Independence Day, moved from Saturday 5 Iyar to Thursday
        ).forEach { assertTrue(IsraeliRestDays.isRestDay(LocalDate.parse(it)), it) }
    }

    @Test
    fun ordinaryDaysAreNotRestDays() {
        // A Sunday, a Pesach intermediate day, and the Friday after Independence Day moved to Thursday.
        listOf("2026-10-18", "2026-04-05", "2025-05-02")
            .forEach { assertFalse(IsraeliRestDays.isRestDay(LocalDate.parse(it)), it) }
    }

    @Test
    fun hebrewYearBoundaries() {
        assertEquals(LocalDate.parse("2026-09-12"), HebrewCalendar.roshHashana(5787))
        assertEquals(5786, HebrewCalendar.yearOf(LocalDate.parse("2026-09-11")))
        assertEquals(5787, HebrewCalendar.yearOf(LocalDate.parse("2026-09-12")))
    }

    @Test
    fun dayTypePrecedence() {
        val isRest = IsraeliRestDays::isRestDay
        assertEquals(DayType.RestDayEve, dayType(LocalDate.parse("2026-10-16"), isRest)) // Friday
        assertEquals(DayType.RestDay, dayType(LocalDate.parse("2026-10-17"), isRest)) // Saturday
        assertEquals(DayType.RestDay, dayType(LocalDate.parse("2026-09-12"), isRest)) // RH day 1 is also an eve
        assertEquals(DayType.RestDayEve, dayType(LocalDate.parse("2026-04-21"), isRest)) // Memorial Day
        assertEquals(DayType.Ordinary(DayOfWeek.THURSDAY), dayType(LocalDate.parse("2026-10-15"), isRest))
    }
}
