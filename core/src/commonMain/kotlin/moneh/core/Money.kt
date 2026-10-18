package moneh.core

import kotlin.jvm.JvmInline

/** An amount in minor currency units (agorot for ILS). Money is never a floating-point number. */
@JvmInline
value class Money(
    val minorUnits: Long,
) : Comparable<Money> {
    operator fun plus(other: Money) = Money(minorUnits + other.minorUnits)

    override fun compareTo(other: Money) = minorUnits.compareTo(other.minorUnits)

    companion object {
        val ZERO = Money(0)
    }
}
