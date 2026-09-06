package com.maeumjaro.app.navigation

import android.content.Intent
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import com.maeumjaro.app.MainActivity
import org.junit.Rule
import org.junit.Test

class MainActivityRouteTest {
    @get:Rule
    val composeRule = createEmptyComposeRule()

    @Test
    fun givenReturningIconLaunch_whenOpened_thenRecordsDashboardIsVisible() {
        // Given: a verified debug returning-user launch.
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_SEED_RETURNING, true)

        // When: the real activity is launched.
        ActivityScenario.launch<MainActivity>(intent).use {
            // Then: the records dashboard is visible.
            composeRule.waitUntil(timeoutMillis = 5_000) {
                composeRule.onAllNodesWithText("나의 기록").fetchSemanticsNodes().isNotEmpty()
            }
            composeRule.onNodeWithText("나의 기록").assertIsDisplayed()
        }
    }

    @Test
    fun givenVerifiedWidgetReturningLaunch_whenOpened_thenInjectionHasNoDashboardStop() {
        // Given: a verified debug widget source for a returning user.
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_SEED_RETURNING, true)
            .putExtra(MainActivity.EXTRA_SOURCE, "widget")
            .putExtra(MainActivity.EXTRA_DEBUG_VERIFIED_WIDGET, true)

        // When: the real activity is launched.
        ActivityScenario.launch<MainActivity>(intent).use {
            // Then: injection is the first visible route with no records dashboard.
            composeRule.waitUntil(timeoutMillis = 5_000) {
                composeRule.onAllNodesWithText("마음 정리").fetchSemanticsNodes().isNotEmpty()
            }
            composeRule.onNodeWithText("마음 정리").assertIsDisplayed()
            composeRule.onNodeWithText("나의 기록").assertDoesNotExist()
        }
    }
}
