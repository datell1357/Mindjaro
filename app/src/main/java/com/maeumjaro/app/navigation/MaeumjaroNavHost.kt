package com.maeumjaro.app.navigation

import android.content.Intent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.maeumjaro.app.AppContainer
import com.maeumjaro.app.R
import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.core.EntrySource
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.design.PrimaryAction
import com.maeumjaro.app.design.SecondaryAction
import com.maeumjaro.app.feature.completion.CompletionScreen
import com.maeumjaro.app.feature.completion.InjectionCompletionRoute
import com.maeumjaro.app.feature.history.DayDetailState
import com.maeumjaro.app.feature.history.HistoryDashboardState
import com.maeumjaro.app.feature.history.HistoryRecordItem
import com.maeumjaro.app.feature.history.RecordDetailState
import com.maeumjaro.app.feature.history.ui.DayDetailSheet
import com.maeumjaro.app.feature.history.ui.HistoryDashboard
import com.maeumjaro.app.feature.history.ui.RecordDetailSheet
import com.maeumjaro.app.feature.settings.SettingsScreen
import com.maeumjaro.app.feature.settings.SettingsUiState
import com.maeumjaro.app.feature.settings.SettingsDeleteController
import com.maeumjaro.app.feature.settings.SettingsDeleteResult
import com.maeumjaro.app.feature.settings.SettingsDeleteStatus
import com.maeumjaro.app.feature.settings.SettingsOperationController
import com.maeumjaro.app.feature.settings.SettingsOperationResult
import com.maeumjaro.app.feature.settings.SettingsOperationStatus
import com.maeumjaro.app.feature.settings.SettingsExportController
import com.maeumjaro.app.feature.settings.SettingsExportResult
import com.maeumjaro.app.feature.analytics.ProAnalyticsScreen
import com.maeumjaro.app.feature.analytics.JsonExportController
import com.maeumjaro.app.feature.analytics.JsonExportOperationResult
import com.maeumjaro.app.feature.analytics.JsonExportStatus
import com.maeumjaro.app.feature.analytics.Entitlement
import com.maeumjaro.app.feature.analytics.effectiveEntitlement
import com.maeumjaro.app.feature.customization.CustomizationScreen
import com.maeumjaro.app.feature.customization.PhraseSaveResult
import com.maeumjaro.app.billing.AndroidBillingActivityHandle
import com.maeumjaro.app.feature.export.ExportShareIntent
import com.maeumjaro.app.data.settings.PhraseTone as StoredPhraseTone
import com.maeumjaro.app.feature.injection.InjectionViewModel
import com.maeumjaro.app.feature.onboarding.OnboardingPersistence
import com.maeumjaro.app.feature.onboarding.OnboardingScreen
import com.maeumjaro.app.feature.onboarding.OnboardingSettings
import com.maeumjaro.app.feature.onboarding.WidgetPinRequester
import com.maeumjaro.app.feature.shell.SafetyShell
import java.util.UUID
import kotlinx.coroutines.launch

