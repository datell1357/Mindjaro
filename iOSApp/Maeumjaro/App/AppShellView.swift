import SwiftUI
import MaeumjaroDomain
import MaeumjaroShared

struct AppShellView: View {
    let dependencies: AppShellDependencies
    let router: AppRouter
    @State private var settings: AppSettings?
    @State private var loadError: Error?
    @State private var selectedTab = 0
    @State private var entitlement: Entitlement = .loading
    @State private var presentedSheet: ShellSheet?
    @State private var pendingSource: EventSource?
    @State private var refreshID = UUID()
    @State private var ritualPresentation: RitualPresentation?
    @State private var openingRitual = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if let settings {
                if settings.onboardingCompleted {
                    mainShell(settings: settings)
                } else {
                    OnboardingView(model: OnboardingViewModel(initialSettings: settings, settingsRepository: dependencies.settingsRepository, strengthStore: dependencies.strengthStore, onStrengthChanged: { try dependencies.projection.strengthChanged(to: $0) })) { completed in
                        self.settings = completed
                    }
                }
            } else if let loadError {
                PersistenceFailureView(error: loadError) { Task { await loadSettings() } }
            } else {
                ProgressView("준비 중이에요").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadSettings()
            _ = await dependencies.entitlementStore.start()
            let stream = await dependencies.entitlementStore.stateStream()
            for await value in stream {
                guard !Task.isCancelled else { return }
                entitlement = value
                if value != .pro, var current = settings, current.themeID != .quietIvory {
                    current.themeID = .quietIvory
                    do {
                        try await dependencies.settingsRepository.save(current)
                        settings = current
                        _ = try dependencies.projection.entitlementDowngraded()
                    } catch { loadError = error }
                }
                refreshID = UUID()
            }
        }
        .onOpenURL { url in
            guard let route = MaeumjaroDeepLink.parse(url) else { return }
            if settings?.onboardingCompleted == true { openRitual(source: route.source) }
            else { pendingSource = route.source }
        }
        .onChange(of: settings?.onboardingCompleted) { _, completed in
            if completed == true, let source = pendingSource {
                pendingSource = nil
                openRitual(source: source)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await loadSettings(); await dependencies.entitlementStore.refresh() } }
        }
        .sheet(item: $presentedSheet, onDismiss: { Task { await loadSettings() } }) { sheet in
            NavigationStack {
                switch sheet {
                case .settings:
                    if let settings {
                        SettingsView(model: SettingsViewModel(initialSettings: settings, settingsRepository: dependencies.settingsRepository, strengthStore: dependencies.strengthStore, onStrengthChanged: { try dependencies.projection.strengthChanged(to: $0) }), onPro: { presentedSheet = .pro }, onDataManagement: { presentedSheet = .data }, onWidgetHelp: { presentedSheet = .widgetHelp }, onSafety: { presentedSheet = .safetyNotice })
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button { presentedSheet = nil } label: {
                                        Image(systemName: "xmark").frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("닫기")
                                    .accessibilityIdentifier("settings-close")
                                }
                            }
                    }
                case .widgetHelp: WidgetHelpView(palette: ThemePalette.palette(for: settings?.themeID ?? .quietIvory, colorScheme: colorScheme, contrast: colorSchemeContrast), onDismiss: { presentedSheet = .settings })
                case .safetyNotice: SafetyNoticeView()
                case .pro: ProPaywallView(model: ProPaywallViewModel(entitlement: entitlement, store: dependencies.entitlementStore))
                case .data:
                    if let settings {
                        DataManagementView(model: DataManagementViewModel(settings: settings, entitlement: entitlement, eventRepository: dependencies.events, settingsRepository: dependencies.settingsRepository, onWidgetThemeChange: { theme in
                            _ = try await dependencies.projection.themeChanged(to: theme)
                        }, onEventsDeleted: {
                            _ = try await dependencies.projection.projectAfterDeletion()
                        }, currentEntitlement: { await dependencies.entitlementStore.entitlement }))
                    }
                }
            }
        }
        .fullScreenCover(item: $ritualPresentation, onDismiss: { Task { await loadSettings() } }) { presentation in
            RitualView(model: presentation.model, palette: ThemePalette.palette(for: presentation.settings.themeID, colorScheme: colorScheme, contrast: colorSchemeContrast), haptics: SystemRitualHapticEngine(enabled: presentation.settings.hapticsEnabled), sound: SystemRitualSoundEngine(enabled: presentation.settings.soundEnabled), reducedMotion: presentation.settings.reducedMotionEnabled, onRecords: { selectedTab = 1 })
                #if DEBUG && MAEUMJARO_QA_FIXTURES
                .overlay(alignment: .topLeading) { fixtureIdentity }
                #endif
        }
        #if DEBUG && MAEUMJARO_QA_FIXTURES
        .overlay(alignment: .topLeading) { fixtureIdentity }
        #endif
        .alert("상태를 갱신하지 못했어요", isPresented: Binding(get: { loadError != nil && settings != nil }, set: { if !$0 { loadError = nil } })) {
            Button("다시 시도") { Task { await loadSettings() } }
            Button("닫기", role: .cancel) { loadError = nil }
        } message: {
            Text("저장된 기록은 유지됩니다. 잠시 후 다시 시도해 주세요.")
        }
    }

    #if DEBUG && MAEUMJARO_QA_FIXTURES
    @ViewBuilder private var fixtureIdentity: some View {
        if let id = dependencies.qaFixtureID {
            Text("QA \(id.uuidString)")
                .font(.caption2).foregroundStyle(.secondary)
                .accessibilityIdentifier("qa-fixture-identity")
                .accessibilityLabel(id.uuidString)
                .allowsHitTesting(false)
        }
    }
    #endif

    @ViewBuilder private func mainShell(settings: AppSettings) -> some View {
        let palette = ThemePalette.palette(for: settings.themeID, colorScheme: colorScheme, contrast: colorSchemeContrast)
        NavigationStack(path: Binding(get: { router.path }, set: { router.replacePath($0) })) {
            TabView(selection: $selectedTab) {
                HomeView(palette: palette, onStart: { openRitual(source: .app) }, onOpenSettings: { presentedSheet = .settings })
                    .tabItem { Image(systemName: "pencil").accessibilityLabel("홈") }.tag(0)
                HistoryView(viewModel: HistoryViewModel(eventRepository: dependencies.events, entitlement: entitlement, onEventsDeleted: {
                    do { _ = try await dependencies.projection.projectAfterDeletion() }
                    catch { loadError = error }
                }), palette: palette)
                    .id(refreshID)
                    .tabItem { Image(systemName: "clock.arrow.circlepath").accessibilityLabel("기록") }.tag(1)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .widgetHelp: WidgetHelpView(palette: palette)
                case .safetyNotice: SafetyNoticeView()
                case .ritual(let source):
                    ProgressView().accessibilityLabel("준비 중이에요")
                        .task { openRitual(source: source) }
                }
            }
        }
        #if DEBUG && MAEUMJARO_QA_FIXTURES
        .overlay(alignment: .bottomTrailing) {
            if ProcessInfo.processInfo.arguments.contains("-MaeumjaroFixtureID") && ProcessInfo.processInfo.arguments.contains("-MaeumjaroAuditUIKit") {
                QAUIKitAppearanceProbe().fixedSize().allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if ProcessInfo.processInfo.arguments.contains("-MaeumjaroFixtureID") && ProcessInfo.processInfo.arguments.contains("-MaeumjaroAuditAppearance") {
                Text("appearance")
                    .font(.caption2)
                    .foregroundStyle(palette.ink.color)
                    .padding(4)
                    .background(palette.surface.color.opacity(0.9))
                    .accessibilityIdentifier("qa-appearance-state")
                    .accessibilityValue("\(colorScheme == .dark ? "dark" : "light")|\(colorSchemeContrast == .increased ? "increased" : "standard")|\(settings.themeID.rawValue)")
                    .allowsHitTesting(false)
            }
        }
        #endif
    }

    private func openRitual(source: EventSource) {
        guard ritualPresentation == nil, !openingRitual else { return }
        openingRitual = true
        Task {
            defer { openingRitual = false }
            do {
                let current = try await dependencies.settingsRepository.load()
                settings = current
                let recentEvents = try await dependencies.events.fetchAll()
                let intensity = dependencies.strengthStore.read()
                let phrase = try await dependencies.phraseProvider.phrase(for: intensity, settings: current, events: recentEvents)
                let model = RitualViewModel(configuration: RitualConfiguration(intensity: intensity, source: source, startedAtUTC: Date()), recorder: dependencies.completion, phraseID: phrase.phraseID, phraseText: phrase.displayText)
                ritualPresentation = RitualPresentation(model: model, settings: current)
            } catch { loadError = error }
        }
    }

    @MainActor private func loadSettings() async {
        do {
            let loadedSettings = try await dependencies.settingsRepository.load()
            settings = loadedSettings
            var firstError: Error?
            do {
                _ = try dependencies.projection.reconcileWidgetTheme(from: loadedSettings)
            } catch {
                firstError = error
            }
            do {
                try await dependencies.completion.repairProjectionOnForeground()
            } catch {
                firstError = firstError ?? error
            }
            refreshID = UUID()
            loadError = firstError
        }
        catch { loadError = error }
    }
}

private enum ShellSheet: String, Identifiable {
    case settings, widgetHelp, safetyNotice, pro, data
    var id: String { rawValue }
}

private struct RitualPresentation: Identifiable {
    let id = UUID()
    let model: RitualViewModel
    let settings: AppSettings
}
