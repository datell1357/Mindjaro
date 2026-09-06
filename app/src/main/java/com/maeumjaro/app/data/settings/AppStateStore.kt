package com.maeumjaro.app.data.settings

import android.content.Context
import com.maeumjaro.app.billing.PRO_LIFETIME_PRODUCT_ID
import androidx.datastore.core.DataStore
import androidx.datastore.core.DataStoreFactory
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.datastore.dataStoreFile
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

interface AppStateGateway {
    val state: Flow<AppState>

    suspend fun update(transform: suspend (AppState) -> AppState): AppState
}

data class IntensityUpdate(val intensity: Int, val updatedAtEpochMillis: Long) {
    init {
        require(intensity in 1..5)
        require(updatedAtEpochMillis >= 0)
    }
}

data class ConfirmedEntitlementCache(
    val status: EntitlementStatus,
    val productId: String,
    val lastVerifiedAtEpochMillis: Long,
) {
}

fun AppState.hasConfirmedProEntitlement(): Boolean =
    hasEntitlementCache() &&
        entitlementCache.status == EntitlementStatus.ENTITLEMENT_STATUS_PRO &&
        entitlementCache.productId == PRO_LIFETIME_PRODUCT_ID &&
        entitlementCache.lastVerifiedAtEpochMillis >= 0

sealed interface StoredPresetLaunchResult {
    data class Prepared(val intensity: Int) : StoredPresetLaunchResult
    data object NoPreset : StoredPresetLaunchResult
    data object ProInactive : StoredPresetLaunchResult
}

class AppStateStore(private val dataStore: DataStore<AppState>) : AppStateGateway {
    override val state: Flow<AppState> = dataStore.data
        .catch { error ->
            if (error is IOException) emit(AppStateSerializer.defaultValue) else throw error
        }
        .map(AppStatePolicy::normalize)

    override suspend fun update(transform: suspend (AppState) -> AppState): AppState =
        dataStore.updateData { current -> AppStatePolicy.normalize(transform(AppStatePolicy.normalize(current))) }

    suspend fun setIntensity(update: IntensityUpdate): AppState = update { current ->
        current.toBuilder()
            .setIntensity(update.intensity)
            .setIntensityUpdatedAtEpochMillis(update.updatedAtEpochMillis)
            .build()
    }

    suspend fun setOnboardingCompleted(completed: Boolean): AppState = update { current ->
        current.toBuilder().setOnboardingCompleted(completed).build()
    }

    suspend fun setHapticEnabled(enabled: Boolean): AppState = update { current ->
        current.toBuilder().setHapticEnabled(enabled).build()
    }

    suspend fun setSoundEnabled(enabled: Boolean): AppState = update { current ->
        current.toBuilder().setSoundEnabled(enabled).build()
    }

    suspend fun setReducedMotionEnabled(enabled: Boolean): AppState = update { current ->
        current.toBuilder().setReducedMotionEnabled(enabled).build()
    }

    suspend fun setPhraseTone(tone: PhraseTone): AppState = update { current ->
        current.toBuilder().setPhraseTone(tone).build()
    }

    suspend fun setWidgetGuideCompleted(completed: Boolean): AppState = update { current ->
        current.toBuilder().setWidgetGuideCompleted(completed).build()
    }

    suspend fun setThemeId(themeId: String): AppState = update { current ->
        current.toBuilder().setThemeId(themeId.trim()).build()
    }

    /** Writes a per-widget intensity without changing the global intensity. */
    suspend fun setWidgetPreset(appWidgetId: Int, intensity: Int): AppState {
        require(appWidgetId > 0)
        require(intensity in 1..5)
        return update { current ->
            val builder = current.toBuilder()
            builder.clearWidgetPresets()
            current.widgetPresetsList
                .filterNot { it.appWidgetId == appWidgetId }
                .forEach(builder::addWidgetPresets)
            builder.addWidgetPresets(
                WidgetPreset.newBuilder()
                    .setAppWidgetId(appWidgetId)
                    .setIntensity(intensity)
                    .build(),
            )
            builder.build()
        }
    }

