package com.maeumjaro.app.feature.settings

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.maeumjaro.app.design.MaeumjaroTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class SettingsScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun deleteActionRemainsReachableInNarrowTwoHundredPercentLayout() {
        composeRule.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, 2f)) {
                Box(Modifier.width(320.dp).height(480.dp)) {
                    MaeumjaroTheme { SettingsUnderTest() }
                }
            }
        }

        composeRule.onNodeWithText("모든 기록 삭제").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun cancelingDeleteConfirmationDoesNotDeleteRecords() {
        var deletes = 0
        composeRule.setContent { MaeumjaroTheme { SettingsUnderTest { deletes++ } } }

        composeRule.onNodeWithText("모든 기록 삭제").performScrollTo().performClick()
        composeRule.onNodeWithText("모든 기록을 삭제할까요?").assertIsDisplayed()
        composeRule.onNodeWithText("취소").performClick()

        assertEquals(0, deletes)
    }

    @Test
    fun confirmingDeleteConfirmationInvokesDeletionExactlyOnce() {
        var deletes = 0
        composeRule.setContent { MaeumjaroTheme { SettingsUnderTest { deletes++ } } }

        composeRule.onNodeWithText("모든 기록 삭제").performScrollTo().performClick()
        composeRule.onNodeWithText("삭제").performClick()

        assertEquals(1, deletes)
    }

    @Test
    fun settingsActionsExposeAtLeast48DpTouchHeight() {
        composeRule.setContent { MaeumjaroTheme { SettingsUnderTest() } }

        composeRule.onNodeWithText("전체 기록 내보내기")
            .performScrollTo()
            .assertHeightIsAtLeast(48.dp)
    }

    @Composable
    private fun SettingsUnderTest(onDeleteAll: () -> Unit = {}) = SettingsScreen(
        state = SettingsUiState(),
        onIntensityChanged = {}, onHapticChanged = {}, onSoundChanged = {},
        onReducedMotionChanged = {}, onPhraseToneChanged = {}, onExport = {},
        onDeleteAll = onDeleteAll, onOpenPro = {},
    )
}
