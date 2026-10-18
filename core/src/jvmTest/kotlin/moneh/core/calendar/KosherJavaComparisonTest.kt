package moneh.core.calendar

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.plus
import kotlin.test.Test
import kotlin.test.assertEquals
import java.time.LocalDate as JavaLocalDate

class KosherJavaComparisonTest {
    @Test
    fun restDaysMatchKosherJavaFor2000To2100() {
        var date = LocalDate(2000, 1, 1)
        val end = LocalDate(2100, 12, 31)
        while (date <= end) {
            val reference =
                JewishCalendar(JavaLocalDate.of(date.year, date.month.ordinal + 1, date.day)).apply {
                    inIsrael = true
                    isUseModernHolidays = true
                }
            val expected = reference.isAssurBemelacha || reference.yomTovIndex == JewishCalendar.YOM_HAATZMAUT
            assertEquals(expected, IsraeliRestDays.isRestDay(date), date.toString())
            date = date.plus(1, DateTimeUnit.DAY)
        }
    }
}
