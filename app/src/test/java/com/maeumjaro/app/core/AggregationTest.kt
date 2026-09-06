package com.maeumjaro.app.core

import java.time.Instant
import java.time.ZoneOffset
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Test

class AggregationTest {
    private fun event(index: Int, intensity: Int = 1, hour: Int = 0): CompletedEvent {
        val instant = Instant.parse("2026-09-04T00:00:00Z").plusSeconds(hour * 3600L + index)
        return CompletedEvent(UUID(0, index.toLong()), Intensity.from(intensity)!!, EventTime.at(instant, ZoneOffset.UTC))
    }

    @Test fun `Given events for one day When summarized Then count sum and average are deterministic`() {
        val summary = Aggregation.daily(listOf(event(1, 2), event(2, 4))).single()
        assertEquals(2, summary.count); assertEquals(6, summary.intensitySum); assertEquals(3.0, summary.averageIntensity, 0.0)
    }

    @Test fun `Given every count heatmap boundary When classified Then fixed levels are exact`() {
        assertEquals(listOf(0, 1, 2, 3, 3, 4, 4, 5), listOf(0, 1, 2, 3, 4, 5, 6, 7).map { HeatmapLevel.forCount(it).value })
    }

    @Test fun `Given every sum heatmap boundary When classified Then fixed levels are exact`() {
        val values = listOf(0, 1, 3, 4, 7, 8, 12, 13, 19, 20)
        assertEquals(listOf(0, 1, 1, 2, 2, 3, 3, 4, 4, 5), values.map { HeatmapLevel.forIntensitySum(it).value })
    }

    @Test fun `Given events across day When bucketed Then eight three-hour buckets and ties are retained`() {
        val distribution = Aggregation.byThreeHourBucket(listOf(event(1, hour = 0), event(2, hour = 3), event(3, hour = 3), event(4, hour = 21), event(5, hour = 21)))
        assertEquals(listOf(1, 2, 0, 0, 0, 0, 0, 2), distribution.counts)
        assertEquals(listOf(1, 7), distribution.peakBucketIndices)
    }

    @Test fun `Given records When distributed Then weekdays and all strengths use stable slots`() {
        val events = listOf(event(1, 1), event(2, 5))
        assertEquals(7, Aggregation.byWeekday(events).counts.size)
        assertEquals(listOf(1, 0, 0, 0, 1), Aggregation.byIntensity(events).counts)
    }

    @Test fun `Given sample boundaries When tiered Then all four tiers are exact`() {
        val values = listOf(0, 4, 5, 9, 10, 29, 30)
        assertEquals(listOf(SampleTier.NEEDS_MORE, SampleTier.NEEDS_MORE, SampleTier.EARLY, SampleTier.EARLY, SampleTier.SUMMARY, SampleTier.SUMMARY, SampleTier.COMPARISON), values.map(SampleTier::fromCount))
    }
}
