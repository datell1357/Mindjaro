package com.maeumjaro.app.feature.customization

import com.maeumjaro.app.content.ContentPolicy
import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseSelector
import com.maeumjaro.app.core.PhraseSelection
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.feature.analytics.Entitlement
import com.maeumjaro.app.feature.analytics.EntitlementRepository
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.random.Random

enum class PhraseValidationState { NOT_VALIDATED, VALID, UNSAFE }

data class CustomPhrase(
    val id: PhraseId,
    val text: String,
    val tone: PhraseTone,
    val category: PhraseCategory,
    val createdAtEpochMillis: Long,
    val validationState: PhraseValidationState = PhraseValidationState.NOT_VALIDATED,
    val archived: Boolean = false,
) {
    init {
        require(id.value.isNotBlank())
        require(createdAtEpochMillis >= 0)
    }
}

data class PhraseValidation(val state: PhraseValidationState, val reasons: List<String>)

/** Local-only safety gate. Unsafe text remains editable but can never enter the selector pool. */
class CustomPhraseValidator {
    private val positiveClaimPatterns = listOf(
        Regex("(?i)(효과|효능|치료|처방|약물|의약품|복용|용량|도즈|dose)"),
        Regex("(?i)(식욕|충동).{0,8}(억제|감소|차단|제거)"),
        Regex("(?i)(체중|살).{0,8}(감량|감소|빠짐|빼기)"),
    )

    fun validate(text: String): PhraseValidation {
        val normalized = text.trim()
        if (normalized.isBlank()) return PhraseValidation(PhraseValidationState.UNSAFE, listOf("blank"))
        val reasons = ContentPolicy.violations(normalized).toMutableList()
        positiveClaimPatterns.forEach { pattern ->
            if (pattern.containsMatchIn(normalized)) reasons += "positive_or_medical_claim"
        }
        return if (reasons.isEmpty()) PhraseValidation(PhraseValidationState.VALID, emptyList())
        else PhraseValidation(PhraseValidationState.UNSAFE, reasons.distinct())
    }
}

interface CustomPhraseRepository {
    suspend fun save(phrase: CustomPhrase): CustomPhrase
    suspend fun update(phrase: CustomPhrase): CustomPhrase
    suspend fun archive(id: PhraseId)
    suspend fun all(): List<CustomPhrase>
    suspend fun resolve(id: PhraseId): CustomPhrase?
}

class InMemoryCustomPhraseRepository : CustomPhraseRepository {
    private val values = linkedMapOf<PhraseId, CustomPhrase>()
    private val validator = CustomPhraseValidator()
    override suspend fun save(phrase: CustomPhrase): CustomPhrase {
        return phrase.validated().also { values[it.id] = it }
    }
    override suspend fun update(phrase: CustomPhrase): CustomPhrase {
        archive(phrase.id)
        return save(phrase.copy(id = PhraseId("custom:${java.util.UUID.randomUUID()}"), archived = false))
    }
    override suspend fun archive(id: PhraseId) { values[id]?.let { values[id] = it.copy(archived = true) } }
    override suspend fun all(): List<CustomPhrase> = values.values.toList()
    override suspend fun resolve(id: PhraseId): CustomPhrase? = values[id]

    private fun CustomPhrase.validated(): CustomPhrase {
        val result = validator.validate(text)
        return copy(text = text.trim(), validationState = result.state)
    }
}

class CustomPhraseSelector(
    private val repository: CustomPhraseRepository,
    private val random: Random,
) {
    /**
     * Builds the active, safety-reviewed extension to the bundled phrase pool.
     * Custom phrases are deliberately intensity-agnostic: the author chooses a
     * tone/category, while the current ritual intensity still controls the
     * selection request and built-in candidates.
     */
    suspend fun selectionPool(base: List<Phrase>, intensity: Intensity): List<Phrase> {
        return selectionPool(base, intensity, Entitlement.PRO)
    }

    suspend fun selectionPool(base: List<Phrase>, intensity: Intensity, entitlement: Entitlement): List<Phrase> {
        if (entitlement != Entitlement.PRO) return base
        val custom = repository.all().asSequence()
            .filter { it.isEligibleForSelection() }
            .map { phrase ->
                Phrase(
                    id = phrase.id,
                    text = phrase.text,
                    category = phrase.category,
                    tone = phrase.tone,
                    intensities = setOf(intensity),
                    safetyReviewed = true,
                )
            }
            .toList()
        return base + custom
    }

    suspend fun select(request: PhraseSelection): Phrase {
        return PhraseSelector(random).select(request.copy(pool = selectionPool(request.pool, request.intensity)))
    }

    private fun CustomPhrase.isEligibleForSelection(): Boolean =
        !archived && validationState == PhraseValidationState.VALID &&
            CustomPhraseValidator().validate(text).state == PhraseValidationState.VALID
}

