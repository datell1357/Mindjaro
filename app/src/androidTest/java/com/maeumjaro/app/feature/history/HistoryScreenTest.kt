package com.maeumjaro.app.feature.history

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.SemanticsActions
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.design.MaeumjaroTheme
import com.maeumjaro.app.data.local.DailyAggregate
import com.maeumjaro.app.feature.history.ui.HistoryDashboard
import com.maeumjaro.app.feature.history.ui.DayDetailSheet
import com.maeumjaro.app.feature.history.ui.RecordDetailSheet
import java.time.LocalDate
import java.time.LocalTime
import java.util.UUID
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Rule
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun heatmapExposesDateCountAndSumAndFutureCellIsDisabled() {
        val today = LocalDate.parse("2026-09-05")
        val start = LocalDate.parse("2026-05-18")
        val countBoundaries = listOf(0, 1, 2, 4, 5, 6, 7)
        val sumBoundaries = listOf(0, 1, 3, 4, 7, 8, 12, 13, 19, 20)
        val fixture = (0L..110L).map { index ->
            DailyAggregate(
                date = start.plusDays(index),
                count = countBoundaries[(index % countBoundaries.size).toInt()],
                intensitySum = sumBoundaries[(index % sumBoundaries.size).toInt()],
            )
        }
        val state = HistoryStateBuilder.build(today, fixture, emptyList(), emptyList())
        composeRule.setContent { MaeumjaroTheme { HistoryDashboard(state, {}, {}) } }

        composeRule.onNodeWithText("횟수").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("히트맵 모드: 횟수").assertExists()
        state.heatmap.forEach { cell ->
            composeRule.onNodeWithContentDescription(cell.semanticDescription).performScrollTo().assertIsDisplayed()
        }
        composeRule.onNodeWithContentDescription("2026년 9월 5일, 6회, 누적 강도 0").assertExists()
        composeRule.onNodeWithContentDescription("2026년 9월 6일, 0회, 누적 강도 0").assertIsNotEnabled()
        captureHistoryEvidence("task9-history-v2-count")
        composeRule.onNodeWithText("누적 강도").performClick()
        composeRule.onNodeWithContentDescription("히트맵 모드: 누적 강도").assertExists()
        composeRule.onNodeWithContentDescription("2026년 9월 5일, 6회, 누적 강도 0").assertExists()
        composeRule.onNodeWithContentDescription("2026년 9월 6일, 0회, 누적 강도 0").assertIsNotEnabled()
        captureHistoryEvidence("task9-history-v2-intensity")
    }

    @Test
    fun dayDetailShowsChronologicalLabelsAndAggregates() {
        val detail = DayDetailState(
            LocalDate.parse("2026-09-04"), 2, 6, 3.0,
            listOf(
                record("11:03", 4),
                record("15:26", 2),
            ),
        )
        composeRule.setContent { MaeumjaroTheme { DayDetailSheet(detail, {}, {}) } }
        composeRule.onNodeWithText("총 2회").assertIsDisplayed()
        composeRule.onNodeWithText("11:03 · 강도 4").assertIsDisplayed()
        composeRule.onNodeWithText("15:26 · 강도 2").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("기록 2026-09-04 11:03, 강도 4").assertHeightIsAtLeast(48.dp)
        assertTrue(
            !composeRule.onNodeWithContentDescription("기록 2026-09-04 11:03, 강도 4").fetchSemanticsNode().config.contains(SemanticsActions.OnClick),
        )
        composeRule.waitForIdle()
        captureHistoryEvidence("task9-history-v2-2026-09-04-detail")
    }

    @Test
    fun dayDetailPreservesCompletionChronologyWhenLocalTimesRunBackward() {
        val detail = DayDetailState(
            LocalDate.parse("2026-09-04"), 2, 6, 3.0,
            listOf(record("23:30", 4), record("01:00", 2)),
        )
        composeRule.setContent { MaeumjaroTheme { DayDetailSheet(detail, {}, {}) } }

        val earlierCompletion = composeRule.onNodeWithText("23:30 · 강도 4").fetchSemanticsNode()
        val laterCompletion = composeRule.onNodeWithText("01:00 · 강도 2").fetchSemanticsNode()
        assertTrue(earlierCompletion.boundsInRoot.top < laterCompletion.boundsInRoot.top)
    }

    @Test
    fun narrowTwoHundredPercentDetailKeepsMutationTargetsReachable() {
        val detail = RecordDetailState(
            UUID.randomUUID(), LocalDate.parse("2026-09-05"), LocalTime.NOON,
            requireNotNull(Intensity.from(3)), EntrySource.APP, "지금은 한 번 멈추어 선택해요.",
        )
        composeRule.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale = 2f)) {
                Box(Modifier.width(320.dp)) {
                    MaeumjaroTheme { RecordDetailSheet(detail, {}, {}, {}) }
                }
            }
        }
        composeRule.onNodeWithText("강도 저장").assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        composeRule.onNodeWithText("이 기록 삭제").performScrollTo().assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        val deleteBounds = composeRule.onNodeWithText("이 기록 삭제").fetchSemanticsNode().boundsInRoot
        val screenHeight = InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.heightPixels
        assertTrue("Delete action must be fully inside the viewport: $deleteBounds vs $screenHeight", deleteBounds.bottom <= screenHeight)
        composeRule.waitForIdle()
        captureHistoryEvidence("task9-history-v2-record-font200")
        composeRule.onNodeWithText("이 기록 삭제").performClick()
        composeRule.onNodeWithText("취소").assertIsDisplayed().performClick()
        composeRule.onNodeWithText("취소").assertDoesNotExist()
    }

    private fun record(time: String, intensity: Int) = HistoryRecordItem(
        id = UUID.nameUUIDFromBytes(time.toByteArray()),
        date = LocalDate.parse("2026-09-04"),
        time = LocalTime.parse(time),
        intensity = requireNotNull(Intensity.from(intensity)),
    )
}
