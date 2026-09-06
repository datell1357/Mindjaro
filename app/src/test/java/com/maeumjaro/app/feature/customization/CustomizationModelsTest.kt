package com.maeumjaro.app.feature.customization

import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseSelection
import com.maeumjaro.app.core.PhraseSelector
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.feature.analytics.DebugEntitlementRepository
import com.maeumjaro.app.feature.analytics.Entitlement
import com.maeumjaro.app.feature.export.CsvHistoryExporter
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CustomizationModelsTest {
    @Test fun widgetInventorySupportsZeroOneAndMultipleInstances() {
        assertEquals(emptyList<Int>(), WidgetPresetPresentation.ids(emptyList(), emptyMap()))
        assertEquals(listOf(7), WidgetPresetPresentation.ids(listOf(7), emptyMap()))
        assertEquals(listOf(3, 7, 11), WidgetPresetPresentation.ids(listOf(11, 3), mapOf(7 to 4)))
    }

    @Test fun widgetLabelsDistinguishGlobalFallbackAndFixedPreset() {
        assertEquals("위젯 7 · 전역 강도 3", WidgetPresetPresentation.label(7, null, 3))
        assertEquals("위젯 7 · 고정 강도 4", WidgetPresetPresentation.label(7, 4, 3))
    }
    @Test fun freeSelectionPoolExcludesCustomPhrases() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        val custom = CustomPhrase(PhraseId("custom-free"), "기록에 남길 문구", PhraseTone.NEUTRAL, PhraseCategory.AUTONOMY, 1, PhraseValidationState.VALID)
        repo.save(custom)
        val intensity = checkNotNull(Intensity.from(3))
        val pool = CustomPhraseSelector(repo, Random(1)).selectionPool(emptyList(), intensity, Entitlement.FREE)
        assertTrue(pool.none { it.id == custom.id })
    }
    @Test fun validatorKeepsUnsafeEditableButIneligible() {
        val validator = CustomPhraseValidator()
        assertEquals(PhraseValidationState.VALID, validator.validate("잠시 숨을 고르고 다음 행동을 골라요").state)
        assertEquals(PhraseValidationState.UNSAFE, validator.validate("이 문구는 식욕 억제 효과가 있어요").state)
        assertEquals(PhraseValidationState.UNSAFE, validator.validate("   ").state)
    }

    @Test fun repositoryOverridesForgedValidationState() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        val saved = repo.save(CustomPhrase(PhraseId("forged"), "치료 효과가 있습니다", PhraseTone.NEUTRAL, PhraseCategory.AUTONOMY, 1, PhraseValidationState.VALID))
        assertEquals(PhraseValidationState.UNSAFE, saved.validationState)
        assertEquals(PhraseValidationState.UNSAFE, repo.resolve(PhraseId("forged"))?.validationState)
    }

    @Test fun selectorHonorsRecentAndPreviousCategoryForCustomPhrase() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        repo.save(CustomPhrase(PhraseId("custom-a"), "다음 행동을 천천히 골라요", PhraseTone.NEUTRAL, PhraseCategory.AUTONOMY, 1, PhraseValidationState.VALID))
        repo.save(CustomPhrase(PhraseId("custom-unsafe"), "치료 효과가 있어요", PhraseTone.FIRM, PhraseCategory.REDIRECT, 2, PhraseValidationState.UNSAFE))
        val intensity = checkNotNull(Intensity.from(3))
        val selected = CustomPhraseSelector(repo, Random(1)).select(
            PhraseSelection(SafePhraseCatalog.phrases, intensity, listOf(PhraseId("other")), PhraseCategory.NONJUDGMENT),
        )
        assertNotEquals(PhraseId("custom-unsafe"), selected.id)
        val excluded = CustomPhraseSelector(repo, Random(1)).select(
            PhraseSelection(SafePhraseCatalog.phrases, intensity, listOf(PhraseId("custom-a")), null),
        )
        assertNotEquals(PhraseId("custom-a"), excluded.id)
    }

    @Test fun unsafeOnlyPoolUsesSafeNeutralFallback() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        repo.save(CustomPhrase(PhraseId("unsafe"), "치료 효과", PhraseTone.FIRM, PhraseCategory.REDIRECT, 1, PhraseValidationState.VALID))
        val intensity = checkNotNull(Intensity.from(5))
        val selected = CustomPhraseSelector(repo, Random(2)).select(PhraseSelection(emptyList(), intensity, emptyList(), null))
        assertEquals(PhraseId("builtin-safe-fallback"), selected.id)
        assertEquals(PhraseTone.NEUTRAL, selected.tone)
    }

    @Test fun archivePreservesResolutionButSelectorExcludesIt() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        val phrase = CustomPhrase(PhraseId("custom-keep"), "잠시 멈춰 바라봐요", PhraseTone.GENTLE, PhraseCategory.NONJUDGMENT, 1, PhraseValidationState.VALID)
        repo.save(phrase); repo.archive(phrase.id)
        assertEquals(phrase.copy(archived = true), repo.resolve(phrase.id))
        assertEquals(emptyList<CustomPhrase>(), repo.all().filter { !it.archived && it.id == phrase.id })
    }

    @Test fun editingPhraseCreatesNewIdentityAndPreservesHistoricalText() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        val original = CustomPhrase(
            PhraseId("custom-history-edit"), "예전 문구", PhraseTone.GENTLE,
            PhraseCategory.NONJUDGMENT, 1, PhraseValidationState.VALID,
        )
        repo.save(original)

        val revised = repo.update(original.copy(text = "새 문구"))

        assertEquals("예전 문구", repo.resolve(original.id)?.text)
        assertEquals(true, repo.resolve(original.id)?.archived)
        assertNotEquals(original.id, revised.id)
        assertEquals("새 문구", revised.text)
    }

    @Test fun selectorExcludesOnlyTheMostRecentTenAndKeepsOlderCustomPhraseEligible() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        val phrases = (0..10).map { index ->
            CustomPhrase(
                PhraseId("custom-$index"), "선택 가능한 문구 $index", PhraseTone.NEUTRAL,
                PhraseCategory.AUTONOMY, index.toLong(), PhraseValidationState.VALID,
            )
        }
        phrases.forEach { repo.save(it) }
        val intensity = checkNotNull(Intensity.from(3))
        val pool = CustomPhraseSelector(repo, Random(4)).selectionPool(emptyList(), intensity)
        val selected = PhraseSelector(Random(4)).select(
            PhraseSelection(pool, intensity, phrases.takeLast(10).map { it.id }, PhraseCategory.NONJUDGMENT),
        )
        assertEquals(PhraseId("custom-0"), selected.id)
    }

    @Test fun historicalResolverReturnsArchivedAndUnsafeCustomTextButUnknownUsesSafeFallback() = runTest {
        val repo = InMemoryCustomPhraseRepository()
        val archived = CustomPhrase(
            PhraseId("custom-history"), "그때의 문구를 그대로 보여줘요", PhraseTone.GENTLE,
            PhraseCategory.NONJUDGMENT, 1, PhraseValidationState.VALID,
        )
        repo.save(archived); repo.archive(archived.id)
        val unsafe = repo.save(
            CustomPhrase(PhraseId("custom-unsafe-history"), "치료 효과", PhraseTone.FIRM,
                PhraseCategory.REDIRECT, 2, PhraseValidationState.VALID),
        )
        val resolver = CustomPhraseResolver(repo)
        assertEquals(archived.text, resolver.resolve(archived.id).text)
        assertEquals(unsafe.text, resolver.resolve(unsafe.id).text)
        assertEquals(SafePhraseCatalog.fallback, resolver.resolve(PhraseId("missing")))
    }

    @Test fun freeGetsDefaultThemeAndProCanSelectApprovedTheme() = runTest {
        assertEquals(ThemeCatalog.default, ThemeResolver(DebugEntitlementRepository(Entitlement.FREE)).resolve("dusk"))
        assertEquals(ThemeCatalog.dusk, ThemeResolver(DebugEntitlementRepository(Entitlement.PRO)).resolve("dusk"))
        assertTrue(ThemeContrast.hasReadableContent(ThemeCatalog.default))
        assertTrue(ThemeContrast.hasReadableContent(ThemeCatalog.dusk))
        assertTrue(ThemeContrast.hasReadableAccent(ThemeCatalog.default))
        assertTrue(ThemeContrast.hasReadableAccent(ThemeCatalog.dusk))
    }

    @Test fun presetsArePerWidgetAndLaunchWritesGlobalBeforeReturn() = runTest {
        val store = InMemoryWidgetPresetStore()
        store.setPreset(11, 5); store.setPreset(12, 2)
        var global = 3
        assertEquals(5, PresetLaunchCoordinator(store).prepare(11) { global = it })
        assertEquals(5, global)
        assertEquals(2, store.preset(12))
        store.delete(11)
        assertNull(store.preset(11))
        assertFalse(store.snapshot().containsKey(11))
    }

    @Test fun presetLaunchHoldsAtomicWindowAgainstConcurrentUpdate() = runTest {
        val store = InMemoryWidgetPresetStore()
        store.setPreset(7, 5)
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        var global = 3
        val launch = async {
            PresetLaunchCoordinator(store).prepare(7) {
                entered.complete(Unit)
                release.await()
                global = it
            }
        }
        entered.await()
        val update = async { store.setPreset(7, 1) }
        assertFalse(update.isCompleted)
        release.complete(Unit)
        assertEquals(5, launch.await())
        update.await()
        assertEquals(5, global)
        assertEquals(1, store.preset(7))
    }

    @Test fun exportCarriesPhraseIdButNeverCustomText() {
        val event = StoredInjectionEvent(
            UUID.randomUUID(), Instant.EPOCH, Instant.ofEpochMilli(1_000), LocalDate.of(1970, 1, 1), 540,
            checkNotNull(Intensity.from(3)), com.maeumjaro.app.core.EntrySource.APP, PhraseId("custom-1"),
            1_800, 0, "test", Instant.EPOCH,
        )
        val text = String(CsvHistoryExporter.encode(listOf(event))!!, Charsets.UTF_8)
        assertTrue(text.contains("custom-1"))
        assertFalse(text.contains("custom text"))
    }
}
