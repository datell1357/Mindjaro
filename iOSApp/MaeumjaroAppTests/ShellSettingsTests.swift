import MaeumjaroDomain
import MaeumjaroShared
import XCTest
@testable import Maeumjaro

@MainActor
final class ShellSettingsTests: XCTestCase {
    func testSettingsIntensityUsesProjectionCallbackAndRefreshesSharedValue() async {
        let defaults = AppGroupDefaults(storage: MemoryDataStore())
        let store = SharedStrengthStore(defaults: defaults)
        let repository = ShellSettingsRepositoryFake()
        var callbackValues: [Intensity] = []
        let model = SettingsViewModel(
            initialSettings: .default,
            settingsRepository: repository,
            strengthStore: store,
            onStrengthChanged: { intensity in
                callbackValues.append(intensity)
                return try store.write(intensity, writer: .app)
            }
        )

        await model.setIntensity(.five)

        XCTAssertEqual(callbackValues, [.five])
        XCTAssertEqual(model.selectedIntensity, .five)
        XCTAssertEqual(store.read(), .five)
    }

    func testSettingsSaveFailureRestoresPreviousValue() async {
        let repository = ShellSettingsRepositoryFake()
        repository.shouldFailSave = true
        let model = SettingsViewModel(
            initialSettings: .default,
            settingsRepository: repository,
            strengthStore: SharedStrengthStore(defaults: AppGroupDefaults(storage: MemoryDataStore()))
        )

        await model.setSoundEnabled(true)

        XCTAssertFalse(model.settings.soundEnabled)
        XCTAssertEqual(model.errorMessage, "설정을 저장하지 못했어요. 다시 시도해 주세요.")
    }

    func testOnboardingIntensityCallbackReadbackFailureRestoresObservedValue() {
        let defaults = AppGroupDefaults(storage: MemoryDataStore())
        let store = SharedStrengthStore(defaults: defaults)
        _ = try? store.write(.two, writer: .app)
        let model = OnboardingViewModel(
            initialSettings: .default,
            settingsRepository: ShellSettingsRepositoryFake(),
            strengthStore: store,
            onStrengthChanged: { _ in throw ShellSettingsTestError.failed }
        )

        model.selectIntensity(.five)

        XCTAssertEqual(model.selectedIntensity, .two)
        XCTAssertNotNil(model.errorMessage)
    }
}

private enum ShellSettingsTestError: Error { case failed }

@MainActor
private final class ShellSettingsRepositoryFake: SettingsRepository {
    var settings = AppSettings.default
    var shouldFailSave = false

    func load() async throws -> AppSettings { settings }

    func save(_ settings: AppSettings) async throws {
        if shouldFailSave { throw ShellSettingsTestError.failed }
        self.settings = settings
    }
}
