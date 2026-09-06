import Foundation

@MainActor
public protocol EventRepository {
    func insert(_ event: InjectionEvent) async throws
    func fetchAll() async throws -> [InjectionEvent]
    func fetch(id: UUID) async throws -> InjectionEvent?
    func delete(id: UUID) async throws
    func deleteAll() async throws
}
