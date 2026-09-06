package com.maeumjaro.app.feature.history

import com.maeumjaro.app.core.HeatmapLevel
import org.junit.Assert.assertEquals
import org.junit.Test

class HistoryBaselineCharacterizationTest {
    @Test
    fun existingFixedAggregationBoundariesRemainStable() {
        assertEquals(listOf(0, 1, 2, 3, 3, 4, 4, 5), listOf(0, 1, 2, 3, 4, 5, 6, 7).map { HeatmapLevel.forCount(it).value })
        assertEquals(listOf(0, 1, 1, 2, 2, 3, 3, 4, 4, 5), listOf(0, 1, 3, 4, 7, 8, 12, 13, 19, 20).map { HeatmapLevel.forIntensitySum(it).value })
    }
}
