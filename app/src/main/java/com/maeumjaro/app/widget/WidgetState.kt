package com.maeumjaro.app.widget

import android.content.Context
import com.maeumjaro.app.data.settings.AppState
import com.maeumjaro.app.data.settings.AppStatePolicy
import com.maeumjaro.app.data.settings.AppStateStore
import com.maeumjaro.app.data.settings.AppStateStoreProvider
import com.maeumjaro.app.data.settings.WidgetPreset
import com.maeumjaro.app.data.settings.WidgetSnapshot
import com.maeumjaro.app.data.settings.hasConfirmedProEntitlement
import java.time.Clock
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/** Minimal persisted state consumed by the widget process. Room is intentionally absent. */
data class WidgetState(
    val intensity: Int,
    val todayCount: Int,
    val todayIntensitySum: Int,
    val appWidgetId: Int? = null,
    val usesPreset: Boolean = false,
) {
    val summary: String get() = "오늘 ${todayCount}회 · 강도 합계 ${todayIntensitySum}"
}

interface WidgetStateGateway {
    val state: Flow<WidgetState>
    suspend fun changeIntensity(delta: Int): WidgetState
}

class DataStoreWidgetStateGateway(
    private val store: AppStateStore,
    private val clock: Clock = Clock.systemDefaultZone(),
    private val appWidgetId: Int? = null,
) : WidgetStateGateway {
    override val state: Flow<WidgetState> = store.state.map { value ->
        value.toWidgetState(LocalDate.now(clock), appWidgetId)
    }

    override suspend fun changeIntensity(delta: Int): WidgetState {
        require(delta == -1 || delta == 1) { "Widget intensity changes are one step at a time." }
        val updated = store.update { current ->
            val preset = appWidgetId?.takeIf { current.hasConfirmedProEntitlement() }?.let { id ->
                current.widgetPresetsList.firstOrNull { it.appWidgetId == id }
            }
            val intensity = preset?.intensity?.takeIf { it in 1..5 }
                ?: current.normalizedIntensity()
            val nextIntensity = (intensity + delta).coerceIn(1, 5)
            if (preset != null) {
                val builder = current.toBuilder().clearWidgetPresets()
                current.widgetPresetsList
                    .filterNot { it.appWidgetId == appWidgetId }
                    .forEach(builder::addWidgetPresets)
                builder.addWidgetPresets(
                    WidgetPreset.newBuilder()
                        .setAppWidgetId(appWidgetId)
                        .setIntensity(nextIntensity)
                        .build(),
                )
                builder.build()
            } else {
                current.toBuilder()
                    .setIntensity(nextIntensity)
                    .setIntensityUpdatedAtEpochMillis(clock.millis())
                    .build()
            }
        }
        return updated.toWidgetState(LocalDate.now(clock), appWidgetId)
    }

    private fun AppState.normalizedIntensity(): Int =
        if (hasIntensity() && intensity in 1..5) intensity else 3
}

private fun AppState.toWidgetState(date: LocalDate, appWidgetId: Int? = null): WidgetState {
    val snapshot = WidgetSnapshot.from(AppStatePolicy.normalize(this), date.toString())
    val hasConfirmedPro = hasConfirmedProEntitlement()
    val presetIntensity = appWidgetId?.takeIf { hasConfirmedPro }?.let { id ->
        widgetPresetsList.firstOrNull { it.appWidgetId == id }
            ?.intensity
            ?.takeIf { it in 1..5 }
    }
    return WidgetState(
        presetIntensity ?: snapshot.intensity.coerceIn(1, 5),
        snapshot.count,
        snapshot.intensitySum,
        appWidgetId,
        presetIntensity != null,
    )
}

object WidgetStateFactory {
    fun create(
        context: Context,
        clock: Clock = Clock.systemDefaultZone(),
        appWidgetId: Int? = null,
    ): WidgetStateGateway = DataStoreWidgetStateGateway(
        AppStateStoreProvider.get(context),
        clock,
        appWidgetId,
    )
}