    suspend fun deleteWidgetPreset(appWidgetId: Int): AppState = update { current ->
        val builder = current.toBuilder().clearWidgetPresets()
        current.widgetPresetsList
            .filterNot { it.appWidgetId == appWidgetId }
            .forEach(builder::addWidgetPresets)
        builder.build()
    }

    /** Removes all deleted widget presets in one DataStore transaction. */
    suspend fun deleteWidgetPresets(appWidgetIds: Collection<Int>): AppState {
        val ids = appWidgetIds.toSet()
        if (ids.isEmpty()) return state.first()
        return update { current ->
            current.toBuilder()
                .clearWidgetPresets()
                .also { builder ->
                    current.widgetPresetsList
                        .filterNot { it.appWidgetId in ids }
                        .forEach(builder::addWidgetPresets)
                }
                .build()
        }
    }

    suspend fun widgetPreset(appWidgetId: Int): Int? = state.first()
        .widgetPresetsList
        .firstOrNull { it.appWidgetId == appWidgetId }
        ?.intensity

    suspend fun widgetPresets(): Map<Int, Int> = state.first()
        .widgetPresetsList
        .associate { it.appWidgetId to it.intensity }

    suspend fun setEntitlementCache(
        status: EntitlementStatus,
        productId: String,
        lastVerifiedAtEpochMillis: Long,
    ): AppState = update { current ->
        require(lastVerifiedAtEpochMillis >= 0)
        current.toBuilder()
            .setEntitlementCache(
                EntitlementCache.newBuilder()
                    .setStatus(status)
                    .setProductId(productId.trim())
                    .setLastVerifiedAtEpochMillis(lastVerifiedAtEpochMillis)
                    .build(),
            )
            .build()
    }

    suspend fun writeConfirmedPro(
        productId: String,
        lastVerifiedAtEpochMillis: Long,
    ): AppState = setEntitlementCache(
        EntitlementStatus.ENTITLEMENT_STATUS_PRO,
        productId,
        lastVerifiedAtEpochMillis,
    )

    suspend fun clearConfirmedEntitlementCache(): AppState = update { current ->
        current.toBuilder().clearEntitlementCache().build()
    }

    suspend fun confirmedEntitlementCache(): ConfirmedEntitlementCache? =
        confirmedEntitlementCache(state.first())

    fun confirmedEntitlementCache(value: AppState): ConfirmedEntitlementCache? =
        if (!value.hasConfirmedProEntitlement()) null else value.entitlementCache.let {
                ConfirmedEntitlementCache(
                    status = it.status,
                    productId = it.productId,
                    lastVerifiedAtEpochMillis = it.lastVerifiedAtEpochMillis,
                )
            }

    /**
     * Atomically applies a stored Pro widget preset to the global intensity.
     * There is exactly one DataStore updateData transaction, so readers never
     * observe the preset and global intensity between two writes.
     */
    suspend fun prepareLaunch(
        appWidgetId: Int,
        updatedAtEpochMillis: Long,
    ): StoredPresetLaunchResult {
        require(updatedAtEpochMillis >= 0)
        var result: StoredPresetLaunchResult = StoredPresetLaunchResult.NoPreset
        dataStore.updateData { current ->
            val normalized = AppStatePolicy.normalize(current)
            val cache = confirmedEntitlementCache(normalized)
            val preset = normalized.widgetPresetsList.firstOrNull { it.appWidgetId == appWidgetId }
            result = when {
                cache == null -> StoredPresetLaunchResult.ProInactive
                preset == null -> StoredPresetLaunchResult.NoPreset
                else -> StoredPresetLaunchResult.Prepared(preset.intensity)
            }
            if (result is StoredPresetLaunchResult.Prepared) {
                normalized.toBuilder()
                    .setIntensity(preset!!.intensity)
                    .setIntensityUpdatedAtEpochMillis(updatedAtEpochMillis)
                    .build()
            } else {
                normalized
            }
        }
        return result
    }

    companion object {
        fun create(
            context: Context,
            scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
        ): AppStateStore = AppStateStore(
            DataStoreFactory.create(
                serializer = AppStateSerializer,
                corruptionHandler = ReplaceFileCorruptionHandler { AppStateSerializer.defaultValue },
                scope = scope,
                produceFile = { context.dataStoreFile("app_state.pb") },
            ),
        )
    }
}
