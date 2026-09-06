package com.maeumjaro.app.feature.customization

import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.data.settings.AppStateStore
import com.maeumjaro.app.feature.analytics.Entitlement
import com.maeumjaro.app.feature.analytics.EntitlementRepository
import java.util.UUID
import kotlinx.coroutines.flow.first

data class CustomizationUiState(
    val entitlement: Entitlement = Entitlement.FREE,
    val selectedThemeId: String = ThemeCatalog.default.id,
    val themes: List<ThemeOption> = emptyList(),
    val phrases: List<CustomPhrase> = emptyList(),
    val widgetPresets: Map<Int, Int> = emptyMap(),
    val installedWidgetIds: List<Int> = emptyList(),
    val globalIntensity: Int = 3,
    val errorMessage: String? = null,
)

fun interface InstalledWidgetInventory {
    suspend fun ids(): List<Int>
}

object WidgetPresetPresentation {
    fun ids(installed: List<Int>, presets: Map<Int, Int>): List<Int> =
        (installed + presets.keys).filter { it > 0 }.distinct().sorted()

    fun label(widgetId: Int, preset: Int?, globalIntensity: Int): String =
        if (preset == null) "위젯 $widgetId · 전역 강도 $globalIntensity"
        else "위젯 $widgetId · 고정 강도 $preset"
}

data class ThemeOption(
    val theme: ThemeDefinition,
    val isSelected: Boolean,
    val isLocked: Boolean,
)

object CustomPhraseInputPolicy {
    const val maxLength: Int = 120

    fun truncate(value: String): String = value.take(maxLength)
}

/** Coordinates customization writes and keeps the Pro gate at the feature boundary. */
class CustomizationController(
    private val appStateStore: AppStateStore,
    private val phraseRepository: CustomPhraseRepository,
    private val entitlementRepository: EntitlementRepository,
    private val widgetPresetStore: WidgetPresetStore,
    private val installedWidgetInventory: InstalledWidgetInventory = InstalledWidgetInventory { emptyList() },
) {
    suspend fun load(): CustomizationUiState {
        val entitlement = entitlementRepository.current()
        val appState = appStateStore.state.first()
        val phrases = if (entitlement == Entitlement.PRO) phraseRepository.all() else emptyList()
        val presets = if (entitlement == Entitlement.PRO) widgetPresetStore.snapshot() else emptyMap()
        val installedIds = installedWidgetInventory.ids().filter { it > 0 }.distinct().sorted()
        return state(entitlement, appState.themeId, phrases, presets, installedIds, appState.intensity.takeIf { it in 1..5 } ?: 3)
    }

    suspend fun selectTheme(requestedId: String): CustomizationUiState {
        val entitlement = entitlementRepository.current()
        val selected = if (entitlement == Entitlement.PRO) ThemeCatalog.resolve(requestedId).id else ThemeCatalog.default.id
        appStateStore.setThemeId(selected)
        return load()
    }

    suspend fun savePhrase(
        text: String,
        tone: PhraseTone,
        category: PhraseCategory,
        existingId: PhraseId? = null,
        nowEpochMillis: Long,
    ): PhraseSaveResult {
        if (entitlementRepository.current() != Entitlement.PRO) return PhraseSaveResult.Locked
        val validation = CustomPhraseValidator().validate(text)
        if (validation.state == PhraseValidationState.UNSAFE) return PhraseSaveResult.Rejected(validation)
        if (text.trim().length > CustomPhraseInputPolicy.maxLength) {
            return PhraseSaveResult.Rejected(PhraseValidation(PhraseValidationState.UNSAFE, listOf("too_long")))
        }
        val phrase = CustomPhrase(
            id = existingId ?: PhraseId("custom:${UUID.randomUUID()}"),
            text = text.trim(),
            tone = tone,
            category = category,
            createdAtEpochMillis = nowEpochMillis,
            validationState = validation.state,
        )
        val saved = if (existingId == null) phraseRepository.save(phrase) else phraseRepository.update(phrase)
        return PhraseSaveResult.Saved(saved)
    }

    suspend fun archivePhrase(id: PhraseId): CustomizationUiState {
        if (entitlementRepository.current() == Entitlement.PRO) phraseRepository.archive(id)
        return load()
    }

    suspend fun setWidgetPreset(widgetId: Int, intensity: Int): CustomizationUiState {
        if (entitlementRepository.current() == Entitlement.PRO) widgetPresetStore.setPreset(widgetId, intensity)
        return load()
    }

    suspend fun deleteWidgetPreset(widgetId: Int): CustomizationUiState {
        if (entitlementRepository.current() == Entitlement.PRO) widgetPresetStore.delete(widgetId)
        return load()
    }

    private fun state(
        entitlement: Entitlement,
        selectedThemeId: String,
        phrases: List<CustomPhrase>,
        presets: Map<Int, Int>,
        installedWidgetIds: List<Int>,
        globalIntensity: Int,
    ): CustomizationUiState {
        val effectiveThemeId = if (entitlement == Entitlement.PRO) selectedThemeId else ThemeCatalog.default.id
        return CustomizationUiState(
        entitlement = entitlement,
        selectedThemeId = effectiveThemeId,
        themes = ThemeCatalog.themes.map { theme ->
            ThemeOption(theme, theme.id == effectiveThemeId, entitlement != Entitlement.PRO && theme.id != ThemeCatalog.default.id)
        },
        phrases = phrases,
        widgetPresets = presets,
        installedWidgetIds = installedWidgetIds,
        globalIntensity = globalIntensity,
        )
    }
}

sealed interface PhraseSaveResult {
    data class Saved(val phrase: CustomPhrase) : PhraseSaveResult
    data class Rejected(val validation: PhraseValidation) : PhraseSaveResult
    data object Locked : PhraseSaveResult
}
