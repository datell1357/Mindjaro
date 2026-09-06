#if MAEUMJARO_QA_FIXTURES
import XCTest
import MaeumjaroDomain
import MaeumjaroPersistence
import SwiftData
@testable import Maeumjaro

@MainActor
final class QAFixtureSeederTests: XCTestCase {
    private let fixtureID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!
    private let anchor = Date(timeIntervalSince1970: 1_757_059_200)

    func testAnalyticsReferenceSeedsDeterministicEventsAndIsIdempotent() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let fixture = try configuration(.analyticsReference)
        try QAFixtureSeeder.seed(fixture, container: container, now: anchor, calendar: utcCalendar())
        try QAFixtureSeeder.seed(fixture, container: container, now: anchor, calendar: utcCalendar())
        let events = try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
        XCTAssertEqual(events.count, 40)
        XCTAssertEqual(Set(events.map(\.id)).count, 40)
        XCTAssertTrue(events.allSatisfy { $0.appVersion == "qa-fixture" })
        XCTAssertEqual(events.map(\.eventLocalDate).max(), "2025-09-05")
    }

    func testFreeBoundaryAndProSettings() throws {
        let freeContainer = try ModelContainerFactory.makeInMemory()
        try QAFixtureSeeder.seed(try configuration(.freeBoundary), container: freeContainer, now: anchor, calendar: utcCalendar())
        let freeModels = try freeContainer.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
        XCTAssertEqual(freeModels.count, 31)
        let freeEvents = try freeModels.map(InjectionEventMapper.makeDomain(from:))
        let freeWindow = try XCTUnwrap(HistoryWindow.free(today: "2025-09-05"))
        let freeReport = AnalyticsAggregator().aggregate(events: freeEvents, period: freeWindow)
        XCTAssertGreaterThan(freeReport.daily[freeWindow.startDate]?.count ?? 0, 0)
        XCTAssertNil(freeReport.daily[AnalyticsDate(freeWindow.startDate)!.addingDays(-1)!.rawValue])
        let proContainer = try ModelContainerFactory.makeInMemory()
        try QAFixtureSeeder.seed(try configuration(.proBoundary), container: proContainer, now: anchor, calendar: utcCalendar())
        let settings = try proContainer.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>())
        XCTAssertEqual(settings.first?.themeIDRawValue, ThemeID.midnightInk.rawValue)
        let proEvents = try proContainer.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
        XCTAssertEqual(proEvents.count, 38)
        let window = try XCTUnwrap(HistoryWindow.pro(today: "2025-09-05"))
        XCTAssertTrue(proEvents.contains { $0.eventLocalDate == window.startDate })
        XCTAssertTrue(proEvents.contains { $0.eventLocalDate == AnalyticsDate(window.startDate)!.addingDays(-1)!.rawValue })
        let domainEvents = try proEvents.map(InjectionEventMapper.makeDomain(from:))
        let report = AnalyticsAggregator().aggregate(events: domainEvents, period: window)
        XCTAssertGreaterThan(report.daily[window.startDate]?.count ?? 0, 0)
        XCTAssertEqual(report.daily[AnalyticsDate(window.startDate)!.addingDays(-1)!.rawValue]?.count ?? 0, 0)
    }

    func testReseedingPreservesDeletionAndUserTheme() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let fixture = try configuration(.analyticsReference)
        try QAFixtureSeeder.seed(fixture, container: container, now: anchor, calendar: utcCalendar())
        let event = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>()).first)
        let deletedEventID = event.id
        container.mainContext.delete(event)
        let settings = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>()).first)
        settings.themeIDRawValue = ThemeID.forestMist.rawValue
        try container.mainContext.save()
        try QAFixtureSeeder.seed(fixture, container: container, now: anchor, calendar: utcCalendar())
        XCTAssertNil(try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>()).first { $0.id == deletedEventID })
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>()).first?.themeIDRawValue, ThemeID.forestMist.rawValue)
    }

    func testDateFormattingAndOffsetsUseCompletedInstantAcrossUTCDSTBoundary() throws {
        let utc = try seededEvents(.analyticsReference, calendar: calendar("UTC"))
        let latest = try XCTUnwrap(utc.first { $0.index == 0 })
        XCTAssertEqual(latest.eventLocalDate, "2025-09-05")
        XCTAssertEqual(latest.timezoneOffsetMinutes, 0)

        let losAngeles = try seededEvents(.proBoundary, calendar: calendar("America/Los_Angeles"))
        let summer = try XCTUnwrap(losAngeles.first { $0.index == 0 })
        XCTAssertEqual(summer.timezoneOffsetMinutes, -420)
        let window = try XCTUnwrap(HistoryWindow.pro(today: "2025-09-05"))
        XCTAssertEqual(summer.eventLocalDate, window.startDate)
        XCTAssertEqual(summer.durationMilliseconds, 1200)
        XCTAssertEqual(summer.startedAtUTC.timeIntervalSince(summer.completedAtUTC), -1.2, accuracy: 0.001)

        let winter = try XCTUnwrap(losAngeles.first { $0.index == 17 })
        XCTAssertEqual(winter.timezoneOffsetMinutes, -480)
        XCTAssertEqual(winter.durationMilliseconds, 1800)
    }

    func testEmptyAndRitualRemainEmpty() throws {
        for name in [QAFixtureConfiguration.Name.empty, .ritual] {
            let container = try ModelContainerFactory.makeInMemory()
            try QAFixtureSeeder.seed(try configuration(name), container: container, now: anchor, calendar: utcCalendar())
            XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>()).isEmpty)
            XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>()).isEmpty)
        }
    }

    private func configuration(_ name: QAFixtureConfiguration.Name) throws -> QAFixtureConfiguration {
        try XCTUnwrap(QAFixtureConfiguration(arguments: ["-MaeumjaroFixtureID", fixtureID.uuidString, "-MaeumjaroFixture", name.rawValue], cachesDirectory: FileManager.default.temporaryDirectory))
    }

    private func utcCalendar() -> Calendar {
        calendar("UTC")
    }

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private struct EventSnapshot {
        let index: Int
        let eventLocalDate: String
        let timezoneOffsetMinutes: Int
        let startedAtUTC: Date
        let completedAtUTC: Date
        let durationMilliseconds: Int
    }

    private func seededEvents(_ name: QAFixtureConfiguration.Name, calendar: Calendar) throws -> [EventSnapshot] {
        let container = try ModelContainerFactory.makeInMemory()
        try QAFixtureSeeder.seed(try configuration(name), container: container, now: anchor, calendar: calendar)
        let models = try container.mainContext.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
        return models.compactMap {
            guard let index = Int($0.phraseID.split(separator: ".").last ?? "") else { return nil }
            return EventSnapshot(
                index: index - 1,
                eventLocalDate: $0.eventLocalDate,
                timezoneOffsetMinutes: $0.timezoneOffsetMinutes,
                startedAtUTC: $0.startedAtUTC,
                completedAtUTC: $0.completedAtUTC,
                durationMilliseconds: $0.animationDurationMilliseconds
            )
        }
    }

}
#endif
