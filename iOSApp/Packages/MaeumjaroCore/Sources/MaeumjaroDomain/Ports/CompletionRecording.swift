import Foundation

public enum CompletionRecordingOutcome: String, Codable, CaseIterable, Hashable, Sendable {
    case inserted
    case alreadyRecorded
}

public enum CompletionRecordingError: Error, Equatable, Sendable {
    case sessionIDMismatch
}

public struct CompletionRecordingRequest: Codable, Equatable, Hashable, Sendable {
    public let sessionID: UUID
    public let event: InjectionEvent

    public init(sessionID: UUID, event: InjectionEvent) {
        self.sessionID = sessionID
        self.event = event
    }

    public init(event: InjectionEvent) {
        self.init(sessionID: event.id, event: event)
    }

    public var idempotencyKey: UUID { sessionID }
    public var isIdempotencyConsistent: Bool { sessionID == event.id }

    public func validated() throws -> Self {
        guard isIdempotencyConsistent else {
            throw CompletionRecordingError.sessionIDMismatch
        }
        return self
    }
}

@MainActor
public protocol CompletionRecording {
    func recordCompletion(
        _ request: CompletionRecordingRequest
    ) async throws -> CompletionRecordingOutcome
}
