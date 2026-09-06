import MaeumjaroDomain

public enum AppSettingsMapper {
    public static func makeModel(from settings: AppSettings) -> MaeumjaroSchemaV1.Settings {
        MaeumjaroSchemaV1.Settings(
            onboardingCompleted: settings.onboardingCompleted,
            hapticsEnabled: settings.hapticsEnabled,
            soundEnabled: settings.soundEnabled,
            reducedMotionEnabled: settings.reducedMotionEnabled,
            phraseTonePreferenceRawValue: settings.phraseTonePreference.rawValue,
            themeIDRawValue: settings.themeID.rawValue,
            widgetHelpBannerDismissed: settings.widgetHelpBannerDismissed
        )
    }

    public static func makeDomain(from model: MaeumjaroSchemaV1.Settings) throws -> AppSettings {
        guard let tonePreference = PhraseTonePreference(rawValue: model.phraseTonePreferenceRawValue) else {
            throw PersistenceError.invalidStoredValue(entity: "settings", field: "phraseTonePreference")
        }
        guard let themeID = ThemeID(rawValue: model.themeIDRawValue) else {
            throw PersistenceError.invalidStoredValue(entity: "settings", field: "themeID")
        }
        return AppSettings(
            onboardingCompleted: model.onboardingCompleted,
            hapticsEnabled: model.hapticsEnabled,
            soundEnabled: model.soundEnabled,
            reducedMotionEnabled: model.reducedMotionEnabled,
            phraseTonePreference: tonePreference,
            themeID: themeID,
            widgetHelpBannerDismissed: model.widgetHelpBannerDismissed
        )
    }
}

public enum PhraseMapper {
    public static func makeModel(from phrase: Phrase) -> MaeumjaroSchemaV1.Phrase {
        MaeumjaroSchemaV1.Phrase(
            phraseID: phrase.phraseID,
            categoryRawValue: phrase.category.rawValue,
            toneRawValue: phrase.tone.rawValue,
            minimumIntensityRawValue: phrase.minimumIntensity.rawValue,
            maximumIntensityRawValue: phrase.maximumIntensity.rawValue,
            textKO: phrase.textKO,
            safetyStatusRawValue: phrase.safetyStatus.rawValue,
            contentVersion: phrase.contentVersion
        )
    }

    public static func makeDomain(from model: MaeumjaroSchemaV1.Phrase) throws -> Phrase {
        guard let category = PhraseCategory(rawValue: model.categoryRawValue) else {
            throw PersistenceError.invalidStoredValue(entity: "phrase", field: "category")
        }
        guard let tone = PhraseTone(rawValue: model.toneRawValue) else {
            throw PersistenceError.invalidStoredValue(entity: "phrase", field: "tone")
        }
        guard let minimumIntensity = Intensity(rawValue: model.minimumIntensityRawValue),
              let maximumIntensity = Intensity(rawValue: model.maximumIntensityRawValue),
              minimumIntensity <= maximumIntensity,
              !model.phraseID.isEmpty,
              !model.textKO.isEmpty,
              model.contentVersion >= 1 else {
            throw PersistenceError.invalidStoredValue(entity: "phrase", field: "content")
        }
        guard let safetyStatus = PhraseSafetyStatus(rawValue: model.safetyStatusRawValue) else {
            throw PersistenceError.invalidStoredValue(entity: "phrase", field: "safetyStatus")
        }
        return Phrase(
            phraseID: model.phraseID,
            category: category,
            tone: tone,
            minimumIntensity: minimumIntensity,
            maximumIntensity: maximumIntensity,
            textKO: model.textKO,
            safetyStatus: safetyStatus,
            contentVersion: model.contentVersion
        )
    }
}
