package com.maeumjaro.app

import android.content.Context
import com.maeumjaro.app.billing.AndroidBillingGateway
import com.maeumjaro.app.billing.DataStoreBillingEntitlementCache
import com.maeumjaro.app.billing.PlayBillingEntitlementRepository
import com.maeumjaro.app.feature.analytics.Entitlement
import com.maeumjaro.app.feature.analytics.EntitlementRepository
import com.maeumjaro.app.feature.analytics.effectiveEntitlement
import com.maeumjaro.app.feature.customization.CustomPhraseResolver
import com.maeumjaro.app.feature.customization.CustomPhraseSelector
import com.maeumjaro.app.feature.customization.CustomizationController
import com.maeumjaro.app.feature.customization.WidgetPresetStore
import com.maeumjaro.app.feature.customization.PresetLaunchResult
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.data.local.MaeumjaroDatabase
import com.maeumjaro.app.data.local.RoomInjectionEventRepository
import com.maeumjaro.app.data.local.RoomCustomPhraseRepository
import com.maeumjaro.app.data.settings.AppStateStore
import com.maeumjaro.app.data.settings.AppStateStoreProvider
import com.maeumjaro.app.data.settings.LocalDateSource
import com.maeumjaro.app.data.settings.ReconcileTrigger
import com.maeumjaro.app.data.settings.ReconciliationResult
import com.maeumjaro.app.data.settings.TodayTotals
import com.maeumjaro.app.data.settings.TodayTotalsAuthority
import com.maeumjaro.app.data.settings.WidgetProjectionReconciler
import com.maeumjaro.app.feature.completion.CompleteInjectionUseCase
import com.maeumjaro.app.feature.completion.CompletionWidgetGateway
import com.maeumjaro.app.feature.completion.CompletionRepair
import com.maeumjaro.app.feature.completion.CompletionRepairTracker
import com.maeumjaro.app.feature.history.HistoryController
import com.maeumjaro.app.feature.history.HistoryMutationObserver
import com.maeumjaro.app.feature.export.ExportFileStore
import com.maeumjaro.app.widget.AndroidAllInstancesWidgetUpdater
import com.maeumjaro.app.widget.AndroidInstalledWidgetInventory
import java.time.Clock
import java.time.LocalDate
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.first

class AppContainer private constructor(context: Context) {
    private val appContext = context.applicationContext
    val clock: Clock = Clock.systemDefaultZone()
    val database: MaeumjaroDatabase by lazy { MaeumjaroDatabase.create(appContext) }
    val repository: RoomInjectionEventRepository by lazy { RoomInjectionEventRepository(database) }
    val appStateStore: AppStateStore by lazy { AppStateStoreProvider.get(appContext) }
    val billingGateway: AndroidBillingGateway by lazy { AndroidBillingGateway(appContext) }
    val billingRepository: PlayBillingEntitlementRepository by lazy {
        PlayBillingEntitlementRepository(
            gateway = billingGateway,
            cache = DataStoreBillingEntitlementCache(appStateStore) { clock.millis() },
        ).also { repository ->
            billingGateway.setPurchaseUpdateListener(
                listener = { repository.onPurchaseUpdated() },
                onFailure = repository::onPurchaseUpdateFailed,
            )
        }
    }
    val entitlements: EntitlementRepository = object : EntitlementRepository {
        override suspend fun current(): Entitlement = billingRepository.state.value.effectiveEntitlement()
    }
    val customPhraseRepository: RoomCustomPhraseRepository by lazy { RoomCustomPhraseRepository(database) }
    val customPhraseResolver: CustomPhraseResolver by lazy { CustomPhraseResolver(customPhraseRepository) }
    val customPhraseSelector: CustomPhraseSelector by lazy { CustomPhraseSelector(customPhraseRepository, kotlin.random.Random.Default) }
    val widgetPresetStore: WidgetPresetStore by lazy { DataStoreWidgetPresetStore(appStateStore, clock) }
    val customizationController: CustomizationController by lazy {
        CustomizationController(
            appStateStore,
            customPhraseRepository,
            entitlements,
            widgetPresetStore,
            AndroidInstalledWidgetInventory(appContext),
        )
    }
    val widgetGateway: CompletionWidgetGateway = CompletionWidgetGateway { AndroidAllInstancesWidgetUpdater(appContext).updateAll() }
    val exportFileStore: ExportFileStore by lazy { ExportFileStore(appContext) }
    val repairTracker = CompletionRepairTracker()
    val projectionReconciler: WidgetProjectionReconciler by lazy {
        WidgetProjectionReconciler(
            authority = TodayTotalsAuthority { rawDate ->
                repository.totalsForStoredDate(LocalDate.parse(rawDate)).let { TodayTotals(it.count, it.intensitySum) }
            },
            stateGateway = appStateStore,
            localDateSource = LocalDateSource { LocalDate.now(clock).toString() },
        )
    }
    val completeInjection: CompleteInjectionUseCase by lazy {
        CompleteInjectionUseCase(
            repository = repository,
            projectionReconciler = projectionReconciler,
            widgetGateway = widgetGateway,
            clock = clock,
            appVersion = BuildConfig.VERSION_NAME,
            diagnosticSink = repairTracker,
            phrasePool = { intensity ->
                customPhraseSelector.selectionPool(
                    com.maeumjaro.app.content.SafePhraseCatalog.phrases,
                    intensity,
                    entitlements.current(),
                )
            },
            phraseResolver = customPhraseResolver::resolve,
        )
    }
    val historyController: HistoryController by lazy {
        HistoryController(
            repository = repository,
            clock = clock,
            entitlements = entitlements,
            phraseResolver = customPhraseResolver,
            mutationObserver = HistoryMutationObserver {
                val result = projectionReconciler.reconcile(ReconcileTrigger.INDIVIDUAL_EDIT, clock.millis())
                if (result is ReconciliationResult.Failure) throw result.cause
                widgetGateway.updateAll()
            },
        )
    }

