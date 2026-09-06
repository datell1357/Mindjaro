import Foundation
import Testing

import MaeumjaroDomain

@Test
func eventContractKeepsEveryCompletionFieldAndBothEntrySources() {
    let eventID = UUID(uuidString: "E7C22E0B-3B7E-48AA-BE26-6E0E5A74BC40")!
    let started = Date(timeIntervalSince1970: 1_757_000_000)
    let completed = started.addingTimeInterval(1.8)
    let event = InjectionEvent(
        id: eventID,
        startedAtUTC: started,
        completedAtUTC: completed,
        createdAtUTC: completed,
        eventLocalDate: "2026-09-05",
        timezoneOffsetMinutes: 540,
        intensity: .three,
        source: .app,
        phraseID: "phrase.autonomy.001",
        animationDurationMilliseconds: 1800,
        interruptedCount: 2,
        appVersion: "1.0 (1)"
    )

    #expect(event.id == eventID)
    #expect(event.startedAtUTC == started)
    #expect(event.completedAtUTC == completed)
    #expect(event.createdAtUTC == completed)
    #expect(event.eventLocalDate == "2026-09-05")
    #expect(event.timezoneOffsetMinutes == 540)
    #expect(event.intensity == .three)
    #expect(event.source == .app)
    #expect(event.phraseID == "phrase.autonomy.001")
    #expect(event.animationDurationMilliseconds == 1800)
    #expect(event.interruptedCount == 2)
    #expect(event.appVersion == "1.0 (1)")

    #expect(EventSource.allCases == [.app, .widget])
}

@Test
func eventContractRoundTripsTheFrozenCodingKeys() throws {
    let event = InjectionEvent(
        id: UUID(uuidString: "E7C22E0B-3B7E-48AA-BE26-6E0E5A74BC40")!,
        startedAtUTC: Date(timeIntervalSince1970: 1_757_000_000),
        completedAtUTC: Date(timeIntervalSince1970: 1_757_000_001),
        createdAtUTC: Date(timeIntervalSince1970: 1_757_000_001),
        eventLocalDate: "2026-09-05",
        timezoneOffsetMinutes: 540,
        intensity: .three,
        source: .widget,
        phraseID: "phrase.redirect.001",
        animationDurationMilliseconds: 1800,
        interruptedCount: 1,
        appVersion: "1.0 (1)"
    )
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(event)
    let decoded = try decoder.decode(InjectionEvent.self, from: encoded)

    #expect(decoded == event)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    #expect(object?.keys.sorted() == [
        "animationDurationMilliseconds", "appVersion", "completedAtUTC", "createdAtUTC",
        "eventLocalDate", "id", "intensity", "interruptedCount", "phraseID", "source",
        "startedAtUTC", "timezoneOffsetMinutes"
    ])
}

@Test
func phraseContractUsesOnlyApprovedCatalogDimensions() {
    let phrase = Phrase(
        phraseID: "phrase.autonomy.001",
        category: .autonomy,
        tone: .neutral,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "지금의 다음 선택만 바라봅니다.",
        safetyStatus: .approved,
        contentVersion: 1
    )

    #expect(PhraseCategory.allCases.count == 5)
    #expect(PhraseTone.allCases.count == 3)
    #expect(PhraseCategory.allCases.contains(phrase.category))
    #expect(PhraseTone.allCases.contains(phrase.tone))
    #expect(phrase.safetyStatus == .approved)
    #expect(phrase.contentVersion == 1)
    #expect(phrase.minimumIntensity.rawValue == 1)
    #expect(phrase.maximumIntensity.rawValue == 5)
}

@Test
func phraseContractEncodesOnlyTheCatalogFields() throws {
    let phrase = Phrase(
        phraseID: "phrase.redirect.001",
        category: .redirect,
        tone: .gentle,
        minimumIntensity: .one,
        maximumIntensity: .four,
        textKO: "다음 한 걸음에 집중합니다.",
        safetyStatus: .approved,
        contentVersion: 1
    )
    let encoded = try JSONEncoder().encode(phrase)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

    #expect(object?.keys.sorted() == [
        "category", "contentVersion", "maximumIntensity", "minimumIntensity", "phraseID",
        "safetyStatus", "textKO", "tone"
    ])
}

