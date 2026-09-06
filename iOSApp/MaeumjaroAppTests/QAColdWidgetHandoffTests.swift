#if DEBUG && MAEUMJARO_QA_FIXTURES
import XCTest
import MaeumjaroShared
@testable import Maeumjaro

@MainActor
final class QAColdWidgetHandoffTests: XCTestCase {
    private let id = UUID(uuidString: "A0000000-0000-4000-8000-000000000099")!
    private let now = Date(timeIntervalSince1970: 1_757_059_200)

    override func setUp() async throws {
        try await super.setUp()
        QAColdWidgetHandoff.resetForTesting()
    }

    override func tearDown() async throws {
        QAColdWidgetHandoff.resetForTesting()
        try await super.tearDown()
    }

    func testValidHandoffReusesSameProcessAndFreshProcessFailsClosed() throws {
        let store = MemoryDataStore(); let d = defaults(store); let fixture = try fixture()
        try QAColdWidgetHandoff.arm(arguments: args(arm: true, name: fixture.name), fixture: fixture, defaults: d, now: now)
        _ = try QAColdWidgetHandoff.consume(defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: now)
        XCTAssertEqual(try QAColdWidgetHandoff.resolve(arguments: [], defaults: d, cachesDirectory: FileManager.default.temporaryDirectory)?.storeURL, fixture.storeURL)
        QAColdWidgetHandoff.resetForTesting()
        XCTAssertThrowsError(try QAColdWidgetHandoff.resolve(arguments: [], defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: now))
    }

    func testMalformedExplicitArgumentsDoNotClearTombstone() throws {
        let store = MemoryDataStore(); let d = defaults(store)
        try d.set(Data("blocked".utf8), forKey: QAColdWidgetHandoff.tombstoneKey)
        XCTAssertThrowsError(try QAColdWidgetHandoff.resolve(arguments: ["-MaeumjaroFixtureID", "bad", "-MaeumjaroFixture", "analytics-reference"], defaults: d, cachesDirectory: FileManager.default.temporaryDirectory))
        XCTAssertNotNil(d.data(forKey: QAColdWidgetHandoff.tombstoneKey))
    }

    func testInvalidHandoffsStayQuarantinedAcrossProcessReset() throws {
        for scenario in ["malformed", "expired", "marker-mismatch"] {
            QAColdWidgetHandoff.resetForTesting()
            let d = defaults(MemoryDataStore())
            let fixture = try fixture()
            try QAColdWidgetHandoff.arm(arguments: args(arm: true, name: fixture.name), fixture: fixture, defaults: d, now: now)
            if scenario == "malformed" {
                try d.set(Data("invalid".utf8), forKey: QAColdWidgetHandoff.envelopeKey)
            } else if scenario == "marker-mismatch" {
                try d.set(Data(UUID().uuidString.utf8), forKey: DebugFixtureNamespace.activeFixtureIDKey)
            }
            let consumeTime = scenario == "expired" ? now.addingTimeInterval(91) : now
            XCTAssertThrowsError(try QAColdWidgetHandoff.resolve(arguments: [], defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: consumeTime), scenario)
            XCTAssertNil(d.data(forKey: QAColdWidgetHandoff.envelopeKey))
            QAColdWidgetHandoff.resetForTesting()
            XCTAssertThrowsError(try QAColdWidgetHandoff.resolve(arguments: [], defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: consumeTime), scenario)
            XCTAssertEqual(try QAColdWidgetHandoff.resolve(arguments: args(arm: false, name: fixture.name), defaults: d, cachesDirectory: FileManager.default.temporaryDirectory), fixture)
            XCTAssertNil(d.data(forKey: QAColdWidgetHandoff.tombstoneKey))
        }
    }

    func testFailedTombstoneWriteRetainsEnvelope() throws {
        let store = MemoryDataStore(); let d = defaults(store)
        try d.set(Data("malformed".utf8), forKey: QAColdWidgetHandoff.envelopeKey)
        store.failWrites = true
        XCTAssertThrowsError(try QAColdWidgetHandoff.consume(defaults: d, cachesDirectory: FileManager.default.temporaryDirectory))
        XCTAssertNotNil(d.data(forKey: QAColdWidgetHandoff.envelopeKey))
    }

    func testArmRequiresExplicitFixtureArguments() throws {
        let store = MemoryDataStore()
        XCTAssertThrowsError(try QAColdWidgetHandoff.arm(arguments: [QAColdWidgetHandoff.armArgument], fixture: nil, defaults: defaults(store))) { error in
            XCTAssertEqual(error as? QAColdWidgetHandoffError, .optInRequiresFixture)
        }
    }

