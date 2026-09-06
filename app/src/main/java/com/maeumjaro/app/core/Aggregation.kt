package com.maeumjaro.app.core

import java.time.DayOfWeek
import java.time.LocalDate
import java.util.UUID

data class CompletedEvent(val id: UUID, val intensity: Intensity, val completedAt: EventTime)
data class DailySummary(val date: LocalDate, val count: Int, val intensitySum: Int, val averageIntensity: Double)

@JvmInline
value class HeatmapLevel private constructor(val value: Int) {
    companion object {
        fun forCount(count: Int): HeatmapLevel = HeatmapLevel(when (count) { in Int.MIN_VALUE..0 -> 0; 1 -> 1; 2 -> 2; in 3..4 -> 3; in 5..6 -> 4; else -> 5 })
        fun forIntensitySum(sum: Int): HeatmapLevel = HeatmapLevel(when (sum) { in Int.MIN_VALUE..0 -> 0; in 1..3 -> 1; in 4..7 -> 2; in 8..12 -> 3; in 13..19 -> 4; else -> 5 })
    }
}

enum class SampleTier {
    NEEDS_MORE, EARLY, SUMMARY, COMPARISON;
    companion object {
        fun fromCount(count: Int): SampleTier = when (count) {
            in Int.MIN_VALUE..4 -> NEEDS_MORE
            in 5..9 -> EARLY
            in 10..29 -> SUMMARY
            else -> COMPARISON
        }
    }
}

data class Distribution(val counts: List<Int>) {
    val peakBucketIndices: List<Int>
        get() {
            val peak = counts.maxOrNull() ?: 0
            return if (peak == 0) emptyList() else counts.indices.filter { counts[it] == peak }
        }
}

object Aggregation {
    fun daily(events: List<CompletedEvent>): List<DailySummary> = events
        .groupBy { it.completedAt.localDate }
        .toSortedMap()
        .map { (date, values) ->
            val sum = values.sumOf { it.intensity.value }
            DailySummary(date, values.size, sum, sum.toDouble() / values.size)
        }

    fun byThreeHourBucket(events: List<CompletedEvent>): Distribution = distribution(8, events) {
        it.completedAt.localDateTime.hour / 3
    }

    fun byWeekday(events: List<CompletedEvent>): Distribution = distribution(7, events) {
        it.completedAt.localDate.dayOfWeek.value - DayOfWeek.MONDAY.value
    }

    fun byIntensity(events: List<CompletedEvent>): Distribution = distribution(5, events) { it.intensity.value - 1 }

    private fun distribution(size: Int, events: List<CompletedEvent>, slot: (CompletedEvent) -> Int): Distribution {
        val counts = MutableList(size) { 0 }
        events.forEach { counts[slot(it)]++ }
        return Distribution(counts)
    }
}
