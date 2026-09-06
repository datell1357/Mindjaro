import MaeumjaroDomain
import XCTest
@testable import Maeumjaro

@MainActor
final class DataManagementViewModelTests: XCTestCase {
    func testRevokedEntitlementBlocksExportAndProTheme() async {
        let repository = DataSettingsFake()
        let eventRepository = DataEventFake(events: [DataManagementViewModelTests.event])
        let model = DataManagementViewModel(
            settings: .default, entitlement: .pro, eventRepository: eventRepository,
            settingsRepository: repository, currentEntitlement: { .revoked }
        )

        let export = await model.export(format: .csv)
        XCTAssertNil(export)
        await model.selectTheme(.midnightInk)

        XCTAssertEqual(model.selectedTheme, .quietIvory)
        XCTAssertEqual(repository.settings.themeID, .quietIvory)
    }

    func testWidgetFailureLeavesDurableThemeAndReportsPendingSync() async {
        let repository = DataSettingsFake()
        let model = DataManagementViewModel(
            settings: .default, entitlement: .pro, eventRepository: DataEventFake(),
            settingsRepository: repository, onWidgetThemeChange: { _ in throw DataTestError.failed },
            currentEntitlement: { .pro }
        )

        await model.selectTheme(.forestMist)

        XCTAssertEqual(repository.settings.themeID, .forestMist)
        XCTAssertEqual(model.selectedTheme, .forestMist)
        XCTAssertEqual(model.settingsMessage, "테마는 저장됐지만 위젯을 아직 갱신하지 못했어요.")
    }

    func testDeleteConfirmationSurvivesDialogAutoDismissal() async {
        let eventRepository = DataEventFake(events: [Self.event])
        let model = DataManagementViewModel(
            settings: .default, entitlement: .free, eventRepository: eventRepository,
            settingsRepository: DataSettingsFake()
        )

        model.presentDeleteConfirmation()
        XCTAssertTrue(model.acceptDeleteConfirmation())
        XCTAssertFalse(model.isDeleteConfirmationPresented)
        // SwiftUI invokes the confirmation binding setter as the dialog
        // dismisses after the destructive action is selected.
        model.cancelDelete()
        await model.confirmDeleteAll()

        XCTAssertTrue(eventRepository.events.isEmpty)
        XCTAssertEqual(model.exportMessage, "모든 기록을 삭제했어요.")
    }

    func testDeleteCancellationAndUnconfirmedCallDoNotDelete() async {
        let eventRepository = DataEventFake(events: [Self.event])
        let model = DataManagementViewModel(
            settings: .default, entitlement: .free, eventRepository: eventRepository,
            settingsRepository: DataSettingsFake()
        )

        await model.confirmDeleteAll()
        XCTAssertEqual(eventRepository.events.count, 1)

        model.presentDeleteConfirmation()
        model.cancelDelete()
        await model.confirmDeleteAll()
        XCTAssertEqual(eventRepository.events.count, 1)
    }

    static let event = InjectionEvent(
        id: UUID(), startedAtUTC: .distantPast, completedAtUTC: .distantPast,
        createdAtUTC: .distantPast, eventLocalDate: "2026-09-05", timezoneOffsetMinutes: 540,
        intensity: .three, source: .app, phraseID: "safe", animationDurationMilliseconds: 1,
        interruptedCount: 0, appVersion: "test"
    )
}

private enum DataTestError: Error { case failed }

@MainActor private final class DataSettingsFake: SettingsRepository {
    var settings = AppSettings.default
    func load() async throws -> AppSettings { settings }
    func save(_ settings: AppSettings) async throws { self.settings = settings }
}

@MainActor private final class DataEventFake: EventRepository {
    var events: [InjectionEvent]
    init(events: [InjectionEvent] = []) { self.events = events }
    func insert(_ event: InjectionEvent) async throws { events.append(event) }
    func fetchAll() async throws -> [InjectionEvent] { events }
    func fetch(id: UUID) async throws -> InjectionEvent? { events.first { $0.id == id } }
    func delete(id: UUID) async throws { events.removeAll { $0.id == id } }
    func deleteAll() async throws { events.removeAll() }
}
