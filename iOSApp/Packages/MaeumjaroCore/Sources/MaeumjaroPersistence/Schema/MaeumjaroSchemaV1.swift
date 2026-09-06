import Foundation
import SwiftData

public enum MaeumjaroSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static let models: [any PersistentModel.Type] = [
        Event.self,
        Settings.self,
        Phrase.self
    ]

    @Model
    public final class Event {
        @Attribute(.unique) public var id: UUID
        public var startedAtUTC: Date
        public var completedAtUTC: Date
        public var createdAtUTC: Date
        public var eventLocalDate: String
        public var timezoneOffsetMinutes: Int
        public var intensityRawValue: Int
        public var sourceRawValue: String
        public var phraseID: String
        public var animationDurationMilliseconds: Int
        public var interruptedCount: Int
        public var appVersion: String

        public init(
            id: UUID,
            startedAtUTC: Date,
            completedAtUTC: Date,
            createdAtUTC: Date,
            eventLocalDate: String,
            timezoneOffsetMinutes: Int,
            intensityRawValue: Int,
            sourceRawValue: String,
            phraseID: String,
            animationDurationMilliseconds: Int,
            interruptedCount: Int,
            appVersion: String
        ) {
            self.id = id
            self.startedAtUTC = startedAtUTC
            self.completedAtUTC = completedAtUTC
            self.createdAtUTC = createdAtUTC
            self.eventLocalDate = eventLocalDate
            self.timezoneOffsetMinutes = timezoneOffsetMinutes
            self.intensityRawValue = intensityRawValue
            self.sourceRawValue = sourceRawValue
            self.phraseID = phraseID
            self.animationDurationMilliseconds = animationDurationMilliseconds
            self.interruptedCount = interruptedCount
            self.appVersion = appVersion
        }
    }

    @Model
    public final class Settings {
        @Attribute(.unique) public var id: String
        public var onboardingCompleted: Bool
        public var hapticsEnabled: Bool
        public var soundEnabled: Bool
        public var reducedMotionEnabled: Bool
        public var phraseTonePreferenceRawValue: String
        public var themeIDRawValue: String
        public var widgetHelpBannerDismissed: Bool

        public init(
            id: String = "singleton",
            onboardingCompleted: Bool,
            hapticsEnabled: Bool,
            soundEnabled: Bool,
            reducedMotionEnabled: Bool,
            phraseTonePreferenceRawValue: String,
            themeIDRawValue: String,
            widgetHelpBannerDismissed: Bool
        ) {
            self.id = id
            self.onboardingCompleted = onboardingCompleted
            self.hapticsEnabled = hapticsEnabled
            self.soundEnabled = soundEnabled
            self.reducedMotionEnabled = reducedMotionEnabled
            self.phraseTonePreferenceRawValue = phraseTonePreferenceRawValue
            self.themeIDRawValue = themeIDRawValue
            self.widgetHelpBannerDismissed = widgetHelpBannerDismissed
        }
    }

    @Model
    public final class Phrase {
        @Attribute(.unique) public var phraseID: String
        public var categoryRawValue: String
        public var toneRawValue: String
        public var minimumIntensityRawValue: Int
        public var maximumIntensityRawValue: Int
        public var textKO: String
        public var safetyStatusRawValue: String
        public var contentVersion: Int

        public init(
            phraseID: String,
            categoryRawValue: String,
            toneRawValue: String,
            minimumIntensityRawValue: Int,
            maximumIntensityRawValue: Int,
            textKO: String,
            safetyStatusRawValue: String,
            contentVersion: Int
        ) {
            self.phraseID = phraseID
            self.categoryRawValue = categoryRawValue
            self.toneRawValue = toneRawValue
            self.minimumIntensityRawValue = minimumIntensityRawValue
            self.maximumIntensityRawValue = maximumIntensityRawValue
            self.textKO = textKO
            self.safetyStatusRawValue = safetyStatusRawValue
            self.contentVersion = contentVersion
        }
    }
}

public extension MaeumjaroSchemaV1 {
    typealias InjectionEvent = Event
    typealias AppSettings = Settings
    typealias PhraseRecord = Phrase
}
