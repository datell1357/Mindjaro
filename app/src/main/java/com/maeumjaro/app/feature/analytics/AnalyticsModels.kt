package com.maeumjaro.app.feature.analytics

import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.billing.BillingEntitlementState
import java.time.LocalDate

enum class Entitlement { FREE, PRO }

/** Canonical feature-gate mapping. Only confirmed Pro or an explicitly confirmed cached Pro
 * continuity marker remains unlocked while Billing is unavailable. */
fun BillingEntitlementState.effectiveEntitlement(): Entitlement = when (this) {
    is BillingEntitlementState.Pro -> Entitlement.PRO
    is BillingEntitlementState.Error -> if (cachedPro) Entitlement.PRO else Entitlement.FREE
    is BillingEntitlementState.Unknown -> if (cachedPro) Entitlement.PRO else Entitlement.FREE
    BillingEntitlementState.Free,
    BillingEntitlementState.Pending -> Entitlement.FREE
}

interface EntitlementRepository { suspend fun current(): Entitlement }
class DebugEntitlementRepository(initial: Entitlement = Entitlement.FREE) : EntitlementRepository {
    @Volatile var entitlement: Entitlement = initial
    override suspend fun current(): Entitlement = entitlement
}

sealed interface AccessResult<out T> {
    data class Unlocked<T>(val value: T) : AccessResult<T>
    data object Locked : AccessResult<Nothing>
}

enum class SampleTier { NEEDS_MORE, EARLY, SUMMARY, COMPARISON }
data class AnalyticsPeriod(val plan: Entitlement, val start: LocalDate, val end: LocalDate, val today: LocalDate, val viewportStart: LocalDate) {
    val dates: List<LocalDate> get() = generateSequence(start) { if (it < end) it.plusDays(1) else null }.toList()
    companion object {
        fun forPlan(plan: Entitlement, today: LocalDate): AnalyticsPeriod {
            val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
            if (plan == Entitlement.FREE) return AnalyticsPeriod(plan, today.minusDays(29), today, today, monday.minusWeeks(15))
            return AnalyticsPeriod(plan, today.minusDays(363), today, today, monday.minusWeeks(51))
        }
    }
}

data class DailyAnalytics(val date: LocalDate, val count: Int, val intensitySum: Int) {
    val averageIntensity: Double get() = if (count == 0) 0.0 else intensitySum.toDouble() / count
}
data class PeriodSummary(val count: Int, val intensitySum: Int, val activeDays: Int) {
    val activeDayAverage: Double get() = if (activeDays == 0) 0.0 else count.toDouble() / activeDays
}
data class Comparison(val recent: PeriodSummary, val previous: PeriodSummary)
data class AnalyticsReport(
    val period: AnalyticsPeriod, val daily: List<DailyAnalytics>, val totalCount: Int, val totalIntensity: Int,
    val activeDays: Int, val threeHourCounts: List<Int>, val weekdayCounts: List<Int>, val intensityCounts: List<Int>,
    val sampleTier: SampleTier, val comparison: Comparison?, val peakThreeHourBuckets: List<Int>, val peakWeekdays: List<Int>
)

data class DetailedPatternsResult(val report: AnalyticsReport)
/** Bytes and metadata required by Android Sharesheet; no file is created by the domain layer. */
data class JsonExportResult(
    val bytes: ByteArray,
    val mimeType: String = "application/json",
    val suggestedFileName: String = "maeumjaro-history.json",
)
