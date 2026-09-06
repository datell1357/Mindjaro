import Foundation
import MaeumjaroDomain
import SwiftData

@MainActor
public final class SwiftDataEventRepository: EventRepository, CompletionRecording {
    public let modelContext: ModelContext

    public init(context: ModelContext) {
        modelContext = context
    }

    public convenience init(container: ModelContainer) {
        self.init(context: container.mainContext)
    }

    public func insert(_ event: InjectionEvent) async throws {
        if try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>()).contains(where: { $0.id == event.id }) {
            return
        }
        try modelContext.transaction {
            modelContext.insert(InjectionEventMapper.makeModel(from: event))
            try modelContext.save()
        }
    }

    public func fetchAll() async throws -> [InjectionEvent] {
        try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
            .map(InjectionEventMapper.makeDomain(from:))
            .sorted {
                if $0.completedAtUTC == $1.completedAtUTC {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.completedAtUTC > $1.completedAtUTC
            }
    }

    public func fetch(id: UUID) async throws -> InjectionEvent? {
        guard let model = try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
            .first(where: { $0.id == id }) else {
            return nil
        }
        return try InjectionEventMapper.makeDomain(from: model)
    }

    public func delete(id: UUID) async throws {
        try delete(ids: [id])
    }

    public func delete(ids: Set<UUID>) throws {
        guard !ids.isEmpty else {
            return
        }
        let models = try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
            .filter { ids.contains($0.id) }
        try modelContext.transaction {
            models.forEach(modelContext.delete)
            try modelContext.save()
        }
    }

    public func deleteAll() async throws {
        try deleteAllEvents()
    }

    public func deleteAllEvents() throws {
        let models = try modelContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
        try modelContext.transaction {
            models.forEach(modelContext.delete)
            try modelContext.save()
        }
    }

    public func recordCompletion(
        _ request: CompletionRecordingRequest
    ) async throws -> CompletionRecordingOutcome {
        let validated = try request.validated()
        if try await fetch(id: validated.sessionID) != nil {
            return .alreadyRecorded
        }
        try await insert(validated.event)
        return .inserted
    }
}
