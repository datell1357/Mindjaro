package com.maeumjaro.app.feature.analytics

import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.data.local.StoredDateRange
import java.time.LocalDate
import java.time.ZoneOffset

object AnalyticsAggregator {
    fun aggregate(events: List<StoredInjectionEvent>, period: AnalyticsPeriod): AnalyticsReport {
        val valid = events.filter { it.eventLocalDate in period.start..period.end && it.eventLocalDate <= period.today && it.timezoneOffsetMinutes in -720..840 }
        val byDate = valid.groupingBy { it.eventLocalDate }.eachCount()
        val intensityByDate = valid.groupingBy { it.eventLocalDate }.fold(0) { sum, e -> sum + e.intensity.value }
        val daily = period.dates.map { DailyAnalytics(it, byDate[it] ?: 0, intensityByDate[it] ?: 0) }
        val buckets = IntArray(8); val weekdays = IntArray(7); val intensities = IntArray(5)
        valid.forEach { event ->
            val localHour = event.completedAtUtc.atOffset(ZoneOffset.ofTotalSeconds(event.timezoneOffsetMinutes * 60)).hour
            buckets[(localHour / 3).coerceIn(0, 7)]++
            weekdays[event.eventLocalDate.dayOfWeek.value - 1]++
            intensities[event.intensity.value - 1]++
        }
        val tier = when (valid.size) { in 0..4 -> SampleTier.NEEDS_MORE; in 5..9 -> SampleTier.EARLY; in 10..29 -> SampleTier.SUMMARY; else -> SampleTier.COMPARISON }
        val patternsAvailable = valid.size >= 10
        val comparison = if (tier == SampleTier.COMPARISON && period.plan == Entitlement.PRO) {
            val recentStart = period.today.minusDays(27)
            Comparison(summary(valid, recentStart, period.today), summary(valid, recentStart.minusDays(28), recentStart.minusDays(1)))
        } else null
        return AnalyticsReport(period, daily, valid.size, valid.sumOf { it.intensity.value }, byDate.keys.size,
            if (patternsAvailable) buckets.toList() else emptyList(),
            if (patternsAvailable) weekdays.toList() else emptyList(),
            if (patternsAvailable) intensities.toList() else emptyList(), tier, comparison,
            if (patternsAvailable) peaks(buckets) else emptyList(),
            if (patternsAvailable) peaks(weekdays) else emptyList())
    }
    private fun summary(events: List<StoredInjectionEvent>, start: LocalDate, end: LocalDate): PeriodSummary {
        val inRange = events.filter { it.eventLocalDate in start..end }
        return PeriodSummary(inRange.size, inRange.sumOf { it.intensity.value }, inRange.map { it.eventLocalDate }.toSet().size)
    }
    private fun peaks(values: IntArray): List<Int> { val max = values.maxOrNull() ?: 0; return if (max == 0) emptyList() else values.indices.filter { values[it] == max } }
}

class VisibleHistoryRange(private val entitlements: EntitlementRepository) {
    suspend fun resolve(today: LocalDate): AnalyticsPeriod = AnalyticsPeriod.forPlan(entitlements.current(), today)
}
class DetailedPatterns(private val repository: com.maeumjaro.app.data.local.InjectionEventRepository, private val entitlements: EntitlementRepository) {
    suspend fun execute(today: LocalDate): AccessResult<DetailedPatternsResult> {
        if (entitlements.current() != Entitlement.PRO) return AccessResult.Locked
        val period = AnalyticsPeriod.forPlan(Entitlement.PRO, today)
        return AccessResult.Unlocked(DetailedPatternsResult(AnalyticsAggregator.aggregate(repository.eventsInStoredDateRange(StoredDateRange(period.start, period.end)), period)))
    }
}
