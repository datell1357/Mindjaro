@MainActor
public protocol PhraseRepository {
    func fetchAll() async throws -> [Phrase]
}
