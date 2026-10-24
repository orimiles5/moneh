package moneh.core.fare

import moneh.core.Money
import kotlin.time.Duration

data class FareBreakdown(
    val tariffId: String,
    /** Line items exclude VAT and are each rounded half-up; with [vat], [passThrough] and [rounding] they sum exactly to [total]. */
    val startingFare: Money,
    val timeCharge: Money,
    val distanceCharge: Money,
    val extras: Money,
    val vat: Money,
    /** Amounts such as tolls, charged as entered with no VAT. */
    val passThrough: Money,
    /** The difference between [total] and the exact sum rounded to the agora; at most 5 agorot either way. */
    val rounding: Money,
    /** What the passenger pays: computed exactly, then rounded once to 0.10 ₪ as the meter spec requires. */
    val total: Money,
    /** The running fare to show while the meter runs: rounded down to 0.10 ₪, so it never exceeds [total]. */
    val displayTotal: Money,
    val chargedTime: Duration,
    val distanceMetres: Long,
)
