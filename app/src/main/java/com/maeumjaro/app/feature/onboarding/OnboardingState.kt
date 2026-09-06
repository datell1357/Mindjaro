package com.maeumjaro.app.feature.onboarding

import com.maeumjaro.app.core.Intensity

enum class OnboardingStep {
    Purpose,
    UseFlow,
    Intensity,
    Disclaimer,
    Widget,
}

data class OnboardingState(
    val step: OnboardingStep,
    val intensity: Intensity,
    val widgetPinRequested: Boolean,
    val readyToComplete: Boolean,
) {
    fun next(): OnboardingState {
        val nextIndex = (step.ordinal + 1).coerceAtMost(OnboardingStep.entries.lastIndex)
        return copy(step = OnboardingStep.entries[nextIndex])
    }

    fun selectIntensity(rawValue: Int): OnboardingState =
        Intensity.from(rawValue)?.let { copy(intensity = it) } ?: this

    fun requestWidgetPin(): OnboardingState = copy(widgetPinRequested = true)

    fun skipWidget(): OnboardingState = copy(readyToComplete = true)

    companion object {
        fun initial(intensity: Intensity = checkNotNull(Intensity.from(3))) = OnboardingState(
            step = OnboardingStep.Purpose,
            intensity = intensity,
            widgetPinRequested = false,
            readyToComplete = false,
        )
    }
}
