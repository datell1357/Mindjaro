import Foundation
import Testing

import MaeumjaroDomain
import MaeumjaroPersistence

@Test
@MainActor
func phraseCatalogSeederIsIdempotentForAnInjectedFixture() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let phrase = Phrase(
        phraseID: "phrase.test.001",
        category: .autonomy,
        tone: .neutral,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "다음 선택을 천천히 고릅니다."
    )
    let seeder = PhraseCatalogSeeder(context: container.mainContext, catalog: [phrase])

    #expect(try await seeder.seed() == [phrase])
    #expect(try await seeder.seed() == [phrase])
    #expect(try await SwiftDataPhraseRepository(container: container).fetchAll() == [phrase])
}

@Test
@MainActor
func phraseCatalogSeederLoadsTheBundleCatalogAtThePersistenceBoundary() throws {
    let container = try ModelContainerFactory.makeInMemory()
    let seeder = PhraseCatalogSeeder(context: container.mainContext)

    let catalog = try seeder.loadCatalog()

    #expect(catalog.count >= 100)
    #expect(Set(catalog.map(\.phraseID)).count == catalog.count)
}
