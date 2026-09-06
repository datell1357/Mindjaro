package com.maeumjaro.app.feature.onboarding

import com.maeumjaro.app.core.Intensity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OnboardingStateTest {
    @Test
    fun `given onboarding contract when loaded then it has exactly five ordered steps`() {
        // Given: the bundled onboarding contract.
        // When: its steps are loaded.
        val steps = OnboardingStep.entries

        // Then: all five safety and setup steps are present.
        assertEquals(5, steps.size)
        assertEquals(
            listOf(
                OnboardingStep.Purpose,
                OnboardingStep.UseFlow,
                OnboardingStep.Intensity,
                OnboardingStep.Disclaimer,
                OnboardingStep.Widget,
            ),
            steps,
        )
    }

    @Test
    fun `given fresh state when intensity four is selected then selection is retained`() {
        // Given: a fresh onboarding state at the default intensity.
        val state = OnboardingState.initial()

        // When: the user selects intensity four.
        val updated = state.selectIntensity(4)

        // Then: the valid selection is retained.
        assertEquals(4, updated.intensity.value)
    }

    @Test
    fun `given fresh state when invalid intensity is selected then input is rejected`() {
        // Given: the supported intensity boundary.
        // When: an invalid value is parsed.
        val parsed = Intensity.from(6)

        // Then: the malformed value is rejected.
        assertNull(parsed)
    }

    @Test
    fun `given widget step when skipped then onboarding can complete without pin request`() {
        // Given: the optional widget step.
        val state = OnboardingState.initial().copy(step = OnboardingStep.Widget)

        // When: the user skips pinning.
        val result = state.skipWidget()

        // Then: completion is ready and no pin request is recorded.
        assertTrue(result.readyToComplete)
        assertFalse(result.widgetPinRequested)
    }
}
