package com.maeumjaro.app.feature.history

import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.core.HeatmapLevel
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.data.local.DailyAggregate
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.feature.analytics.Entitlement
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

object HistoryStateBuilder {
    private val semanticDateFormatter = DateTimeFormatter.ofPattern("yyyy년 M월 d일", Locale.KOREAN)

    fun build(
        today: LocalDate,
        aggregates: List<DailyAggregate>,
        latest: List<StoredInjectionEvent>,
        lastThirtyDays: List<StoredInjectionEvent>,
    ): HistoryDashboardState {
        return build(
            today = today,
            aggregates = aggregates,
            latest = latest,
            lastThirtyDays = lastThirtyDays,
            historyWindowStart = today.minusDays(29),
            heatmapWeeks = 16,
            entitlement = Entitlement.FREE,
        )
    }

    fun build(
        today: LocalDate,
        aggregates: List<DailyAggregate>,
        latest: List<StoredInjectionEvent>,
        lastThirtyDays: List<StoredInjectionEvent>,
        historyWindowStart: LocalDate,
        heatmapWeeks: Int,
        entitlement: Entitlement,
    ): HistoryDashboardState {
        val aggregateByDate = aggregates.associateBy(DailyAggregate::date)
        val todayAggregate = aggregateByDate[today]
        val count = todayAggregate?.count ?: 0
        val sum = todayAggregate?.intensitySum ?: 0
        val visibleEvents = lastThirtyDays
            .filter { it.eventLocalDate in historyWindowStart..today }
            .sortedByDescending(StoredInjectionEvent::completedAtUtc)
        val visibleRecords = visibleEvents.map(::recordItem)
        return HistoryDashboardState(
            today = today,
            todaySummary = TodayHistorySummary(count, sum, average(count, sum)),
            latest = latest.sortedByDescending(StoredInjectionEvent::completedAtUtc).take(10).map(::recordItem),
            lastThirtyDays = visibleRecords,
            heatmap = heatmap(today, aggregateByDate, heatmapWeeks),
            sampleCopy = sampleCopy(visibleEvents.size),
            entitlement = entitlement,
            visibleHistoryDays = (today.toEpochDay() - historyWindowStart.toEpochDay() + 1).toInt(),
            visibleHeatmapWeeks = heatmapWeeks,
            visibleHistory = visibleRecords,
        )
    }

    fun dayDetail(date: LocalDate, events: List<StoredInjectionEvent>): DayDetailState {
        val chronological = events.filter { it.eventLocalDate == date }.sortedBy(StoredInjectionEvent::completedAtUtc)
        val sum = chronological.sumOf { it.intensity.value }
        return DayDetailState(date, chronological.size, sum, average(chronological.size, sum), chronological.map(::recordItem))
    }

    fun recordDetail(event: StoredInjectionEvent): RecordDetailState = RecordDetailState(
        id = event.id,
        date = event.eventLocalDate,
        time = localTime(event),
        intensity = event.intensity,
        source = event.source,
        phraseText = SafePhraseCatalog.resolve(event.phraseId).text,
    )

    fun recordDetail(event: StoredInjectionEvent, phrase: Phrase): RecordDetailState = RecordDetailState(
        id = event.id,
        date = event.eventLocalDate,
        time = localTime(event),
        intensity = event.intensity,
        source = event.source,
        phraseText = phrase.text,
    )

    fun sampleCopy(count: Int): String = when (count) {
        in Int.MIN_VALUE..4 -> "패턴을 보기에는 기록이 더 필요합니다."
        in 5..9 -> "초기 사용 경향입니다."
        else -> "저장된 사용 기록을 표시합니다."
    }

    private fun heatmap(today: LocalDate, byDate: Map<LocalDate, DailyAggregate>, weeks: Int): List<HeatmapCellState> {
        val currentMonday = today.minusDays((today.dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())
        val firstDay = currentMonday.minusWeeks((weeks - 1).coerceAtLeast(0).toLong())
        return (0L until (weeks.coerceAtLeast(1) * 7).toLong()).map { offset ->
            val date = firstDay.plusDays(offset)
            val aggregate = byDate[date]
            val count = aggregate?.count ?: 0
            val sum = aggregate?.intensitySum ?: 0
            val future = date > today
            HeatmapCellState(
                date = date,
                count = count,
                intensitySum = sum,
                countLevel = HeatmapLevel.forCount(count),
                intensityLevel = HeatmapLevel.forIntensitySum(sum),
                isFuture = future,
                enabled = !future,
                semanticDescription = "${date.format(semanticDateFormatter)}, ${count}회, 누적 강도 $sum",
            )
        }
    }

    private fun recordItem(event: StoredInjectionEvent) = HistoryRecordItem(
        id = event.id,
        date = event.eventLocalDate,
        time = localTime(event),
        intensity = event.intensity,
    )

    private fun localTime(event: StoredInjectionEvent): LocalTime = event.completedAtUtc
        .atOffset(ZoneOffset.ofTotalSeconds(event.timezoneOffsetMinutes.coerceIn(-1_080, 1_080) * 60))
        .toLocalTime()

    private fun average(count: Int, sum: Int): Double = if (count == 0) 0.0 else sum.toDouble() / count
}
