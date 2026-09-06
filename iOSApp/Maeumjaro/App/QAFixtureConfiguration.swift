#if MAEUMJARO_QA_FIXTURES
import Foundation
import MaeumjaroShared

enum QAFixtureConfigurationError: Error, Equatable {
    case malformedArguments
    case unsupportedFixture(String)
}

struct QAFixtureConfiguration: Equatable, Sendable {
    enum Name: String, CaseIterable, Sendable {
        case empty
        case analyticsReference = "analytics-reference"
        case freeBoundary = "free-boundary"
        case proBoundary = "pro-boundary"
        case offline
        case ritual
    }

    let fixtureID: UUID
    let name: Name
    let namespace: DebugFixtureNamespace
    let cacheRoot: URL

    init?(arguments: [String], cachesDirectory: URL) throws {
        let idValues = Self.values(for: "-MaeumjaroFixtureID", in: arguments)
        let fixtureValues = Self.values(for: "-MaeumjaroFixture", in: arguments)
        guard idValues.isEmpty == fixtureValues.isEmpty else {
            throw QAFixtureConfigurationError.malformedArguments
        }
        guard let idString = idValues.first, let fixtureValue = fixtureValues.first else {
            return nil
        }
        guard idValues.count == 1, fixtureValues.count == 1,
              let fixtureID = UUID(uuidString: idString),
              let name = Name(rawValue: fixtureValue),
              let namespace = DebugFixtureNamespace(fixtureID: idString) else {
            if UUID(uuidString: idString) != nil {
                throw QAFixtureConfigurationError.unsupportedFixture(fixtureValue)
            }
            throw QAFixtureConfigurationError.malformedArguments
        }
        self.fixtureID = fixtureID
        self.name = name
        self.namespace = namespace
        cacheRoot = cachesDirectory
            .appendingPathComponent("MaeumjaroQA", isDirectory: true)
            .appendingPathComponent(fixtureID.uuidString, isDirectory: true)
    }

    var storeURL: URL {
        cacheRoot.appendingPathComponent("Maeumjaro.sqlite", isDirectory: false)
    }

    func scopedDefaults(from defaults: AppGroupDefaults) -> AppGroupDefaults {
        namespace.scopedDefaults(from: defaults)
    }

    private static func values(for flag: String, in arguments: [String]) -> [String] {
        arguments.enumerated().compactMap { index, argument in
            guard argument == flag, arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
    }
}

#if DEBUG
/// Deterministic commerce failure client used by the offline QA fixture.
struct QAFailingStoreKitClient: StoreKitPurchaseClientProtocol {
    func product() async throws -> PurchaseProduct {
        throw PurchaseClientError.storeUnavailable
    }

    func purchase() async -> PurchaseResult {
        .failed(.storeUnavailable)
    }

    func currentEntitlements() async throws -> [TransactionEvidence] {
        throw PurchaseClientError.storeUnavailable
    }

    func transactionUpdates() -> AsyncStream<TransactionEvidence> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func syncStore() async throws {
        throw PurchaseClientError.storeUnavailable
    }
}
#endif
#endif