@Test
func appSettingsHasNoSecondIntensitySource() throws {
    let settings = AppSettings.default
    let storedPropertyNames = Mirror(reflecting: settings).children.compactMap(\.label)

    #expect(!storedPropertyNames.contains("intensity"))
    #expect(settings.onboardingCompleted == false)
    #expect(settings.hapticsEnabled == true)
    #expect(settings.soundEnabled == false)
    #expect(settings.reducedMotionEnabled == false)
    #expect(settings.phraseTonePreference == .automatic)
    #expect(settings.themeID == .quietIvory)
    #expect(settings.widgetHelpBannerDismissed == false)

    let encoded = try JSONEncoder().encode(settings)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    #expect(object?.keys.sorted() == [
        "hapticsEnabled", "onboardingCompleted", "phraseTonePreference", "reducedMotionEnabled",
        "soundEnabled", "themeID", "widgetHelpBannerDismissed"
    ])
    let roundTrip = try JSONDecoder().decode(AppSettings.self, from: encoded)
    #expect(roundTrip == settings)
}

@Test
func themesAreClosedAndDefaultToQuietIvory() {
    #expect(ThemeID.allCases == [.quietIvory, .midnightInk, .forestMist])
    #expect(ThemeID.default == .quietIvory)
}

@Test
func completionRequestCarriesTheSameSessionIdentityAndOutcomesAreExplicit() {
    let sessionID = UUID(uuidString: "E7C22E0B-3B7E-48AA-BE26-6E0E5A74BC40")!
    let event = InjectionEvent(
        id: sessionID,
        startedAtUTC: Date(timeIntervalSince1970: 1_757_000_000),
        completedAtUTC: Date(timeIntervalSince1970: 1_757_000_001),
        createdAtUTC: Date(timeIntervalSince1970: 1_757_000_001),
        eventLocalDate: "2026-09-05",
        timezoneOffsetMinutes: 540,
        intensity: .three,
        source: .widget,
        phraseID: "phrase.autonomy.001",
        animationDurationMilliseconds: 1800,
        interruptedCount: 0,
        appVersion: "1.0 (1)"
    )
    let request = CompletionRecordingRequest(sessionID: sessionID, event: event)

    #expect(request.sessionID == sessionID)
    #expect(request.event.id == sessionID)
    #expect(request.isIdempotencyConsistent)
    #expect(CompletionRecordingOutcome.allCases == [.inserted, .alreadyRecorded])
}

@Test
func completionRequestRejectsAChangedSessionIdentityAtThePortBoundary() {
    let sessionID = UUID(uuidString: "E7C22E0B-3B7E-48AA-BE26-6E0E5A74BC40")!
    let event = InjectionEvent(
        id: UUID(uuidString: "62BD8E4D-D6F5-4DA1-A8BF-F30E6A32F7AA")!,
        startedAtUTC: Date(timeIntervalSince1970: 1_757_000_000),
        completedAtUTC: Date(timeIntervalSince1970: 1_757_000_001),
        createdAtUTC: Date(timeIntervalSince1970: 1_757_000_001),
        eventLocalDate: "2026-09-05",
        timezoneOffsetMinutes: 540,
        intensity: .three,
        source: .app,
        phraseID: "phrase.autonomy.001",
        animationDurationMilliseconds: 1800,
        interruptedCount: 0,
        appVersion: "1.0 (1)"
    )
    let request = CompletionRecordingRequest(sessionID: sessionID, event: event)

    #expect(!request.isIdempotencyConsistent)
    #expect((try? request.validated()) == nil)
}

@Test
func injectableClockAndUUIDPortsExposeDeterministicBoundaries() {
    let now = Date(timeIntervalSince1970: 1_757_000_000)
    let clock = FixedClock(nowUTC: now)
    let id = UUID(uuidString: "E7C22E0B-3B7E-48AA-BE26-6E0E5A74BC40")!
    let generator = FixedUUIDGenerator(id: id)

    #expect(clock.nowUTC == now)
    #expect(generator.makeUUID() == id)
}

private struct FixedClock: Clock {
    let nowUTC: Date
}

private struct FixedUUIDGenerator: UUIDGenerator {
    let id: UUID

    func makeUUID() -> UUID { id }
}
