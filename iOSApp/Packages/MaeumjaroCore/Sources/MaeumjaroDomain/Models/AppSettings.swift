import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var onboardingCompleted: Bool
    public var hapticsEnabled: Bool
    public var soundEnabled: Bool
    public var reducedMotionEnabled: Bool
    public var phraseTonePreference: PhraseTonePreference
    public var themeID: ThemeID
    public var widgetHelpBannerDismissed: Bool

    public init(
        onboardingCompleted: Bool = false,
        hapticsEnabled: Bool = true,
        soundEnabled: Bool = false,
        reducedMotionEnabled: Bool = false,
        phraseTonePreference: PhraseTonePreference = .automatic,
        themeID: ThemeID = .default,
        widgetHelpBannerDismissed: Bool = false
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.hapticsEnabled = hapticsEnabled
        self.soundEnabled = soundEnabled
        self.reducedMotionEnabled = reducedMotionEnabled
        self.phraseTonePreference = phraseTonePreference
        self.themeID = themeID
        self.widgetHelpBannerDismissed = widgetHelpBannerDismissed
    }

    public static let `default` = AppSettings()

}
