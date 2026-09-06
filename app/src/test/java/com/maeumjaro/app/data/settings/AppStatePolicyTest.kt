package com.maeumjaro.app.data.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppStatePolicyTest {
    @Test
    fun `uses safe defaults when fields are missing`() {
        // Given: a proto whose optional settings were never written.
        val missing = AppState.getDefaultInstance()

        // When: the persistence boundary normalizes it.
        val normalized = AppStatePolicy.normalize(missing)

        // Then: product defaults are explicit and safe.
        assertEquals(3, normalized.intensity)
        assertTrue(normalized.hapticEnabled)
        assertFalse(normalized.soundEnabled)
        assertEquals(PhraseTone.PHRASE_TONE_AUTOMATIC, normalized.phraseTone)
        assertEquals("default", normalized.themeId)
    }

    @Test
    fun `uses intensity three when stored value is out of range`() {
        // Given: malformed-but-parseable persisted intensities.
        val invalid = listOf(-1, 0, 6, Int.MAX_VALUE)

        // When: each value crosses the persistence boundary.
        val normalized = invalid.map {
            AppStatePolicy.normalize(AppState.newBuilder().setIntensity(it).build()).intensity
        }

        // Then: every invalid value becomes the neutral default.
        assertEquals(listOf(3, 3, 3, 3), normalized)
    }
}