@Composable
fun MaeumjaroNavHost(
    plan: LaunchPlan,
    settings: OnboardingSettings,
    persistence: OnboardingPersistence,
    pinRequester: WidgetPinRequester,
    container: AppContainer,
    launchSource: EntrySource,
) {
    val navController = rememberNavController()
    val scope = rememberCoroutineScope()
    var injectionSource by remember { mutableStateOf(launchSource) }
    var injectionRun by remember { mutableIntStateOf(0) }
    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.TopCenter) {
            NavHost(navController, plan.start.path, Modifier.widthIn(max = 430.dp)) {
                composable(AppRoute.Onboarding.path) {
                    OnboardingScreen(
                        initialIntensity = settings.intensity.value,
                        pinRequester = pinRequester,
                        onComplete = { rawIntensity ->
                            scope.launch {
                                persistence.complete(checkNotNull(com.maeumjaro.app.core.Intensity.from(rawIntensity)))
                                navController.navigate(plan.afterOnboarding.path) {
                                    popUpTo(AppRoute.Onboarding.path) { inclusive = true }
                                }
                            }
                        },
                    )
                }
                composable(AppRoute.Records.path) {
                    HistoryRoute(
                        container,
                        onStartInjection = {
                            injectionSource = EntrySource.APP
                            injectionRun += 1
                            navController.navigate(AppRoute.Injection.path)
                        },
                        onRecordSelected = { navController.navigate(AppRoute.RecordDetail.pathForEvent(it.id.toString())) },
                        onOpenSettings = { navController.navigate(AppRoute.Settings.path) },
                        onOpenSafety = { navController.navigate(AppRoute.Safety.path) },
                    )
                }
                composable(AppRoute.Settings.path) {
                    SettingsRoute(
                        container,
                        onOpenPro = { navController.navigate(AppRoute.Pro.path) },
                        onOpenCustomization = { navController.navigate(AppRoute.Customization.path) },
                        onOpenAnalytics = { navController.navigate(AppRoute.Analytics.path) },
                    )
                }
                composable(AppRoute.Injection.path) {
                    val appState by androidx.compose.runtime.produceState<com.maeumjaro.app.data.settings.AppState?>(null, container.appStateStore) {
                        container.appStateStore.state.collect { value = it }
                    }
                    val injectionViewModel: InjectionViewModel = viewModel(
                        key = "injection-${injectionSource.name}-$injectionRun",
                        factory = injectionViewModelFactory(container, settings, injectionSource),
                    )
                    LaunchedEffect(appState, injectionViewModel) {
                        appState?.let { injectionViewModel.updatePreferences(it.reducedMotionEnabled, it.hapticEnabled, it.soundEnabled) }
                    }
                    InjectionCompletionRoute(
                        viewModel = injectionViewModel,
                        onCompleted = { success ->
                            navController.navigate(
                                AppRoute.Completion.pathForEvent(
                                    success.attempt.event.id.toString(),
                                    repairPending = success.pendingRepairs.isNotEmpty(),
                                ),
                            ) {
                                popUpTo(AppRoute.Injection.path) { inclusive = true }
                            }
                        },
                    )
                }
                composable(
                    AppRoute.Completion.path,
                    listOf(
                        navArgument("eventId") { type = NavType.StringType },
                        navArgument("repairPending") { type = NavType.BoolType; defaultValue = false },
                    ),
                ) { entry ->
                    val id = entry.arguments?.getString("eventId")?.let(UUID::fromString)
                    val repairPending = entry.arguments?.getBoolean("repairPending") ?: false
                    var event by remember(id) { mutableStateOf<StoredInjectionEvent?>(null) }
                    var phrase by remember(id) { mutableStateOf<com.maeumjaro.app.core.Phrase?>(null) }
                    LaunchedEffect(id) {
                        event = id?.let { container.repository.event(it) }
                        phrase = event?.let { container.customPhraseResolver.resolve(it.phraseId) }
                    }
                    val loadedEvent = event
                    val loadedPhrase = phrase
                    if (loadedEvent != null && loadedPhrase != null) {
                        CompletionScreen(
                            event = loadedEvent,
                            phrase = loadedPhrase,
                            onAgain = {
                                injectionSource = EntrySource.APP
                                injectionRun += 1
                                navController.navigate(AppRoute.Injection.path) {
                                    popUpTo(AppRoute.Completion.path) { inclusive = true }
                                }
                            },
                            onViewRecords = navController::returnToRecords,
                            projectionPending = repairPending,
                        )
                    } else Text("기록을 불러오는 중")
                }
                composable(
                    AppRoute.RecordDetail.path,
                    listOf(navArgument("eventId") { type = NavType.StringType }),
                ) { entry ->
                    val id = entry.arguments?.getString("eventId")?.let(UUID::fromString)
                    RecordDetailRoute(container, id, navController::popBackStack)
                }
                composable(AppRoute.Safety.path) { SafetyShell(navController::returnToRecords) }
                composable(AppRoute.Pro.path) {
                    ProRoute(container, navController::returnToRecords)
                }
                composable(AppRoute.Customization.path) {
                    CustomizationRoute(container, navController::returnToRecords)
                }
                composable(AppRoute.Analytics.path) {
                    AnalyticsRoute(container, navController::returnToRecords)
                }
            }
        }
    }
}

