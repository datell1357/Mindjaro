import Foundation
import MaeumjaroDomain

enum EventCompletionCoordinatorError: Error, Equatable {
    case projectionFailed
}

struct EventCompletionResult: Equatable {
    let recording: CompletionRecordingOutcome
    let projectionError: Error?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.recording == rhs.recording && (lhs.projectionError != nil) == (rhs.projectionError != nil)
    }
}

@MainActor
final class EventCompletionCoordinator: CompletionRecording {
    private let recorder: any CompletionRecording
    private let projection: WidgetProjectionCoordinator
    private var completedSessions = Set<UUID>()
    private var projectedSessions = Set<UUID>()

    init(recorder: any CompletionRecording, projection: WidgetProjectionCoordinator) {
        self.recorder = recorder
        self.projection = projection
    }

    private(set) var lastProjectionError: Error?

    func recordCompletion(_ request: CompletionRecordingRequest) async throws -> CompletionRecordingOutcome {
        try await recordCompletionWithProjection(request).recording
    }

    func recordCompletionWithProjection(
        _ request: CompletionRecordingRequest
    ) async throws -> EventCompletionResult {
        let validated = try request.validated()
        let recording: CompletionRecordingOutcome
        if completedSessions.contains(validated.sessionID) {
            recording = .alreadyRecorded
            if projectedSessions.contains(validated.sessionID) {
                return EventCompletionResult(recording: recording, projectionError: nil)
            }
        } else {
            recording = try await recorder.recordCompletion(validated)
            completedSessions.insert(validated.sessionID)
        }

        do {
            _ = try await projection.projectAfterCompletion()
            projectedSessions.insert(validated.sessionID)
            lastProjectionError = nil
            return EventCompletionResult(recording: recording, projectionError: nil)
        } catch {
            // The durable event is intentionally retained. Foreground repair retries projection.
            lastProjectionError = error
            return EventCompletionResult(recording: recording, projectionError: error)
        }
    }

    func repairProjectionOnForeground() async throws {
        projection.resetOperationReloadGuard()
        _ = try await projection.projectTodaySummary()
    }
}
