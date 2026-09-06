package com.maeumjaro.app.feature.onboarding

import com.maeumjaro.app.core.Intensity
import kotlinx.coroutines.flow.Flow

data class OnboardingSettings(
    val completed: Boolean,
    val intensity: Intensity,
)

interface OnboardingPersistence {
    val settings: Flow<OnboardingSettings>
    suspend fun complete(intensity: Intensity)
}
