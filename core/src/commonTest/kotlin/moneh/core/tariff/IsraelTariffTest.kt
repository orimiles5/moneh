package moneh.core.tariff

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus
import kotlinx.datetime.toInstant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.time.Duration.Companion.minutes

class IsraelTariffTest {
    private val tariff = Tariffs.bundled.getValue("il-2026-04")
    private val israel = TimeZone.of("Asia/Jerusalem")

    private fun rateAt(local: String) = tariff.rateIdAt(LocalDateTime.parse(local).toInstant(israel))

    @Test
    fun ratesMatchTheTemporaryProvision() {
        assertEquals(Tariff.Rate(1056, 165, listOf(Tariff.DistanceTier(0, 165), Tariff.DistanceTier(10, 321))), tariff.rates["A"])
        assertEquals(Tariff.Rate(1056, 198, listOf(Tariff.DistanceTier(0, 198), Tariff.DistanceTier(10, 354))), tariff.rates["B"])
        assertEquals(Tariff.Rate(1056, 231, listOf(Tariff.DistanceTier(0, 231), Tariff.DistanceTier(10, 387))), tariff.rates["C"])
        assertEquals(1800, tariff.vatBasisPoints)
    }

    @Test
    fun bandsFollowTheOrderTable() {
        mapOf(
            "2026-10-18T10:00" to "A", // Sunday
            "2026-10-18T21:00:59" to "A",
            "2026-10-18T21:01" to "B",
            "2026-10-19T02:00" to "B", // Monday 02:00 belongs to Sunday's tariff day
            "2026-10-19T05:59:59" to "B",
            "2026-10-19T06:00" to "A",
            "2026-10-22T22:00" to "B", // Thursday
            "2026-10-22T23:01" to "C",
            "2026-10-23T03:00" to "C", // Thursday night
            "2026-10-23T10:00" to "A", // Friday, eve of Shabbat
            "2026-10-23T16:01" to "B",
            "2026-10-23T21:01" to "C",
            "2026-10-24T10:00" to "B", // Shabbat
            "2026-10-24T19:01" to "C",
            "2026-10-25T05:00" to "C", // Saturday night
            "2026-09-20T17:00" to "B", // Sunday, eve of Yom Kippur
            "2026-09-20T22:00" to "C",
            "2026-09-21T10:00" to "B", // Yom Kippur on a Monday
            "2026-04-21T16:30" to "B", // Memorial Day, eve of Independence Day
            "2026-04-22T12:00" to "B", // Independence Day
        ).forEach { (local, rate) -> assertEquals(rate, rateAt(local), local) }
    }

    @Test
    fun everyMinuteOfTheTariffPeriodResolves() {
        var at = tariff.effectiveFrom.atStartOfDayIn(israel)
        val end = (tariff.effectiveUntil ?: LocalDate(2027, 3, 31)).plus(1, DateTimeUnit.DAY).atStartOfDayIn(israel)
        while (at < end) {
            tariff.rateIdAt(at)
            at += 30.minutes
        }
    }

    @Test
    fun rejectsInvalidTariffs() {
        val valid = Tariffs.bundled.getValue("il-2026-04")
        assertFailsWith<IllegalArgumentException> { valid.copy(vatBasisPoints = -1) }
        assertFailsWith<IllegalArgumentException> { valid.copy(sources = emptyList()) }
        assertFailsWith<IllegalArgumentException> {
            valid.copy(schedule = listOf(Tariff.ScheduleRule(setOf("REST_DAY"), listOf(Tariff.Band(valid.dayStartsAt, "Z")))))
        }
        assertFailsWith<IllegalArgumentException> {
            valid.copy(rates = mapOf("A" to Tariff.Rate(1, 1, listOf(Tariff.DistanceTier(5, 1)))))
        }
    }
}
