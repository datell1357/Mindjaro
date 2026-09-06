package com.maeumjaro.app.feature.analytics

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.data.local.StoredInjectionEvent
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AnalyticsAggregatorTest {
    @Test fun `stored local date drives weekday while offset drives time bucket`() {
        val day = LocalDate.of(2026, 9, 7) // Monday
        val event = event(day, "2026-09-06T23:30:00Z", offsetMinutes = 120, intensity = 5)
        val report = AnalyticsAggregator.aggregate(
            listOf(event) + List(9) { event(day, "2026-09-06T23:30:00Z", offsetMinutes = 600, intensity = 1) },
            AnalyticsPeriod.forPlan(Entitlement.PRO, day),
        )
        assertEquals(10, report.weekdayCounts[0])
        assertEquals(1, report.threeHourCounts[0]) // 01:30 local
        assertEquals(1, report.intensityCounts[4])
    }

    @Test fun `future local dates are excluded and empty days remain represented`() {
        val today = LocalDate.of(2026, 9, 7)
        val report = AnalyticsAggregator.aggregate(listOf(event(today.plusDays(1), "2026-09-08T00:00:00Z", 0, 1)), AnalyticsPeriod.forPlan(Entitlement.FREE, today))
        assertEquals(0, report.totalCount)
        assertEquals(30, report.daily.size)
        assertEquals(SampleTier.NEEDS_MORE, report.sampleTier)
    }

    @Test fun `pro list is rolling while heatmap viewport starts on monday`() {
        val today = LocalDate.of(2026, 9, 5)
        val period = AnalyticsPeriod.forPlan(Entitlement.PRO, today)
        assertEquals(today.minusDays(363), period.start)
        assertEquals(today, period.end)
        assertEquals(LocalDate.of(2025, 9, 8), period.viewportStart)
        assertEquals(364, period.dates.size)
    }

    @Test fun `thresholds and tied peaks are deterministic`() {
        val today = LocalDate.of(2026, 9, 7)
        val events = (0 until 14).map { index ->
            val date = today.minusDays((index % 7).toLong())
            event(date, date.atStartOfDay().toInstant(java.time.ZoneOffset.UTC).toString(), 0, 1)
        }
        val report = AnalyticsAggregator.aggregate(events, AnalyticsPeriod.forPlan(Entitlement.PRO, today))
        assertEquals(SampleTier.SUMMARY, report.sampleTier)
        assertEquals(listOf(0), report.peakThreeHourBuckets)
        assertEquals(listOf(0, 1, 2, 3, 4, 5, 6), report.peakWeekdays)
    }

    @Test fun `pattern arrays and peaks are unavailable below ten events`() {
        val today = LocalDate.of(2026, 9, 7)
        val report = AnalyticsAggregator.aggregate(
            (0 until 9).map { event(today, "2026-09-07T00:00:${it.toString().padStart(2, '0')}Z", 0, 1) },
            AnalyticsPeriod.forPlan(Entitlement.PRO, today),
        )
        assertTrue(report.threeHourCounts.isEmpty())
        assertTrue(report.weekdayCounts.isEmpty())
        assertTrue(report.intensityCounts.isEmpty())
        assertTrue(report.peakThreeHourBuckets.isEmpty())
        assertTrue(report.peakWeekdays.isEmpty())
    }

    private fun event(date: LocalDate, completed: String, offsetMinutes: Int, intensity: Int) = StoredInjectionEvent(
        id = UUID.randomUUID(), startedAtUtc = Instant.parse(completed).minusSeconds(2), completedAtUtc = Instant.parse(completed),
        eventLocalDate = date, timezoneOffsetMinutes = offsetMinutes, intensity = requireNotNull(Intensity.from(intensity)), source = EntrySource.APP,
        phraseId = PhraseId("test"), animationDurationMs = 1200, interruptionCount = 0, appVersion = "test", createdAtUtc = Instant.parse(completed)
    )
}