    suspend fun preferredPhraseTone(): PhraseTone = when (appStateStore.state.first().phraseTone) {
        com.maeumjaro.app.data.settings.PhraseTone.PHRASE_TONE_GENTLE -> PhraseTone.GENTLE
        com.maeumjaro.app.data.settings.PhraseTone.PHRASE_TONE_NEUTRAL -> PhraseTone.NEUTRAL
        com.maeumjaro.app.data.settings.PhraseTone.PHRASE_TONE_FIRM -> PhraseTone.FIRM
        else -> PhraseTone.AUTOMATIC
    }

    suspend fun reconcileForeground(): ReconciliationResult {
        val result = projectionReconciler.reconcile(ReconcileTrigger.FOREGROUND, clock.millis())
        var pending = if (result is ReconciliationResult.Failure) {
            setOf(CompletionRepair.PROJECTION)
        } else {
            emptySet()
        }
        try {
            widgetGateway.updateAll()
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: Exception) {
            pending = pending + CompletionRepair.WIDGET
        }
        repairTracker.recordPending(pending)
        return result
    }

    companion object {
        @Volatile private var instance: AppContainer? = null

        fun get(context: Context): AppContainer = instance ?: synchronized(this) {
            instance ?: AppContainer(context).also { instance = it }
        }
    }
}

private class DataStoreWidgetPresetStore(
    private val store: AppStateStore,
    private val clock: Clock,
) : WidgetPresetStore {
    override suspend fun preset(widgetId: Int): Int? = store.widgetPreset(widgetId)
    override suspend fun setPreset(widgetId: Int, intensity: Int) { store.setWidgetPreset(widgetId, intensity) }
    override suspend fun delete(widgetId: Int) { store.deleteWidgetPreset(widgetId) }
    override suspend fun snapshot(): Map<Int, Int> = store.widgetPresets()
    override suspend fun prepareLaunch(widgetId: Int, setGlobalIntensity: suspend (Int) -> Unit): PresetLaunchResult =
        when (val result = store.prepareLaunch(widgetId, clock.millis())) {
            is com.maeumjaro.app.data.settings.StoredPresetLaunchResult.Prepared -> {
                PresetLaunchResult.Prepared(result.intensity)
            }
            com.maeumjaro.app.data.settings.StoredPresetLaunchResult.NoPreset,
            com.maeumjaro.app.data.settings.StoredPresetLaunchResult.ProInactive,
            -> PresetLaunchResult.Global
        }
}
