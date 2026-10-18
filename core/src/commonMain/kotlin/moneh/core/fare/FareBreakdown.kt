package moneh.core.fare

import moneh.core.Money
import kotlin.time.Duration

data class FareBreakdown(
    val tariffId: String,
    /** Line items exclude VAT and are each rounded half-up for display. */
    val startingFare: Money,
    val timeCharge: Money,
    val distanceCharge: Money,
    val extras: Money,
    val vat: Money,
    /** Amounts such as tolls, charged as entered with no VAT. */
    val passThrough: Money,
    /** What the passenger pays: computed exactly, rounded half-up once. */
    val total: Money,
    /** The running fare to show while the meter runs: rounded down, so it never exceeds [total]. */
    val displayTotal: Money,
    val chargedTime: Duration,
    val distanceMetres: Long,
)
