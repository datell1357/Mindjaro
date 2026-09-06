package com.maeumjaro.app.feature.history

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.HeatmapLevel
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.feature.analytics.Entitlement
import java.time.LocalDate
import java.time.LocalTime
import java.util.UUID

enum class HeatmapMetric { COUNT, INTENSITY_SUM }

data class TodayHistorySummary(
    val count: Int,
    val intensitySum: Int,
    val averageIntensity: Double,
)

data class HistoryRecordItem(
    val id: UUID,
    val date: LocalDate,
    val time: LocalTime,
    val intensity: Intensity,
)

data class HeatmapCellState(
    val date: LocalDate,
    val count: Int,
    val intensitySum: Int,
    val countLevel: HeatmapLevel,
    val intensityLevel: HeatmapLevel,
    val isFuture: Boolean,
    val enabled: Boolean,
    val semanticDescription: String,
) {
    fun level(metric: HeatmapMetric): HeatmapLevel = when (metric) {
        HeatmapMetric.COUNT -> countLevel
        HeatmapMetric.INTENSITY_SUM -> intensityLevel
    }
}

data class HistoryDashboardState(
    val today: LocalDate,
    val todaySummary: TodayHistorySummary,
    val latest: List<HistoryRecordItem>,
    val lastThirtyDays: List<HistoryRecordItem>,
    val heatmap: List<HeatmapCellState>,
    val sampleCopy: String,
    /** The factual history window currently visible to the user. */
    val entitlement: Entitlement = Entitlement.FREE,
    val visibleHistoryDays: Int = 30,
    val visibleHeatmapWeeks: Int = 16,
    val visibleHistory: List<HistoryRecordItem> = lastThirtyDays,
)

data class DayDetailState(
    val date: LocalDate,
    val count: Int,
    val intensitySum: Int,
    val averageIntensity: Double,
    val records: List<HistoryRecordItem>,
)

data class RecordDetailState(
    val id: UUID,
    val date: LocalDate,
    val time: LocalTime,
    val intensity: Intensity,
    val source: EntrySource,
    val phraseText: String,
)

sealed interface HistoryMutationResult {
    data class Applied(val dashboard: HistoryDashboardState) : HistoryMutationResult
    data class ProjectionPending(val dashboard: HistoryDashboardState) : HistoryMutationResult
    data class NotFound(val dashboard: HistoryDashboardState) : HistoryMutationResult
    data class Canceled(val dashboard: HistoryDashboardState) : HistoryMutationResult
    data class InvalidIntensity(val dashboard: HistoryDashboardState) : HistoryMutationResult
}

fun interface HistoryMutationObserver {
    suspend fun recordsChanged()

    companion object {
        val None = HistoryMutationObserver { }
    }
}