@Composable
private fun SettingsRoute(container: AppContainer, onOpenPro: () -> Unit, onOpenCustomization: () -> Unit, onOpenAnalytics: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val state by androidx.compose.runtime.produceState<com.maeumjaro.app.data.settings.AppState?>(null, container.appStateStore) {
        container.appStateStore.state.collect { value = it }
    }
    val loaded = state ?: return
    var deleteStatus by remember { mutableStateOf(SettingsDeleteStatus.Idle) }
    var intensityStatus by remember { mutableStateOf(SettingsOperationStatus.Idle) }
    var exportStatus by remember { mutableStateOf(SettingsOperationStatus.Idle) }
    var intensityRetryValue by remember { mutableIntStateOf(loaded.intensity) }
    val deleteController = remember(container) {
        SettingsDeleteController(container.repository, container.projectionReconciler, container.widgetGateway, container.repairTracker) { container.clock.millis() }
    }
    val operationController = remember(container) {
        SettingsOperationController(container.projectionReconciler, container.widgetGateway, container.repairTracker) { container.clock.millis() }
    }
    fun applyIntensity(value: Int) {
        intensityRetryValue = value
        scope.launch {
            intensityStatus = SettingsOperationStatus.Working
            intensityStatus = when (operationController.intensityChanged {
                container.appStateStore.setIntensity(com.maeumjaro.app.data.settings.IntensityUpdate(value, container.clock.millis()))
            }) {
                SettingsOperationResult.Success -> SettingsOperationStatus.Idle
                SettingsOperationResult.Failure -> SettingsOperationStatus.Failure
            }
        }
    }
    fun export() {
        scope.launch {
            exportStatus = SettingsOperationStatus.Working
            val result = SettingsExportController(
                prepare = {
                    container.exportFileStore.writeCsv(container.repository.chronologicalExport())
                        ?: throw IllegalStateException("export unavailable")
                },
                share = { file ->
                    context.startActivity(Intent.createChooser(ExportShareIntent.create(context, file), "기록 내보내기"))
                },
            ).export()
            exportStatus = when (result) {
                SettingsExportResult.Success -> SettingsOperationStatus.Idle
                SettingsExportResult.Failure -> SettingsOperationStatus.Failure
            }
        }
    }
    fun deleteAll() {
        scope.launch {
            deleteStatus = SettingsDeleteStatus.Deleting
            deleteStatus = when (deleteController.deleteAll()) {
                SettingsDeleteResult.Deleted -> SettingsDeleteStatus.Idle
                SettingsDeleteResult.ProjectionPending -> SettingsDeleteStatus.ProjectionPending
                SettingsDeleteResult.DatabaseFailure -> SettingsDeleteStatus.DatabaseFailure
            }
        }
    }
    val toneLabel = when (loaded.phraseTone) {
        StoredPhraseTone.PHRASE_TONE_GENTLE -> "부드럽게"
        StoredPhraseTone.PHRASE_TONE_NEUTRAL -> "중립적으로"
        StoredPhraseTone.PHRASE_TONE_FIRM -> "단호하게"
        else -> "자동"
    }
    SettingsScreen(
        state = SettingsUiState(loaded.intensity, loaded.hapticEnabled, loaded.soundEnabled, loaded.reducedMotionEnabled, toneLabel, deleteStatus, intensityStatus, exportStatus),
        onIntensityChanged = ::applyIntensity,
        onHapticChanged = { value -> scope.launch { container.appStateStore.setHapticEnabled(value) } },
        onSoundChanged = { value -> scope.launch { container.appStateStore.setSoundEnabled(value) } },
        onReducedMotionChanged = { value -> scope.launch { container.appStateStore.setReducedMotionEnabled(value) } },
        onPhraseToneChanged = {
            val next = when (loaded.phraseTone) {
                StoredPhraseTone.PHRASE_TONE_AUTOMATIC -> StoredPhraseTone.PHRASE_TONE_GENTLE
                StoredPhraseTone.PHRASE_TONE_GENTLE -> StoredPhraseTone.PHRASE_TONE_NEUTRAL
                StoredPhraseTone.PHRASE_TONE_NEUTRAL -> StoredPhraseTone.PHRASE_TONE_FIRM
                else -> StoredPhraseTone.PHRASE_TONE_AUTOMATIC
            }
            scope.launch { container.appStateStore.setPhraseTone(next) }
        },
        onExport = {
            export()
        },
        onRetryIntensity = { applyIntensity(intensityRetryValue) },
        onRetryExport = ::export,
        onDeleteAll = {
            deleteAll()
        },
        onRetryDeleteAll = ::deleteAll,
        onOpenPro = onOpenPro,
        onOpenCustomization = onOpenCustomization,
        onOpenAnalytics = onOpenAnalytics,
        modifier = Modifier.fillMaxSize(),
    )
}

@Composable
private fun HistoryRoute(
    container: AppContainer,
    onStartInjection: () -> Unit,
    onRecordSelected: (HistoryRecordItem) -> Unit,
    onOpenSettings: () -> Unit,
    onOpenSafety: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val billingState by container.billingRepository.state.collectAsState()
    val entitlement = billingState.effectiveEntitlement()
    var dashboard by remember { mutableStateOf<HistoryDashboardState?>(null) }
    var day by remember { mutableStateOf<DayDetailState?>(null) }
    LaunchedEffect(billingState) {
        // Do not leave a Pro snapshot on screen while the authoritative state is changing.
        dashboard = null
        dashboard = container.historyController.dashboard(entitlement)
    }
    dashboard?.takeIf { it.entitlement == entitlement }?.let { loaded ->
        Column(Modifier.fillMaxSize()) {
            HistoryDashboard(
                loaded,
                onDaySelected = { date -> scope.launch { day = container.historyController.day(date) } },
                onRecordSelected = onRecordSelected,
                modifier = Modifier.weight(1f),
            )
            PrimaryAction("마음 정리 시작", onStartInjection)
            SecondaryAction("설정", onOpenSettings)
            SecondaryAction("안전 안내", onOpenSafety)
        }
    } ?: Text("기록을 불러오는 중")
    day?.let { detail -> DayDetailSheet(detail, { day = null }, onRecordSelected) }
}

