import Foundation
import SwiftData
import Testing

import MaeumjaroDomain
import MaeumjaroPersistence

@Test
@MainActor
func settingsRepositoryCreatesOneSingletonWithoutAnIntensityField() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataSettingsRepository(container: container)

    let initial = try await repository.load()
    let saved = AppSettings(
        onboardingCompleted: true,
        hapticsEnabled: false,
        soundEnabled: true,
        reducedMotionEnabled: true,
        phraseTonePreference: .firm,
        themeID: .forestMist,
        widgetHelpBannerDismissed: true
    )
    try await repository.save(saved)

    let models = try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>())
    #expect(initial == .default)
    #expect(try await repository.load() == saved)
    #expect(models.count == 1)
    #expect(Mirror(reflecting: models[0]).children.contains { $0.label == "intensity" } == false)
}
