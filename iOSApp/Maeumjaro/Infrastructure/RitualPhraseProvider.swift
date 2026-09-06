import Foundation
import MaeumjaroDomain
import MaeumjaroPersistence

@MainActor
final class RitualPhraseProvider {
    private let repository: SwiftDataPhraseRepository
    private let seeder: PhraseCatalogSeeder
    private var seeded = false

    init(repository: SwiftDataPhraseRepository) {
        self.repository = repository
        seeder = PhraseCatalogSeeder(repository: repository)
    }

    func phrase(for intensity: Intensity, settings: AppSettings, events: [InjectionEvent]) async throws -> Phrase {
        if !seeded {
            _ = try await seeder.seed()
            seeded = true
        }
        let catalog = try await repository.fetchAll()
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.phraseID, $0) })
        let recent = events.sorted { $0.completedAtUTC > $1.completedAtUTC }.prefix(10)
        let recentIDs = recent.map(\.phraseID)
        // PhraseSelector's category tail is chronological (oldest to newest).
        let recentCategories = recent.reversed().compactMap { byID[$0.phraseID]?.category }
        let request = PhraseSelectionRequest(
            intensity: intensity,
            tonePreference: settings.phraseTonePreference,
            recentPhraseIDs: recentIDs,
            recentCategories: recentCategories,
            seed: UInt64(events.count)
        )
        return PhraseSelector(catalog: catalog).select(request)
    }

    func phrase(for intensity: Intensity, settings: AppSettings) async throws -> Phrase {
        try await phrase(for: intensity, settings: settings, events: [])
    }
}
