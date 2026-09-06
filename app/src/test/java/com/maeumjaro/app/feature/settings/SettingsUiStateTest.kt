package com.maeumjaro.app.feature.settings

import org.junit.Assert.assertEquals
import org.junit.Test

class SettingsUiStateTest {
    @Test fun `defaults match product contract`() {
        val state = SettingsUiState()
        assertEquals(3, state.intensity)
        assertEquals(true, state.hapticEnabled)
        assertEquals(false, state.soundEnabled)
        assertEquals(false, state.reducedMotionEnabled)
    }
}
