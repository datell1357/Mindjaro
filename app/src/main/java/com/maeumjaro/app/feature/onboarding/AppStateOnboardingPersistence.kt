package com.maeumjaro.app.feature.onboarding

import android.content.Context
import com.maeumjaro.app.core.Intensity
import com.maeumjaro.app.data.settings.AppStateStore
import com.maeumjaro.app.data.settings.AppStateStoreProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class AppStateOnboardingPersistence(
    private val store: AppStateStore,
) : OnboardingPersistence {
    override val settings: Flow<OnboardingSettings> = store.state.map { state ->
        OnboardingSettings(
            completed = state.onboardingCompleted,
            intensity = Intensity.from(state.intensity) ?: checkNotNull(Intensity.from(3)),
        )
    }

    override suspend fun complete(intensity: Intensity) {
        store.update { current ->
            current.toBuilder()
                .setIntensity(intensity.value)
                .setIntensityUpdatedAtEpochMillis(System.currentTimeMillis())
                .setOnboardingCompleted(true)
                .build()
        }
    }
}

object OnboardingStoreProvider {
    fun get(context: Context): AppStateStore = AppStateStoreProvider.get(context)
}