@Composable
private fun RecordDetailRoute(container: AppContainer, id: UUID?, onDismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    var detail by remember(id) { mutableStateOf<RecordDetailState?>(null) }
    LaunchedEffect(id) { detail = id?.let { container.historyController.record(it) } }
    detail?.let { loaded ->
        RecordDetailSheet(
            detail = loaded,
            onDismiss = onDismiss,
            onIntensityChanged = { value ->
                scope.launch {
                    container.historyController.correctIntensity(loaded.id, value)
                    detail = container.historyController.record(loaded.id)
                }
            },
            onDeleteConfirmed = { scope.launch { container.historyController.delete(loaded.id, true); onDismiss() } },
        )
    } ?: Column {
        Text(stringResource(R.string.record_detail_title), style = MaterialTheme.typography.headlineMedium)
        Text(stringResource(R.string.record_detail_body))
    }
}

@Composable
private fun CustomizationRoute(container: AppContainer, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    val billingState by container.billingRepository.state.collectAsState()
    val entitlement = billingState.effectiveEntitlement()
    var state by remember { mutableStateOf<com.maeumjaro.app.feature.customization.CustomizationUiState?>(null) }
    var phraseError by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(entitlement) { state = container.customizationController.load() }
    state?.takeIf { it.entitlement == entitlement }?.let { loaded ->
        Column(Modifier.fillMaxSize()) {
            CustomizationScreen(
                state = loaded,
                onSavePhrase = { text, tone, category ->
                    scope.launch {
                        val result = container.customizationController.savePhrase(
                            text, tone, category, nowEpochMillis = container.clock.millis(),
                        )
                        state = when (result) {
                            is PhraseSaveResult.Saved -> { phraseError = null; container.customizationController.load() }
                            is PhraseSaveResult.Rejected -> { phraseError = "이 문구는 저장할 수 없어요: ${result.validation.reasons.joinToString(", ")}"; container.customizationController.load() }
                            PhraseSaveResult.Locked -> { phraseError = "Pro에서 사용할 수 있어요."; container.customizationController.load() }
                        }
                    }
                },
                onArchivePhrase = { id -> scope.launch { state = container.customizationController.archivePhrase(id) } },
                onPresetChanged = { id, intensity -> scope.launch { state = container.customizationController.setWidgetPreset(id, intensity) } },
                onPresetDeleted = { id -> scope.launch { state = container.customizationController.deleteWidgetPreset(id) } },
                onThemeSelected = { id -> scope.launch { state = container.customizationController.selectTheme(id) } },
                modifier = Modifier.weight(1f),
                errorMessage = phraseError,
            )
            androidx.compose.material3.TextButton(modifier = Modifier.navigationBarsPadding(), onClick = onBack) { Text("기록으로") }
        }
    } ?: Text("설정을 불러오는 중")
}

