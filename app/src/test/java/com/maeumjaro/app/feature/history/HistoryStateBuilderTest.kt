package com.maeumjaro.app.feature.history

import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.data.local.DailyAggregate
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.feature.analytics.Entitlement
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryStateBuilderTest {
    private val today = LocalDate.parse("2026-09-05")

    @Test
    fun buildsMondayFirstSixteenWeekGridAndDisablesFutureCells() {
        val state = HistoryStateBuilder.build(today, emptyList(), emptyList(), emptyList())
        assertEquals(112, state.heatmap.size)
        assertEquals(LocalDate.parse("2026-05-18"), state.heatmap.first().date)
        assertEquals(today, state.heatmap[110].date)
        assertTrue(state.heatmap[111].isFuture)
        assertFalse(state.heatmap[111].enabled)
    }

    @Test
    fun labelsAndLevelsAreAbsoluteAndIncludeNonColorSemantics() {
        val aggregates = listOf(DailyAggregate(today, 7, 20))
        val state = HistoryStateBuilder.build(today, aggregates, emptyList(), emptyList())
        val cell = state.heatmap.single { it.date == today }
        assertEquals(5, cell.countLevel.value)
        assertEquals(5, cell.intensityLevel.value)
        assertEquals("2026년 9월 5일, 7회, 누적 강도 20", cell.semanticDescription)
    }

    @Test
    fun dayDetailsAreChronologicalAndMissingPhraseUsesFallback() {
        val late = event("2026-09-05T13:00:00Z", 4, "missing")
        val early = event("2026-09-05T01:00:00Z", 2, "ground-001")
        val detail = HistoryStateBuilder.dayDetail(today, listOf(late, early))
        assertEquals(listOf(early.id, late.id), detail.records.map { it.id })
        assertEquals(3.0, detail.averageIntensity, 0.0)
        assertTrue(HistoryStateBuilder.recordDetail(late).phraseText.isNotBlank())
    }

    @Test
    fun completionChronologyWinsWhenStoredOffsetsReverseDisplayedLocalTimes() {
        val earlierCompletion = event("2026-09-05T01:00:00Z", 2, "ground-001")
            .copy(timezoneOffsetMinutes = 840)
        val laterCompletion = event("2026-09-05T02:00:00Z", 4, "ground-001")
            .copy(timezoneOffsetMinutes = -720)

        val detail = HistoryStateBuilder.dayDetail(today, listOf(laterCompletion, earlierCompletion))

        assertEquals(listOf(earlierCompletion.id, laterCompletion.id), detail.records.map { it.id })
        assertTrue(detail.records.first().time > detail.records.last().time)
    }

    @Test
    fun sampleCopyIsNeutralAtLowCounts() {
        assertEquals("패턴을 보기에는 기록이 더 필요합니다.", HistoryStateBuilder.sampleCopy(4))
        assertEquals("초기 사용 경향입니다.", HistoryStateBuilder.sampleCopy(5))
    }

    @Test
    fun cardsUseTodayAggregateAndLatestIsCappedAtTen() {
        val events = (0 until 12).map { index -> event("2026-09-05T${index.toString().padStart(2, '0')}:00:00Z", (index % 5) + 1, "ground-001") }
        val state = HistoryStateBuilder.build(today, listOf(DailyAggregate(today, 12, 33)), events, events)
        assertEquals(12, state.todaySummary.count)
        assertEquals(33, state.todaySummary.intensitySum)
        assertEquals(2.75, state.todaySummary.averageIntensity, 0.0)
        assertEquals(10, state.latest.size)
        assertEquals(events.last().id, state.latest.first().id)
    }

    @Test
    fun malformedStoredOffsetCannotCrashHistoryRendering() {
        val malformed = event("2026-09-05T01:00:00Z", 3, "ground-001").copy(timezoneOffsetMinutes = Int.MAX_VALUE)
        assertEquals(19, HistoryStateBuilder.recordDetail(malformed).time.hour)
    }

    @Test
    fun proBuilderExposesFiftyTwoWeekHeatmapAndExtendedHistoryWithoutChangingFacts() {
        val historyStart = LocalDate.parse("2025-09-08")
        val event = event("2026-09-05T01:00:00Z", 3, "ground-001")
        val state = HistoryStateBuilder.build(
            today = today,
            aggregates = listOf(DailyAggregate(today, 1, 3)),
            latest = listOf(event),
            lastThirtyDays = listOf(event),
            historyWindowStart = historyStart,
            heatmapWeeks = 52,
            entitlement = Entitlement.PRO,
        )
        assertEquals(Entitlement.PRO, state.entitlement)
        assertEquals(52, state.visibleHeatmapWeeks)
        assertEquals(364, state.heatmap.size)
        assertEquals(1, state.visibleHistory.size)
        assertEquals(event.id, state.visibleHistory.single().id)
    }

    @Test
    fun oldestDisplayedWeekKeepsItsStoredAggregate() {
        val firstDate = LocalDate.parse("2026-05-18")
        val state = HistoryStateBuilder.build(
            today = today,
            aggregates = listOf(DailyAggregate(firstDate, 2, 7)),
            latest = emptyList(),
            lastThirtyDays = emptyList(),
        )
        val first = state.heatmap.first()
        assertEquals(firstDate, first.date)
        assertEquals(2, first.count)
        assertEquals(7, first.intensitySum)
    }

    private fun event(instant: String, intensity: Int, phrase: String) = StoredInjectionEvent(
        id = UUID.nameUUIDFromBytes(instant.toByteArray()),
        startedAtUtc = Instant.parse(instant).minusSeconds(2),
        completedAtUtc = Instant.parse(instant),
        eventLocalDate = today,
        timezoneOffsetMinutes = 540,
        intensity = requireNotNull(Intensity.from(intensity)),
        source = EntrySource.APP,
        phraseId = PhraseId(phrase),
        animationDurationMs = 1_800,
        interruptionCount = 0,
        appVersion = "test",
        createdAtUtc = Instant.parse(instant),
    )
}
