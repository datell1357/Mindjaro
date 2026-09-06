package com.maeumjaro.app.content

import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class SafePhraseCatalogTest {
    @Test
    fun `given bundled catalog when audited then stable safe selection remains feasible after recent ten`() {
        // Given: the bundled reviewed phrase catalog.
        val phrases = SafePhraseCatalog.phrases

        // When: IDs and supported metadata are audited.
        val uniqueIds = phrases.map { it.id }.toSet()
        val intensityCounts = (1..5).associateWith { raw ->
            val intensity = checkNotNull(Intensity.from(raw))
            phrases.count { intensity in it.intensities }
        }

        // Then: it is large, unique, reviewed, categorized, and leaves candidates after ten exclusions.
        assertTrue(phrases.size >= 100)
        assertEquals(phrases.size, uniqueIds.size)
        assertTrue(phrases.all { it.safetyReviewed })
        assertTrue(PhraseCategory.entries.all { category -> phrases.any { it.category == category } })
        assertTrue(intensityCounts.values.all { it > 10 })
    }

    @Test
    fun `given missing or unsafe phrase when resolved then safe fallback is returned`() {
        // Given: an unknown phrase ID and an unsafe injected phrase.
        val unsafe = Phrase(
            id = PhraseId("unsafe-test"),
            text = "효능을 보장합니다",
            category = PhraseCategory.AUTONOMY,
            tone = PhraseTone.NEUTRAL,
            intensities = setOf(checkNotNull(Intensity.from(3))),
            safetyReviewed = false,
        )

        // When: each is resolved at the content boundary.
        val missingResult = SafePhraseCatalog.resolve(PhraseId("missing"))
        val unsafeResult = SafePhraseCatalog.resolve(unsafe)

        // Then: both use the safe built-in fallback.
        assertEquals(SafePhraseCatalog.fallback, missingResult)
        assertEquals(SafePhraseCatalog.fallback, unsafeResult)
    }

    @Test
    fun `given catalog and disclaimer when scanned then only explicit negative context passes`() {
        // Given: safe catalog copy, an explicit disclaimer, and positive unsafe claims.
        val safeCopy = SafePhraseCatalog.phrases.map { it.text }
        val disclaimer = SafetyCopy.disclaimer
        val positiveClaims = listOf("치료 효능을 보장합니다", "2mg 복용", "체중 감량 성공")

        // When: the content contract scans each input.
        val safeViolations = safeCopy.flatMap(ContentPolicy::violations)
        val disclaimerViolations = ContentPolicy.violations(disclaimer)
        val unsafeViolations = positiveClaims.flatMap(ContentPolicy::violations)

        // Then: safe inert data and explicit negative context pass while positive claims are blocked.
        assertTrue(safeViolations.isEmpty())
        assertTrue(disclaimerViolations.isEmpty())
        assertFalse(unsafeViolations.isEmpty())
    }

    @Test
    fun `given mixed positive claim and disclaimer fragment when scanned then claim is blocked`() {
        val mixed = "효능을 보장합니다. 의료기기가 아니며"

        assertTrue(ContentPolicy.violations(mixed).isNotEmpty())
    }

    @Test
    fun `given user facing resource strings when scanned then no unsafe claim is shipped`() {
        val resourceFile = File("src/main/res/values/strings.xml")
        val userFacing = Regex(">([^<]+)<").findAll(resourceFile.readText()).map { it.groupValues[1] }
            .filterNot { it == SafetyCopy.disclaimer }
        val violations = userFacing.flatMap(ContentPolicy::violations)

        assertTrue(violations.none())
    }
}