@Composable
private fun AnalyticsRoute(container: AppContainer, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val billingState by container.billingRepository.state.collectAsState()
    val entitlement = billingState.effectiveEntitlement()
    var result by remember { mutableStateOf<com.maeumjaro.app.feature.analytics.AccessResult<com.maeumjaro.app.feature.analytics.DetailedPatternsResult>?>(null) }
    var exportStatus by remember { mutableStateOf(JsonExportStatus.Idle) }
    LaunchedEffect(entitlement) {
        result = if (entitlement == Entitlement.PRO) {
            com.maeumjaro.app.feature.analytics.DetailedPatterns(
                container.repository,
                container.entitlements,
            ).execute(java.time.LocalDate.now(container.clock))
        } else {
            com.maeumjaro.app.feature.analytics.AccessResult.Locked
        }
    }
    fun exportJson() {
        scope.launch {
            exportStatus = JsonExportStatus.Working
            val export = JsonExportController(
                prepare = {
                    when (val access = com.maeumjaro.app.feature.analytics.JsonExport(
                        container.repository,
                        container.entitlements,
                    ).execute(container.clock.instant())) {
                        is com.maeumjaro.app.feature.analytics.AccessResult.Unlocked -> container.exportFileStore.writeJson(
                            access.value.bytes,
                            access.value.suggestedFileName,
                        )
                        com.maeumjaro.app.feature.analytics.AccessResult.Locked -> error("export unavailable")
                    }
                },
                share = { file ->
                    context.startActivity(Intent.createChooser(ExportShareIntent.create(context, file), "JSON 내보내기"))
                },
            ).export()
            exportStatus = when (export) {
                JsonExportOperationResult.Success -> JsonExportStatus.Idle
                JsonExportOperationResult.Failure -> JsonExportStatus.Failure
            }
        }
    }
    Column(Modifier.fillMaxSize()) {
        if (entitlement != Entitlement.PRO) {
            Column(Modifier.weight(1f).fillMaxWidth().padding(24.dp)) {
                Text("상세 기록 분석", style = MaterialTheme.typography.headlineMedium)
                Text("상세 분석과 JSON 내보내기는 Pro에서 사용할 수 있어요.")
            }
        } else {
            when (val loaded = result) {
                is com.maeumjaro.app.feature.analytics.AccessResult.Unlocked ->
                ProAnalyticsScreen(
                    loaded.value.report,
                    onExportJson = ::exportJson,
                    exportStatus = exportStatus,
                    onRetryExport = ::exportJson,
                    modifier = Modifier.weight(1f),
                )
                com.maeumjaro.app.feature.analytics.AccessResult.Locked -> Column(Modifier.weight(1f).fillMaxWidth().padding(24.dp)) {
                    Text("상세 기록 분석", style = MaterialTheme.typography.headlineMedium)
                    Text("상세 분석과 JSON 내보내기는 Pro에서 사용할 수 있어요.")
                }
                null -> Box(Modifier.weight(1f).fillMaxWidth()) { Text("분석을 불러오는 중") }
            }
        }
        androidx.compose.material3.TextButton(modifier = Modifier.navigationBarsPadding(), onClick = onBack) { Text("기록으로") }
    }
}

@Composable
private fun ProRoute(container: AppContainer, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val state by container.billingRepository.state.collectAsState()
    val statusCopy = when (val current = state) {
        is com.maeumjaro.app.billing.BillingEntitlementState.Unknown -> if (current.cachedPro) {
            "저장된 Pro 사용 권한으로 사용 중이에요. Play 확인을 기다리고 있어요."
        } else "Play 구매 정보를 확인하고 있어요."
        com.maeumjaro.app.billing.BillingEntitlementState.Free -> "Pro는 1회 구매로 상세 분석과 개인화 기능을 열어요."
        com.maeumjaro.app.billing.BillingEntitlementState.Pending -> "구매 처리가 완료되기를 기다리고 있어요."
        is com.maeumjaro.app.billing.BillingEntitlementState.Pro -> if (current.acknowledgementPending) {
            "Pro가 활성화됐어요. Play 확인은 다시 시도할 예정이에요."
        } else "Pro가 활성화됐어요."
        is com.maeumjaro.app.billing.BillingEntitlementState.Error -> if (current.cachedPro) {
            "Play에 연결할 수 없지만 이전에 확인된 Pro는 계속 사용할 수 있어요."
        } else "Play 구매 정보를 확인하지 못했어요. 무료 기능은 계속 사용할 수 있어요."
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp)) {
        Text("Pro", style = MaterialTheme.typography.headlineMedium)
        Text(statusCopy)
        if (state !is com.maeumjaro.app.billing.BillingEntitlementState.Pro && state !is com.maeumjaro.app.billing.BillingEntitlementState.Pending) {
            PrimaryAction("Pro 구매", onClick = { scope.launch { (context as? androidx.activity.ComponentActivity)?.let { container.billingRepository.buyPro(AndroidBillingActivityHandle(it)) } } })
        }
        androidx.compose.material3.TextButton(onClick = { scope.launch { container.billingRepository.restore() } }) { Text("구매 복원") }
        androidx.compose.material3.TextButton(modifier = Modifier.navigationBarsPadding(), onClick = onBack) { Text("기록으로") }
    }
}

private fun injectionViewModelFactory(
    container: AppContainer,
    settings: OnboardingSettings,
    source: EntrySource,
) = object : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = InjectionViewModel(
        initialIntensity = settings.intensity,
        source = source,
        clock = container.clock,
        completionUseCase = container.completeInjection,
        preferredTone = container::preferredPhraseTone,
    ) as T
}

private fun NavHostController.returnToRecords() {
    navigate(AppRoute.Records.path) { popUpTo(graph.id) { inclusive = true } }
}
