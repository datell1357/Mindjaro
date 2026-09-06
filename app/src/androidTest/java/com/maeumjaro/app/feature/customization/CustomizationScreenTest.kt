package com.maeumjaro.app.feature.customization

import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextReplacement
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.feature.analytics.Entitlement
import com.maeumjaro.app.design.MaeumjaroTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class CustomizationScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun phraseToneAndCategorySelectionsReachSaveCallback() {
        var saved: Triple<String, PhraseTone, PhraseCategory>? = null
        composeRule.setContent {
            MaeumjaroTheme {
                CustomizationScreen(
                    state = CustomizationUiState(
                        entitlement = Entitlement.PRO,
                        themes = ThemeCatalog.themes.map { ThemeOption(it, it == ThemeCatalog.default, false) },
                    ),
                    onThemeSelected = {},
                    onSavePhrase = { text, tone, category -> saved = Triple(text, tone, category) },
                    onArchivePhrase = {}, onPresetChanged = { _, _ -> }, onPresetDeleted = {},
                )
            }
        }

        composeRule.onNode(hasSetTextAction()).performTextReplacement("천천히 다음 행동을 골라요")
        composeRule.onNodeWithText("단호하게").performClick()
        composeRule.onNodeWithText("다음 행동 고르기").performScrollTo().performClick()
        composeRule.onNodeWithText("문구 저장").assertIsEnabled().performScrollTo().performClick()
        composeRule.waitForIdle()

        assertEquals(Triple("천천히 다음 행동을 골라요", PhraseTone.FIRM, PhraseCategory.REDIRECT), saved)
    }
}
