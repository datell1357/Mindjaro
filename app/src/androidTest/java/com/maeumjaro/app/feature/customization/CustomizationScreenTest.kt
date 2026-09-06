package com.maeumjaro.app.feature.customization

import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.text.AnnotatedString
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
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
                    onUpdatePhrase = { _, _, _, _ -> },
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

    @Test
    fun editingPhrasePrefillsFormAndReachesUpdateCallback() {
        var updated: List<Any>? = null
        val phrase = CustomPhrase(
            id = PhraseId("custom:123e4567-e89b-12d3-a456-426614174000"),
            text = "기존 문구",
            tone = PhraseTone.GENTLE,
            category = PhraseCategory.AUTONOMY,
            createdAtEpochMillis = 1,
            validationState = PhraseValidationState.VALID,
        )
        composeRule.setContent {
            MaeumjaroTheme {
                CustomizationScreen(
                    state = CustomizationUiState(
                        entitlement = Entitlement.PRO,
                        themes = ThemeCatalog.themes.map { ThemeOption(it, it == ThemeCatalog.default, false) },
                        phrases = listOf(phrase),
                    ),
                    onThemeSelected = {},
                    onSavePhrase = { _, _, _ -> },
                    onUpdatePhrase = { id, text, tone, category -> updated = listOf(id, text, tone, category) },
                    onArchivePhrase = {}, onPresetChanged = { _, _ -> }, onPresetDeleted = {},
                )
            }
        }

        composeRule.onNodeWithText("편집").performScrollTo().performClick()
        composeRule.onNode(hasSetTextAction()).performTextReplacement("수정 문구")
        composeRule.onNodeWithText("문구 수정 저장").performScrollTo().performClick()
        composeRule.waitForIdle()

        assertEquals(listOf(phrase.id, "수정 문구", PhraseTone.GENTLE, PhraseCategory.AUTONOMY), updated)
        composeRule.onNode(hasSetTextAction()).assert(
            SemanticsMatcher.expectValue(SemanticsProperties.EditableText, AnnotatedString("수정 문구")),
        )
        composeRule.onNodeWithText("취소").performClick()
        composeRule.onNodeWithText("문구 저장").assertExists()
    }
}