/**
 * Resolves an event's phrase without applying the current selection policy.
 * This is important for history: an archived or now-unsafe custom phrase must
 * remain readable in an old event, while unknown IDs still use the safe copy.
 */
class CustomPhraseResolver(private val repository: CustomPhraseRepository) {
    suspend fun resolve(id: PhraseId): Phrase {
        val custom = repository.resolve(id)
        if (custom != null) {
            return Phrase(
                id = custom.id,
                text = custom.text,
                category = custom.category,
                tone = custom.tone,
                intensities = (1..5).mapNotNull(Intensity::from).toSet(),
                safetyReviewed = custom.validationState == PhraseValidationState.VALID,
            )
        }
        return SafePhraseCatalog.resolve(id)
    }
}

data class ThemeDefinition(
    val id: String,
    val canvasArgb: Long,
    val contentArgb: Long,
    val accentArgb: Long,
    val secondaryArgb: Long,
) {
    init { require(id.isNotBlank()) }
}

object ThemeCatalog {
    val default = ThemeDefinition("default", 0xFFFFFBF5, 0xFF14263D, 0xFF197A67, 0xFF4052A0)
    val dusk = ThemeDefinition("dusk", 0xFF171827, 0xFFF4F0FF, 0xFF8CD9C6, 0xFFA9B8FF)
    val themes: List<ThemeDefinition> = listOf(default, dusk)
    fun resolve(id: String): ThemeDefinition = themes.firstOrNull { it.id == id } ?: default
}

object ThemeContrast {
    fun hasReadableContent(theme: ThemeDefinition): Boolean = contrast(theme.canvasArgb, theme.contentArgb) >= 4.5
    fun hasReadableAccent(theme: ThemeDefinition): Boolean = contrast(theme.canvasArgb, theme.accentArgb) >= 3.0

    private fun contrast(first: Long, second: Long): Double {
        fun channel(value: Long, shift: Int): Double {
            val c = ((value shr shift) and 0xFF) / 255.0
            return if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
        }
        fun luminance(value: Long) = 0.2126 * channel(value, 16) + 0.7152 * channel(value, 8) + 0.0722 * channel(value, 0)
        val a = luminance(first); val b = luminance(second)
        return (maxOf(a, b) + 0.05) / (minOf(a, b) + 0.05)
    }

    private fun Double.pow(power: Double): Double = java.lang.Math.pow(this, power)
}

class ThemeResolver(private val entitlements: EntitlementRepository) {
    suspend fun resolve(requestedId: String): ThemeDefinition =
        if (entitlements.current() == Entitlement.PRO &&
            ThemeContrast.hasReadableContent(ThemeCatalog.resolve(requestedId)) &&
            ThemeContrast.hasReadableAccent(ThemeCatalog.resolve(requestedId)))
            ThemeCatalog.resolve(requestedId)
        else ThemeCatalog.default
}

interface WidgetPresetStore {
    suspend fun preset(widgetId: Int): Int?
    suspend fun setPreset(widgetId: Int, intensity: Int)
    suspend fun delete(widgetId: Int)
    suspend fun snapshot(): Map<Int, Int>

    /** Rechecks the instance under the same lock as the global write in the integration adapter. */
    suspend fun prepareLaunch(widgetId: Int, setGlobalIntensity: suspend (Int) -> Unit): PresetLaunchResult
}

sealed interface PresetLaunchResult {
    data class Prepared(val intensity: Int) : PresetLaunchResult
    data object Global : PresetLaunchResult
}

class InMemoryWidgetPresetStore : WidgetPresetStore {
    private val values = linkedMapOf<Int, Int>()
    private val lock = Mutex()
    override suspend fun preset(widgetId: Int): Int? = lock.withLock { values[widgetId] }
    override suspend fun setPreset(widgetId: Int, intensity: Int) {
        require(widgetId >= 0); require(intensity in 1..5)
        lock.withLock { values[widgetId] = intensity }
    }
    override suspend fun delete(widgetId: Int) { lock.withLock { values.remove(widgetId) } }
    override suspend fun snapshot(): Map<Int, Int> = lock.withLock { values.toMap() }
    override suspend fun prepareLaunch(widgetId: Int, setGlobalIntensity: suspend (Int) -> Unit): PresetLaunchResult {
        return lock.withLock {
            val intensity = values[widgetId] ?: return@withLock PresetLaunchResult.Global
            setGlobalIntensity(intensity)
            PresetLaunchResult.Prepared(intensity)
        }
    }
}

class PresetLaunchCoordinator(private val presets: WidgetPresetStore) {
    suspend fun prepare(widgetId: Int, setGlobalIntensity: suspend (Int) -> Unit): Int? {
        return when (val result = presets.prepareLaunch(widgetId, setGlobalIntensity)) {
            PresetLaunchResult.Global -> null
            is PresetLaunchResult.Prepared -> result.intensity
        }
    }
}
