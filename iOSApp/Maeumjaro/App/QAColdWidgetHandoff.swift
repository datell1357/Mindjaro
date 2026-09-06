#if DEBUG && MAEUMJARO_QA_FIXTURES
import Foundation
import MaeumjaroShared

enum QAColdWidgetHandoffError: Error, Equatable {
    case optInRequiresFixture
    case malformedEnvelope
    case schemaMismatch
    case fixtureMismatch
    case invalidTimes
    case expired
    case activeMarkerMismatch
    case removeFailed
}

/// A short-lived, app-only bootstrap handoff. UserDefaults read/remove is not
/// cross-process atomic; only the app bootstrap is a consumer.
@MainActor
enum QAColdWidgetHandoff {
    static let armArgument = "-MaeumjaroArmColdWidgetFixture"
    static let envelopeKey = "qa.coldWidgetHandoff.v1"
    static let tombstoneKey = "qa.coldWidgetHandoff.tombstone.v1"
    static let ttl: TimeInterval = 90
    static let maxTTL: TimeInterval = 90
    static let schemaVersion = 1
    static var quarantined = false
    static var claimedFixture: QAFixtureConfiguration?

    struct Envelope: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let fixtureID: UUID
        let fixtureName: String
        let issuedAt: Date
        let expiresAt: Date
    }

    static func hasExplicitFixtureArguments(_ arguments: [String]) -> Bool {
        arguments.contains("-MaeumjaroFixtureID") || arguments.contains("-MaeumjaroFixture")
    }

    static func clear(_ defaults: AppGroupDefaults) throws {
        try defaults.remove(forKey: envelopeKey)
        try defaults.remove(forKey: tombstoneKey)
        quarantined = false
        claimedFixture = nil
    }

    static func resetForTesting() {
        quarantined = false
        claimedFixture = nil
    }

    static func resolve(
        arguments: [String],
        defaults: AppGroupDefaults,
        cachesDirectory: URL,
        now: Date = Date()
    ) throws -> QAFixtureConfiguration? {
        let explicit = hasExplicitFixtureArguments(arguments)
        let parsed = try QAFixtureConfiguration(arguments: arguments, cachesDirectory: cachesDirectory)
        if explicit {
            guard let parsed else { throw QAColdWidgetHandoffError.fixtureMismatch }
            try clear(defaults)
            return parsed
        }
        if arguments.contains(armArgument) { throw QAColdWidgetHandoffError.optInRequiresFixture }
        if let claimedFixture { return claimedFixture }
        guard !quarantined else { throw QAColdWidgetHandoffError.malformedEnvelope }
        return try consume(defaults: defaults, cachesDirectory: cachesDirectory, now: now)
    }

    static func arm(
        arguments: [String],
        fixture: QAFixtureConfiguration?,
        defaults: AppGroupDefaults,
        now: Date = Date()
    ) throws {
        guard arguments.contains(armArgument), let fixture else {
            if arguments.contains(armArgument) { throw QAColdWidgetHandoffError.optInRequiresFixture }
            return
        }
        let envelope = Envelope(
            schemaVersion: schemaVersion,
            fixtureID: fixture.fixtureID,
            fixtureName: fixture.name.rawValue,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttl)
        )
        try defaults.set(try JSONEncoder().encode(envelope), forKey: envelopeKey)
        try defaults.set(Data(fixture.fixtureID.uuidString.utf8), forKey: DebugFixtureNamespace.activeFixtureIDKey)
    }

    /// Removes before decoding/validation so a valid envelope is one-shot.
    /// Invalid input clears the active marker and fails closed.
    static func consume(
        defaults: AppGroupDefaults,
        expectedFixture: QAFixtureConfiguration? = nil,
        cachesDirectory: URL,
        now: Date = Date()
    ) throws -> QAFixtureConfiguration? {
        if defaults.data(forKey: tombstoneKey) != nil {
            quarantined = true
            throw QAColdWidgetHandoffError.malformedEnvelope
        }
        guard let data = defaults.data(forKey: envelopeKey) else { return nil }
        do {
            try defaults.set(Data("pending".utf8), forKey: tombstoneKey)
            try defaults.remove(forKey: envelopeKey)
        } catch {
            quarantined = true
            throw QAColdWidgetHandoffError.removeFailed
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.schemaVersion == schemaVersion else { throw QAColdWidgetHandoffError.schemaMismatch }
            guard envelope.expiresAt >= envelope.issuedAt,
                  envelope.expiresAt.timeIntervalSince(envelope.issuedAt) <= maxTTL,
                  now >= envelope.issuedAt,
                  now <= envelope.expiresAt else {
                throw now > envelope.expiresAt ? QAColdWidgetHandoffError.expired : QAColdWidgetHandoffError.invalidTimes
            }
            guard DebugFixtureNamespace.active(in: defaults)?.fixtureID == envelope.fixtureID else {
                throw QAColdWidgetHandoffError.activeMarkerMismatch
            }
            if let expectedFixture,
               expectedFixture.fixtureID != envelope.fixtureID || expectedFixture.name.rawValue != envelope.fixtureName {
                throw QAColdWidgetHandoffError.fixtureMismatch
            }
            let args = ["-MaeumjaroFixtureID", envelope.fixtureID.uuidString, "-MaeumjaroFixture", envelope.fixtureName]
            guard let fixture = try QAFixtureConfiguration(arguments: args, cachesDirectory: cachesDirectory) else {
                throw QAColdWidgetHandoffError.fixtureMismatch
            }
            try defaults.set(Data(fixture.fixtureID.uuidString.utf8), forKey: tombstoneKey)
            claimedFixture = fixture
            return fixture
        } catch let error as QAColdWidgetHandoffError {
            quarantined = true
            try? defaults.set(Data(), forKey: tombstoneKey)
            try? defaults.set(Data(), forKey: DebugFixtureNamespace.activeFixtureIDKey)
            throw error
        } catch {
            quarantined = true
            try? defaults.set(Data(), forKey: tombstoneKey)
            try? defaults.set(Data(), forKey: DebugFixtureNamespace.activeFixtureIDKey)
            throw QAColdWidgetHandoffError.malformedEnvelope
        }
    }
}
#endif
