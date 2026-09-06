import Foundation
import MaeumjaroDomain
import MaeumjaroShared
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable, Sendable {
        case purpose
        case howToUse
        case intensity
        case feedback
        case safety
        case widgetHelp

        var number: Int { rawValue + 1 }

        var next: Self? {
            Self(rawValue: rawValue + 1)
        }
    }

    private let settingsRepository: any SettingsRepository
    private let strengthStore: SharedStrengthStore
    private let onStrengthChanged: (@MainActor (Intensity) throws -> Intensity)?

    private(set) var settings: AppSettings
    private(set) var selectedIntensity: Intensity
    private(set) var step: Step = .purpose
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

    func start() {
        guard step == .purpose else { return }
        step = .howToUse
    }

    func selectIntensity(_ intensity: Intensity) {
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

    func setHapticsEnabled(_ value: Bool) async {
        let previous = settings
        settings.hapticsEnabled = value
        await persistSettings(restoring: previous)
    }

    func setSoundEnabled(_ value: Bool) async {
        let previous = settings
        settings.soundEnabled = value
        await persistSettings(restoring: previous)
    }

    func setReducedMotionEnabled(_ value: Bool) async {
        let previous = settings
        settings.reducedMotionEnabled = value
        await persistSettings(restoring: previous)
    }

    func advance() async -> AppSettings? {
        guard step != .purpose else {
            start()
            return nil
        }
        guard let next = step.next else { return await complete() }
        step = next
        return nil
    }

    func skipWidgetHelp() async -> AppSettings? {
        settings.widgetHelpBannerDismissed = true
        return await complete()
    }

    private func complete() async -> AppSettings? {
        settings.onboardingCompleted = true
        do {
            try await settingsRepository.save(settings)
            errorMessage = nil
            return settings
        } catch {
            errorMessage = String(localized: "설정을 저장하지 못했어요. 다시 시도해 주세요.")
            return nil
        }
    }

    private func persistSettings(restoring previous: AppSettings) async {
        do {
            try await settingsRepository.save(settings)
            errorMessage = nil
        } catch {
            settings = previous
            errorMessage = String(localized: "설정을 저장하지 못했어요. 다시 시도해 주세요.")
        }
    }
}
