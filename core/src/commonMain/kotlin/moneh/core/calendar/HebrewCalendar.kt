package moneh.core.calendar

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.plus

/**
 * Hebrew calendar arithmetic (Dershowitz & Reingold, "Calendrical Calculations").
 * Only what tariffs need: the Gregorian date of Rosh Hashana and the holidays fixed relative to it.
 */
internal object HebrewCalendar {
    private const val PARTS_PER_DAY = 25_920L
    private const val DAYS_FROM_PESACH_TO_ROSH_HASHANA = 163

    // R.D. day number of 1 Tishrei AM 1; R.D. 1 is 0001-01-01 (proleptic Gregorian).
    private const val EPOCH_RD = -1_373_427L
    private val RD_ZERO = LocalDate(1, 1, 1)

    /** Gregorian date of 1 Tishrei of [hebrewYear]. */
    fun roshHashana(hebrewYear: Int): LocalDate = fromRd(EPOCH_RD + elapsedDays(hebrewYear) + yearLengthCorrection(hebrewYear))

    /** Gregorian date of 15 Nisan in [hebrewYear]: always 163 days before the next Rosh Hashana. */
    fun pesach(hebrewYear: Int): LocalDate = roshHashana(hebrewYear + 1).plus(-DAYS_FROM_PESACH_TO_ROSH_HASHANA, DateTimeUnit.DAY)

    /** The Hebrew year that contains [date]. */
    fun yearOf(date: LocalDate): Int {
        val candidate = date.year + 3761
        return if (date < roshHashana(candidate)) candidate - 1 else candidate
    }

    private fun elapsedDays(year: Int): Long {
        val monthsElapsed = (235L * year - 234).floorDiv(19)
        val partsElapsed = 12_084L + 13_753L * monthsElapsed
        val day = 29L * monthsElapsed + partsElapsed.floorDiv(PARTS_PER_DAY)
        return if ((3 * (day + 1)).mod(7) < 3) day + 1 else day
    }

    private fun yearLengthCorrection(year: Int): Long {
        val previous = elapsedDays(year - 1)
        val current = elapsedDays(year)
        val next = elapsedDays(year + 1)
        return when {
            next - current == 356L -> 2
            current - previous == 382L -> 1
            else -> 0
        }
    }

    private fun fromRd(rd: Long): LocalDate = RD_ZERO.plus(rd - 1, DateTimeUnit.DAY)
}
