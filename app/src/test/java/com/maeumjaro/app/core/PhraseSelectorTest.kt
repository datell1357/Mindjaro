package com.maeumjaro.app.core

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhraseSelectorTest {
    private val intensity = Intensity.from(3)!!
    private fun phrase(number: Int, category: PhraseCategory, reviewed: Boolean = true) = Phrase(
        id = PhraseId("phrase-$number"), text = "안전한 문구 $number", category = category,
        tone = PhraseTone.NEUTRAL, intensities = setOf(intensity), safetyReviewed = reviewed,
    )

    @Test fun `Given reviewed pool When selecting Then recent ten previous category and unsafe data are excluded`() {
        val pool = (0..12).map { phrase(it, if (it == 12) PhraseCategory.REDIRECT else PhraseCategory.SEPARATION) } + phrase(99, PhraseCategory.REDIRECT, false)
        val selected = PhraseSelector(Random(7)).select(PhraseSelection(pool, intensity, (2..11).map { PhraseId("phrase-$it") }, PhraseCategory.SEPARATION))
        assertEquals(PhraseId("phrase-12"), selected.id)
        assertTrue(selected.safetyReviewed)
        assertFalse(selected.id in (2..11).map { PhraseId("phrase-$it") })
    }

    @Test fun `Given no eligible phrase When selecting Then safe reviewed fallback is returned`() {
        val pool = listOf(phrase(1, PhraseCategory.SEPARATION, false), phrase(2, PhraseCategory.SEPARATION))
        val selected = PhraseSelector(Random(1)).select(PhraseSelection(pool, intensity, listOf(PhraseId("phrase-2")), PhraseCategory.SEPARATION))
        assertEquals(SafePhraseFallback.phrase, selected)
        assertTrue(selected.safetyReviewed)
    }
}
