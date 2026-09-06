import Foundation
import MaeumjaroDomain
import XCTest
import UniformTypeIdentifiers
@testable import Maeumjaro

final class HistoryExporterTests: XCTestCase {
    func testExportUsesApprovedFieldsAndCSVQuoting() throws {
        let event = InjectionEvent(
            id: UUID(), startedAtUTC: .distantPast, completedAtUTC: Date(timeIntervalSince1970: 0),
            createdAtUTC: .distantPast, eventLocalDate: "2026-09-05",
            timezoneOffsetMinutes: 540, intensity: .five, source: .app,
            phraseID: "phrase,\"quoted\"\nline", animationDurationMilliseconds: 1,
            interruptedCount: 0, appVersion: "private"
        )
        let document = try XCTUnwrap(HistoryExporter().export([event], format: .csv))
        XCTAssertEqual(Data(document.data.prefix(3)), Data([0xEF, 0xBB, 0xBF]))
        let csv = String(decoding: document.data.dropFirst(3), as: UTF8.self)
        XCTAssertTrue(csv.hasPrefix("completedAtUTC,eventLocalDate,timezoneOffsetMinutes,intensity,source,phraseID"))
        XCTAssertTrue(csv.contains("\"phrase,\"\"quoted\"\"\nline\""))
        XCTAssertFalse(csv.contains("appVersion"))
    }

    func testEmptyHistoryDoesNotCreateDocument() {
        XCTAssertNil(HistoryExporter().export([], format: .json))
    }

    func testCSVTransferAdvertisesCSVTypeAndData() async throws {
        let document = ExportDocument(format: .csv, data: Data("csv".utf8), filename: "history.csv")
        let provider = NSItemProvider()
        provider.register(document)

        XCTAssertTrue(provider.registeredTypeIdentifiers.contains(UTType.commaSeparatedText.identifier))

        let transferredData: Data = try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.commaSeparatedText.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                }
            }
        }
        XCTAssertEqual(transferredData, document.data)
    }

    func testJSONTransferAdvertisesJSONTypeAndFilename() {
        let document = ExportDocument(format: .json, data: Data("{}".utf8), filename: "history.json")
        let provider = NSItemProvider()
        provider.register(document)

        XCTAssertTrue(provider.registeredTypeIdentifiers.contains(UTType.json.identifier))
    }
}
