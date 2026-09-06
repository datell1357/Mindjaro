package com.maeumjaro.app.feature.shell

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.maeumjaro.app.content.SafetyCopy
import com.maeumjaro.app.design.MaeumjaroTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SafetyShellTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun safetyShellShowsDisclaimerWithoutDeveloperPlaceholder() {
        composeRule.setContent {
            MaeumjaroTheme { SafetyShell(onBack = {}) }
        }

        composeRule.onNodeWithText(SafetyCopy.disclaimer).assertIsDisplayed()
        composeRule.onAllNodesWithText("Task 5", substring = true).assertCountEquals(0)
        composeRule.onAllNodesWithText("준비 화면", substring = true).assertCountEquals(0)
    }
}