    func testValidEnvelopeIsConsumedOnceAndReconstructsSameStoreURL() throws {
        let store = MemoryDataStore(); let d = defaults(store); let fixture = try fixture()
        try QAColdWidgetHandoff.arm(arguments: args(arm: true, name: fixture.name), fixture: fixture, defaults: d, now: now)
        let consumed = try QAColdWidgetHandoff.consume(defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: now.addingTimeInterval(1))
        XCTAssertEqual(consumed?.fixtureID, id)
        XCTAssertEqual(consumed?.name, fixture.name)
        XCTAssertEqual(consumed?.storeURL, fixture.storeURL)
        XCTAssertThrowsError(try QAColdWidgetHandoff.consume(defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: now.addingTimeInterval(2))) { XCTAssertEqual($0 as? QAColdWidgetHandoffError, .malformedEnvelope) }
    }

    func testExpiredFutureAndOverMaxTTLFailClosed() throws {
        let fixture = try fixture()
        for (offset, expected) in [(91.0, QAColdWidgetHandoffError.expired), (-1.0, QAColdWidgetHandoffError.invalidTimes)] {
            let store = MemoryDataStore(); let d = defaults(store)
            let e = QAColdWidgetHandoff.Envelope(schemaVersion: 1, fixtureID: id, fixtureName: fixture.name.rawValue, issuedAt: now, expiresAt: now.addingTimeInterval(QAColdWidgetHandoff.ttl))
            try d.set(try JSONEncoder().encode(e), forKey: QAColdWidgetHandoff.envelopeKey)
            try d.set(Data(id.uuidString.utf8), forKey: DebugFixtureNamespace.activeFixtureIDKey)
            XCTAssertThrowsError(try QAColdWidgetHandoff.consume(defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: now.addingTimeInterval(offset))) { XCTAssertEqual($0 as? QAColdWidgetHandoffError, expected) }
            XCTAssertTrue((d.data(forKey: DebugFixtureNamespace.activeFixtureIDKey) ?? Data()).isEmpty)
        }
        let store = MemoryDataStore(); let d = defaults(store)
        let e = QAColdWidgetHandoff.Envelope(schemaVersion: 1, fixtureID: id, fixtureName: fixture.name.rawValue, issuedAt: now, expiresAt: now.addingTimeInterval(QAColdWidgetHandoff.maxTTL + 1))
        try d.set(try JSONEncoder().encode(e), forKey: QAColdWidgetHandoff.envelopeKey)
        try d.set(Data(id.uuidString.utf8), forKey: DebugFixtureNamespace.activeFixtureIDKey)
        XCTAssertThrowsError(try QAColdWidgetHandoff.consume(defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: now.addingTimeInterval(1))) { XCTAssertEqual($0 as? QAColdWidgetHandoffError, .invalidTimes) }
    }

    func testExplicitFixturePrecedenceClearsPriorEnvelope() throws {
        let store = MemoryDataStore(); let d = defaults(store); let fixture = try fixture()
        try QAColdWidgetHandoff.arm(arguments: args(arm: true, name: fixture.name), fixture: fixture, defaults: d, now: now)
        try QAColdWidgetHandoff.clear(d)
        XCTAssertNil(d.data(forKey: QAColdWidgetHandoff.envelopeKey))
    }

    func testRemoveFailureFailsClosedWithoutConsuming() throws {
        let store = MemoryDataStore(); store.failRemovals = true; let d = defaults(store); let fixture = try fixture()
        try QAColdWidgetHandoff.arm(arguments: args(arm: true, name: fixture.name), fixture: fixture, defaults: defaults(MemoryDataStore()), now: now)
        // The failure path is exercised with a directly encoded envelope.
        let e = QAColdWidgetHandoff.Envelope(schemaVersion: 1, fixtureID: id, fixtureName: fixture.name.rawValue, issuedAt: now, expiresAt: now.addingTimeInterval(90))
        try d.set(try JSONEncoder().encode(e), forKey: QAColdWidgetHandoff.envelopeKey)
        XCTAssertThrowsError(try QAColdWidgetHandoff.consume(defaults: d, cachesDirectory: FileManager.default.temporaryDirectory, now: now)) { XCTAssertEqual($0 as? QAColdWidgetHandoffError, .removeFailed) }
    }

    private func defaults(_ store: MemoryDataStore) -> AppGroupDefaults { AppGroupDefaults(storage: store) }
    private func fixture() throws -> QAFixtureConfiguration { try XCTUnwrap(QAFixtureConfiguration(arguments: ["-MaeumjaroFixtureID", id.uuidString, "-MaeumjaroFixture", "analytics-reference"], cachesDirectory: FileManager.default.temporaryDirectory)) }
    private func args(arm: Bool, name: QAFixtureConfiguration.Name) -> [String] { ["-MaeumjaroFixtureID", id.uuidString, "-MaeumjaroFixture", name.rawValue] + (arm ? [QAColdWidgetHandoff.armArgument] : []) }
}
#endif
