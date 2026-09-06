import Foundation
import MaeumjaroDomain
import MaeumjaroPersistence
import XCTest
@testable import Maeumjaro

@MainActor
final class RitualPhraseProviderTests: XCTestCase {
    func testSeedsExactCatalogCountAndUsesLatestTwoCategories() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataPhraseRepository(container: container)
        let provider = RitualPhraseProvider(repository: repository)
        let catalog = try PhraseCatalogSeeder.loadBundledCatalog()
        let latestCategory = catalog[0].category
        let latest = catalog.filter { $0.category == latestCategory }.prefix(2)
        let older = catalog.filter { $0.category != latestCategory }.prefix(2)
        XCTAssertEqual(latest.count, 2)
        XCTAssertEqual(older.count, 2)

        let selected = try await provider.phrase(
            for: .three,
            settings: AppSettings(phraseTonePreference: .automatic),
            events: [
                makeEvent(phraseID: older[0].phraseID, seconds: 100),
                makeEvent(phraseID: older[1].phraseID, seconds: 200),
                makeEvent(phraseID: latest[0].phraseID, seconds: 300),
                makeEvent(phraseID: latest[1].phraseID, seconds: 400)
            ]
        )

        XCTAssertNotEqual(selected.category, latestCategory)
        let persisted = try await repository.fetchAll()
        XCTAssertEqual(persisted.count, catalog.count)
    }

    private func makeEvent(phraseID: String, seconds: TimeInterval) -> InjectionEvent {
        let date = Date(timeIntervalSince1970: 1_788_566_400 + seconds)
        return InjectionEvent(
            id: UUID(), startedAtUTC: date, completedAtUTC: date, createdAtUTC: date,
            eventLocalDate: "2026-09-05", timezoneOffsetMinutes: 540, intensity: .three,
            source: .app, phraseID: phraseID, animationDurationMilliseconds: 1800,
            interruptedCount: 0, appVersion: "test"
        )
    }
}
