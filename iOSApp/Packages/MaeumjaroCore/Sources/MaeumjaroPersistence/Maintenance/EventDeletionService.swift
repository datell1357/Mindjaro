import Foundation
import SwiftData

public enum EventDeletionScope: Hashable, Sendable {
    case selected(Set<UUID>)
    case all

    public static func selected(_ ids: [UUID]) -> Self {
        .selected(Set(ids))
    }
}

public struct EventDeletionConfirmationToken: Hashable, Sendable {
    public let tokenID: UUID
    fileprivate let scope: EventDeletionScope

    fileprivate init(scope: EventDeletionScope) {
        tokenID = UUID()
        self.scope = scope
    }
}

public typealias DeletionConfirmationToken = EventDeletionConfirmationToken
public typealias DeletionScope = EventDeletionScope

@MainActor
public final class EventDeletionService {
    private let repository: SwiftDataEventRepository

    public init(repository: SwiftDataEventRepository) {
        self.repository = repository
    }

    public convenience init(context: ModelContext) {
        self.init(repository: SwiftDataEventRepository(context: context))
    }

    public func requestConfirmation(
        for scope: EventDeletionScope
    ) throws -> EventDeletionConfirmationToken {
        if case let .selected(ids) = scope, ids.isEmpty {
            throw PersistenceError.deletionScopeEmpty
        }
        return EventDeletionConfirmationToken(scope: scope)
    }

    public func confirm(
        _ token: EventDeletionConfirmationToken
    ) throws {
        switch token.scope {
        case let .selected(ids):
            try repository.delete(ids: ids)
        case .all:
            try repository.deleteAllEvents()
        }
    }

    public func delete(
        scope: EventDeletionScope,
        confirmation token: EventDeletionConfirmationToken
    ) throws {
        guard token.scope == scope else {
            throw PersistenceError.deletionConfirmationRequired
        }
        try confirm(token)
    }

    public func deleteSelected(
        _ ids: Set<UUID>,
        confirmation token: EventDeletionConfirmationToken
    ) throws {
        try delete(scope: .selected(ids), confirmation: token)
    }

    public func deleteAll(
        confirmation token: EventDeletionConfirmationToken
    ) throws {
        try delete(scope: .all, confirmation: token)
    }
}
