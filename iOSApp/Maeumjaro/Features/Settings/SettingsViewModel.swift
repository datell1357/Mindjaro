import MaeumjaroDomain
import MaeumjaroShared
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let settingsRepository: any SettingsRepository
    private let strengthStore: SharedStrengthStore
    private let onStrengthChanged: (@MainActor (Intensity) throws -> Intensity)?

    private(set) var settings: AppSettings
    private(set) var selectedIntensity: Intensity
    private(set) var errorMessage: String?

    init(
        initialSettings: AppSettings,
        settingsRepository: any SettingsRepository,
        strengthStore: SharedStrengthStore,
        onStrengthChanged: (@MainActor (Intensity) throws -> Intensity)? = nil
    ) {
        settings = initialSettings
        self.settingsRepository = settingsRepository
        self.strengthStore = strengthStore
        self.onStrengthChanged = onStrengthChanged
        selectedIntensity = strengthStore.read()
    }

    func setIntensity(_ intensity: Intensity) async {
        let observedBeforeWrite = strengthStore.read()
        do {
            if let onStrengthChanged {
                selectedIntensity = try onStrengthChanged(intensity)
            } else {
                selectedIntensity = try strengthStore.write(intensity, writer: .app)
            }
            errorMessage = nil
        } catch {
            selectedIntensity = strengthStore.read()
            if selectedIntensity == .default { selectedIntensity = observedBeforeWrite }
            errorMessage = String(localized: "기본 강도를 저장하지 못했어요. 저장 확인을 할 수 없습니다.")
        }
    }

    func refreshIntensity() {
        selectedIntensity = strengthStore.read()
    }

    func refresh() async {
        refreshIntensity()
        do {
            settings = try await settingsRepository.load()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "설정을 불러오지 못했어요. 다시 시도해 주세요.")
        }
    }

    func setHapticsEnabled(_ value: Bool) async {
        let previous = settings
        settings.hapticsEnabled = value
        await persist(restoring: previous)
    }

    func setSoundEnabled(_ value: Bool) async {
        let previous = settings
        settings.soundEnabled = value
        await persist(restoring: previous)
    }

    func setReducedMotionEnabled(_ value: Bool) async {
        let previous = settings
        settings.reducedMotionEnabled = value
        await persist(restoring: previous)
    }

    func setPhraseTonePreference(_ value: PhraseTonePreference) async {
        let previous = settings
        settings.phraseTonePreference = value
        await persist(restoring: previous)
    }

    func dismissWidgetHelp() async {
        let previous = settings
        settings.widgetHelpBannerDismissed = true
        await persist(restoring: previous)
    }

    func restoreWidgetHelpBanner() async {
        let previous = settings
        settings.widgetHelpBannerDismissed = false
        await persist(restoring: previous)
    }

    private func persist(restoring previous: AppSettings) async {
        do {
            try await settingsRepository.save(settings)
            errorMessage = nil
        } catch {
            settings = previous
            errorMessage = String(localized: "설정을 저장하지 못했어요. 다시 시도해 주세요.")
        }
    }
}
