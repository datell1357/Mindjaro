import MaeumjaroDomain
import SwiftData

@MainActor
public final class SwiftDataPhraseRepository: PhraseRepository {
    public let modelContext: ModelContext

    public init(context: ModelContext) {
        modelContext = context
    }

    public convenience init(container: ModelContainer) {
        self.init(context: container.mainContext)
    }

    public func fetchAll() async throws -> [Phrase] {
        try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Phrase>())
            .map(PhraseMapper.makeDomain(from:))
            .sorted { $0.phraseID < $1.phraseID }
    }

    public func seed(_ phrases: [Phrase]) throws {
        let existing = try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Phrase>())
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.phraseID, $0) })
        try modelContext.transaction {
            for phrase in phrases {
                if let model = existingByID[phrase.phraseID] {
                    model.categoryRawValue = phrase.category.rawValue
                    model.toneRawValue = phrase.tone.rawValue
                    model.minimumIntensityRawValue = phrase.minimumIntensity.rawValue
                    model.maximumIntensityRawValue = phrase.maximumIntensity.rawValue
                    model.textKO = phrase.textKO
                    model.safetyStatusRawValue = phrase.safetyStatus.rawValue
                    model.contentVersion = phrase.contentVersion
                } else {
                    modelContext.insert(PhraseMapper.makeModel(from: phrase))
                }
            }
            try modelContext.save()
        }
    }

    public func upsert(_ phrases: [Phrase]) throws {
        try seed(phrases)
    }
}
