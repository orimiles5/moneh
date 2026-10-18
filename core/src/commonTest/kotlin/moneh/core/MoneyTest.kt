package moneh.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class MoneyTest {
    @Test
    fun addsInMinorUnits() {
        assertEquals(Money(1221), Money(1056) + Money(165))
    }

    @Test
    fun ordersByAmount() {
        assertTrue(Money(1) > Money.ZERO)
    }
}
