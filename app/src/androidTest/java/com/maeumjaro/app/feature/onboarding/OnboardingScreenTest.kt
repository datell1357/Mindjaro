package com.maeumjaro.app.feature.onboarding

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.maeumjaro.app.design.MaeumjaroTheme
import org.junit.Assert.assertEquals
import com.maeumjaro.app.content.SafetyCopy
import org.junit.Rule
import org.junit.Test

class OnboardingScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun givenFiveStepFlow_whenCompleted_thenSelectedIntensityIsReturned() {
        // Given: a first-run onboarding surface and an unavailable automatic pin request.
        var completedIntensity: Int? = null
        composeRule.setContent {
            MaeumjaroTheme {
                OnboardingScreen(
                    initialIntensity = 3,
                    pinRequester = WidgetPinRequester { false },
                    onComplete = { completedIntensity = it },
                )
            }
        }

        // When: all five steps are traversed and intensity four is selected.
        composeRule.onNodeWithText("다음").performClick()
        composeRule.onNodeWithText("다음").performClick()
        composeRule.onNodeWithContentDescription("마인드 강도 4").performClick()
        composeRule.onNodeWithText("다음").performClick()
        composeRule.onNodeWithText("안전 안내를 확인해요").assertIsDisplayed()
        composeRule.onNodeWithText("다음").performClick()
        composeRule.onNodeWithText("나중에").performClick()

        // Then: completion returns the selected valid value.
        assertEquals(4, completedIntensity)
    }

    @Test
    fun givenOptionalWidgetStep_whenPinRequestUnavailable_thenManualFallbackIsVisible() {
        // Given: onboarding advanced to the optional widget guidance step.
        composeRule.setContent {
            MaeumjaroTheme {
                OnboardingScreen(3, WidgetPinRequester { false }, onComplete = {})
            }
        }
        repeat(4) { composeRule.onNodeWithText("다음").performClick() }

        // When: the user explicitly requests a widget pin.
        composeRule.onNodeWithText("위젯 추가 요청").performClick()

        // Then: manual device guidance is shown without an error surface.
        composeRule.onNodeWithText(
            "자동 추가를 사용할 수 없어요. 홈 화면을 길게 누른 뒤 위젯 메뉴에서 마음자로를 선택해 주세요.",
        ).assertIsDisplayed()
    }

    @Test
    fun givenNarrowTwoHundredPercentText_whenRendered_thenPrimaryTargetRemainsReachable() {
        // Given: a narrow screen and 200 percent text scaling.
        composeRule.setContent {
            val density = LocalDensity.current
            androidx.compose.runtime.CompositionLocalProvider(
                LocalDensity provides Density(density.density, fontScale = 2f),
            ) {
                Box(Modifier.width(320.dp)) {
                    MaeumjaroTheme {
                        OnboardingScreen(3, WidgetPinRequester { false }, onComplete = {})
                    }
                }
            }
        }

        // Then: every step remains reachable at 200% text, including the disclaimer.
        repeat(3) { composeRule.onNodeWithText("다음").assertIsDisplayed().assertHeightIsAtLeast(48.dp).performClick() }
        composeRule.onNodeWithText("안전 안내를 확인해요").assertIsDisplayed()
        composeRule.onNodeWithContentDescription(SafetyCopy.disclaimer).assertIsDisplayed()
        composeRule.onNodeWithText("다음").assertIsDisplayed().assertHeightIsAtLeast(48.dp).performClick()
        composeRule.onNodeWithText("나중에").assertIsDisplayed().assertHeightIsAtLeast(48.dp)
    }

    @Test
    fun givenDisclaimerStep_whenRendered_thenTitleAndCanonicalCopyAppearExactlyOnce() {
    composeRule.setContent { MaeumjaroTheme { OnboardingScreen(3, WidgetPinRequester { false }, onComplete = {}) } }
        repeat(3) { composeRule.onNodeWithText("다음").performClick() }
        composeRule.onNodeWithText("안전 안내를 확인해요").assertIsDisplayed()
        composeRule.onNodeWithText(SafetyCopy.disclaimer, useUnmergedTree = true).assertIsDisplayed()
    }

    @Test
    fun givenOnboardingCopy_whenRendered_thenKoreanPhrasesStayIntact() {
        composeRule.setContent {
            MaeumjaroTheme {
                OnboardingScreen(3, WidgetPinRequester { false }, onComplete = {})
            }
        }

        composeRule.onNodeWithText(
            "몸과 마음을 잠시 살피는 자기조절 도구예요. 의료적 판단이나 변화를 약속하지 않아요.",
        ).assertIsDisplayed()
    }
}
