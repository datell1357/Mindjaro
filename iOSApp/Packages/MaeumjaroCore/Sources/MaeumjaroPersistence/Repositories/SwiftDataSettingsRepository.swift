import MaeumjaroDomain
import SwiftData

@MainActor
public final class SwiftDataSettingsRepository: SettingsRepository {
    public let modelContext: ModelContext

    public init(context: ModelContext) {
        modelContext = context
    }

    public convenience init(container: ModelContainer) {
        self.init(context: container.mainContext)
    }

    public func load() async throws -> AppSettings {
        let models = try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>())
        if let model = models.first(where: { $0.id == "singleton" }) ?? models.first {
            return try AppSettingsMapper.makeDomain(from: model)
        }

        let settings = AppSettings.default
        modelContext.insert(AppSettingsMapper.makeModel(from: settings))
        try modelContext.save()
        return settings
    }

    public func save(_ settings: AppSettings) async throws {
        let models = try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>())
        if let model = models.first(where: { $0.id == "singleton" }) ?? models.first {
            model.id = "singleton"
            model.onboardingCompleted = settings.onboardingCompleted
            model.hapticsEnabled = settings.hapticsEnabled
            model.soundEnabled = settings.soundEnabled
            model.reducedMotionEnabled = settings.reducedMotionEnabled
            model.phraseTonePreferenceRawValue = settings.phraseTonePreference.rawValue
            model.themeIDRawValue = settings.themeID.rawValue
            model.widgetHelpBannerDismissed = settings.widgetHelpBannerDismissed
        } else {
            modelContext.insert(AppSettingsMapper.makeModel(from: settings))
        }
        try modelContext.save()
    }
}
