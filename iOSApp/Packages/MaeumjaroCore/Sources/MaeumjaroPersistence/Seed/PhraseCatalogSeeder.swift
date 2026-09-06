import Foundation
import MaeumjaroDomain
import SwiftData

@MainActor
public final class PhraseCatalogSeeder {
    private let repository: SwiftDataPhraseRepository
    private let bundle: Bundle
    private let injectedCatalog: [Phrase]?

    public convenience init(
        repository: SwiftDataPhraseRepository,
        catalog: [Phrase]? = nil
    ) {
        self.init(repository: repository, bundle: .module, catalog: catalog)
    }

    public init(
        repository: SwiftDataPhraseRepository,
        bundle: Bundle,
        catalog: [Phrase]? = nil
    ) {
        self.repository = repository
        self.bundle = bundle
        injectedCatalog = catalog
    }

    public convenience init(
        context: ModelContext,
        catalog: [Phrase]? = nil
    ) {
        self.init(
            repository: SwiftDataPhraseRepository(context: context),
            catalog: catalog
        )
    }

    public convenience init(
        context: ModelContext,
        bundle: Bundle,
        catalog: [Phrase]? = nil
    ) {
        self.init(
            repository: SwiftDataPhraseRepository(context: context),
            bundle: bundle,
            catalog: catalog
        )
    }

    public static func loadBundledCatalog() throws -> [Phrase] {
        try loadCatalog(from: .module)
    }

    public func loadCatalog() throws -> [Phrase] {
        if let injectedCatalog {
            return injectedCatalog
        }
        return try Self.loadCatalog(from: bundle)
    }

    private static func loadCatalog(from bundle: Bundle) throws -> [Phrase] {
        guard let url = bundle.url(forResource: "PhraseCatalog.ko", withExtension: "json") else {
            throw PersistenceError.catalogUnavailable
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Phrase].self, from: data)
        } catch {
            throw PersistenceError.catalogDecodingFailed
        }
    }

    public func seed() async throws -> [Phrase] {
        let catalog = try loadCatalog()
        try repository.seed(catalog)
        return catalog
    }

    public func seedCatalog() async throws -> [Phrase] {
        try await seed()
    }
}
