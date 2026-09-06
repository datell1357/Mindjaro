import Foundation
import MaeumjaroDomain
import MaeumjaroPersistence
import MaeumjaroShared
import SwiftData

@MainActor
struct AppShellDependencies {
    let settingsRepository: any SettingsRepository
    let strengthStore: SharedStrengthStore
    let events: SwiftDataEventRepository
    let phraseProvider: RitualPhraseProvider
    let projection: WidgetProjectionCoordinator
    let completion: EventCompletionCoordinator
    let entitlementStore: ProEntitlementStore

    let modelContainer: ModelContainer
#if DEBUG && MAEUMJARO_QA_FIXTURES
    var qaFixtureID: UUID? = nil
#endif

    init(
        settingsRepository: any SettingsRepository,
        strengthStore: SharedStrengthStore,
        modelContainer: ModelContainer,
        defaults: AppGroupDefaults,
        entitlementClient: any StoreKitPurchaseClientProtocol = StoreKitPurchaseClient()
    ) {
        self.settingsRepository = settingsRepository
        self.strengthStore = strengthStore
        self.modelContainer = modelContainer
        let events = SwiftDataEventRepository(container: modelContainer)
        self.events = events
        self.phraseProvider = RitualPhraseProvider(repository: SwiftDataPhraseRepository(container: modelContainer))
        let projection = WidgetProjectionCoordinator(eventRepository: events, summaryStore: TodaySummaryStore(defaults: defaults), themeStore: WidgetThemeStore(defaults: defaults), strengthStore: strengthStore)
        self.projection = projection
        completion = EventCompletionCoordinator(recorder: events, projection: projection)
        entitlementStore = ProEntitlementStore(client: entitlementClient)
    }

    static func makeProduction(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        fileManager: FileManager = .default
    ) throws -> Self {
        let appGroupDefaults = try AppGroupDefaults()
        #if DEBUG && MAEUMJARO_QA_FIXTURES
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let hasExplicitFixture = QAColdWidgetHandoff.hasExplicitFixtureArguments(arguments)
        let fixture = try QAColdWidgetHandoff.resolve(arguments: arguments, defaults: appGroupDefaults, cachesDirectory: cachesDirectory)
        let defaults: AppGroupDefaults
        let container: ModelContainer
        let entitlementClient: any StoreKitPurchaseClientProtocol
        if let fixture {
            _ = try DebugFixtureNamespace.select(from: arguments, in: appGroupDefaults)
            defaults = fixture.scopedDefaults(from: appGroupDefaults)
            container = try ModelContainerFactory.makePersistent(at: fixture.storeURL, fileManager: fileManager)
            try QAFixtureSeeder.seed(fixture, container: container)
            if hasExplicitFixture { try QAColdWidgetHandoff.arm(arguments: arguments, fixture: fixture, defaults: appGroupDefaults) }
            switch fixture.name {
            case .proBoundary:
                entitlementClient = QAVerifiedProEntitlementClient()
            case .offline:
                entitlementClient = QAFailingStoreKitClient()
            default:
                entitlementClient = StoreKitPurchaseClient()
            }
        } else {
            // A normal DEBUG launch leaves the shared production namespace clean.
            // An empty marker is intentionally used instead of removing a key.
            try appGroupDefaults.set(Data(), forKey: DebugFixtureNamespace.activeFixtureIDKey)
            defaults = appGroupDefaults
            container = try ModelContainerFactory.makeProductionContainer(fileManager: fileManager)
            entitlementClient = StoreKitPurchaseClient()
        }
        #else
        let defaults = appGroupDefaults
        let container = try ModelContainerFactory.makeProductionContainer(fileManager: fileManager)
        let entitlementClient: any StoreKitPurchaseClientProtocol = StoreKitPurchaseClient()
        #endif
        var result = Self(
            settingsRepository: SwiftDataSettingsRepository(container: container),
            strengthStore: SharedStrengthStore(defaults: defaults),
            modelContainer: container,
            defaults: defaults,
            entitlementClient: entitlementClient
        )
        #if DEBUG && MAEUMJARO_QA_FIXTURES
        result.qaFixtureID = hasExplicitFixture ? nil : fixture?.fixtureID
        #endif
        return result
    }
}
