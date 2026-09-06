#if MAEUMJARO_QA_FIXTURES
import Foundation
import MaeumjaroDomain
import MaeumjaroPersistence
import MaeumjaroShared
import SwiftData

@MainActor
enum QAFixtureSeeder {
    static func seed(
        _ fixture: QAFixtureConfiguration,
        container: ModelContainer,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) throws {
        guard fixture.name != .empty, fixture.name != .ritual, fixture.name != .offline else { return }

        let context = container.mainContext
        let existingSettings = try context.fetch(FetchDescriptor<MaeumjaroSchemaV1.Settings>())
        // Settings are the durable "seed was applied" marker. Once the fixture
        // is in use, never restore deleted events or overwrite a chosen theme.
        if !existingSettings.isEmpty { return }
        let existing = try context.fetch(FetchDescriptor<MaeumjaroSchemaV1.Event>())
        let existingIDs = Set(existing.map(\.id))
        let events = makeEvents(for: fixture, now: now, calendar: calendar)
        for event in events where !existingIDs.contains(event.id) {
            context.insert(InjectionEventMapper.makeModel(from: event))
        }

        context.insert(MaeumjaroSchemaV1.Settings(
            onboardingCompleted: true,
            hapticsEnabled: true,
            soundEnabled: false,
            reducedMotionEnabled: false,
            phraseTonePreferenceRawValue: PhraseTonePreference.automatic.rawValue,
            themeIDRawValue: (fixture.name == .proBoundary ? ThemeID.midnightInk : ThemeID.quietIvory).rawValue,
            widgetHelpBannerDismissed: false
        ))
        try context.save()
    }

    private static func makeEvents(
        for fixture: QAFixtureConfiguration,
        now: Date,
        calendar: Calendar
    ) -> [InjectionEvent] {
        let count: Int
        switch fixture.name {
        case .analyticsReference: count = 40
        case .freeBoundary: count = 31
        case .proBoundary: count = 38
        case .empty, .ritual, .offline: count = 0
        }
        var localCalendar = calendar
        localCalendar.timeZone = calendar.timeZone
        let formatter = DateFormatter()
        formatter.calendar = localCalendar
        formatter.timeZone = localCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return (0..<count).compactMap { index in
            let completed: Date
            switch fixture.name {
            case .freeBoundary:
                guard let date = localCalendar.date(byAdding: .day, value: -(index == count - 1 ? 30 : index % 30), to: now) else { return nil }
                completed = date
            case .proBoundary:
                // Match HistoryWindow.pro: Monday minus 51 weeks is included;
                // the preceding day is explicitly outside the 52-week window.
                guard let today = AnalyticsDate(formatter.string(from: now)),
                      let window = HistoryWindow.pro(today: today.rawValue),
                      let start = formatter.date(from: index == 1 ? (AnalyticsDate(window.startDate)?.addingDays(-1)?.rawValue ?? window.startDate) : window.startDate),
                      let date = localCalendar.date(byAdding: .day, value: index > 1 ? ((index - 2) * 11) % 364 : 0, to: start) else { return nil }
                completed = date
            case .analyticsReference:
                guard let date = localCalendar.date(byAdding: .day, value: -(index * 13) % 364, to: now) else { return nil }
                completed = date
            case .empty, .ritual, .offline: return nil
            }
            let intensity = Intensity(rawValue: (index % 5) + 1)!
            let durationMilliseconds = IntensityProfile(intensity: intensity).durationMilliseconds
            let started = completed.addingTimeInterval(-Double(durationMilliseconds) / 1_000)
            return InjectionEvent(
                id: derivedID(from: fixture.fixtureID, index: index),
                startedAtUTC: started,
                completedAtUTC: completed,
                createdAtUTC: completed,
                eventLocalDate: formatter.string(from: completed),
                timezoneOffsetMinutes: localCalendar.timeZone.secondsFromGMT(for: completed) / 60,
                intensity: intensity,
                source: index.isMultiple(of: 2) ? .app : .widget,
                phraseID: "fixture.\(fixture.name.rawValue).\(index + 1)",
                animationDurationMilliseconds: durationMilliseconds,
                interruptedCount: index % 3,
                appVersion: "qa-fixture"
            )
        }
    }

    private static func derivedID(from base: UUID, index: Int) -> UUID {
        var bytes = base.uuid
        withUnsafeMutableBytes(of: &bytes) { raw in
            raw[index % 16] ^= UInt8(truncatingIfNeeded: index + 1)
            raw[(index + 5) % 16] ^= UInt8(truncatingIfNeeded: (index + 1) * 31)
        }
        return UUID(uuid: bytes)
    }
}

struct QAVerifiedProEntitlementClient: StoreKitPurchaseClientProtocol {
    func product() async throws -> PurchaseProduct {
        PurchaseProduct(id: StoreKitPurchaseClient.productID, displayNameKorean: "Pro", displayNameEnglish: "Pro", displayPrice: "", isNonConsumable: true)
    }
    func purchase() async -> PurchaseResult { .success(.verified(VerifiedTransactionEvidence(productID: StoreKitPurchaseClient.productID, transactionID: 1, originalTransactionID: 1))) }
    func currentEntitlements() async throws -> [TransactionEvidence] { [.verified(VerifiedTransactionEvidence(productID: StoreKitPurchaseClient.productID, transactionID: 1, originalTransactionID: 1))] }
    func transactionUpdates() -> AsyncStream<TransactionEvidence> { AsyncStream { $0.finish() } }
    func syncStore() async throws {}
}
#endif
