import Foundation
import MaeumjaroDomain
import MaeumjaroPersistence

@MainActor
func runPhrasesProbe(_ arguments: ProbeArguments) throws -> ProbeResponse {
    let catalog = try PhraseCatalogSeeder.loadBundledCatalog()
    guard !catalog.isEmpty else {
        throw ProbeCommandError.invalidArguments(command: "phrases", detail: "empty-catalog")
    }

    let intensity = try parseIntensity(arguments.value(for: "intensity"))
    let tonePreference = try parseTone(arguments.value(for: "tone"))
    let seed = try parseSeed(arguments.value(for: "seed"))
    let fixture = arguments.value(for: "fixture")
    let historyOption = arguments.value(for: "history")

    guard fixture == nil || historyOption == nil else {
        throw ProbeCommandError.invalidArguments(command: "phrases", detail: "fixture-and-history-are-exclusive")
    }

    let history: PhraseHistory
    switch historyOption {
    case nil:
        history = PhraseHistory()
    case "fixture:last10":
        let recent = Array(catalog.suffix(10))
        history = PhraseHistory(
            phraseIDs: recent.map(\.phraseID),
            categories: recent.map(\.category)
        )
    default:
        throw ProbeCommandError.invalidArguments(command: "phrases", detail: "invalid-history")
    }

    let selection: Phrase
    switch fixture {
    case nil:
        selection = PhraseSelector(catalog: catalog).select(
            PhraseSelectionRequest(
                intensity: intensity,
                tonePreference: tonePreference,
                recentPhraseIDs: history.phraseIDs,
                recentCategories: history.categories,
                seed: seed
            )
        )
    case "all-excluded":
        guard let firstPhrase = catalog.first else {
            throw ProbeCommandError.invalidArguments(command: "phrases", detail: "empty-catalog")
        }
        selection = PhraseSelector(catalog: [firstPhrase]).select(
            PhraseSelectionRequest(
                intensity: intensity,
                tonePreference: tonePreference,
                recentPhraseIDs: [firstPhrase.phraseID],
                recentCategories: [firstPhrase.category],
                seed: seed
            )
        )
    default:
        throw ProbeCommandError.invalidArguments(command: "phrases", detail: "invalid-fixture")
    }

    let fallbackID = PhraseSelector.safeFallback.phraseID
    let repeatedCategory = history.categories.count >= 2
        && history.categories.suffix(2).first == history.categories.suffix(2).last
    let avoidsCategoryTail = !repeatedCategory
        || history.categories.last != selection.category

    return ProbeResponse(
        command: "phrases",
        status: "ok",
        data: [
            "catalogCount": .integer(catalog.count),
            "category": .string(selection.category.rawValue),
            "contentVersion": .integer(selection.contentVersion),
            "fallbackPhraseID": .string(fallbackID),
            "fixture": fixture.map(ProbeJSONValue.string) ?? .null,
            "historyCount": .integer(history.phraseIDs.count),
            "historyPhraseIDs": .array(history.phraseIDs.map(ProbeJSONValue.string)),
            "isFallback": .boolean(selection.phraseID == fallbackID),
            "minimumIntensity": .integer(selection.minimumIntensity.rawValue),
            "maximumIntensity": .integer(selection.maximumIntensity.rawValue),
            "avoidsCategoryTail": .boolean(avoidsCategoryTail),
            "phraseID": .string(selection.phraseID),
            "requestedIntensity": .integer(intensity.rawValue),
            "requestedTone": .string(tonePreference.rawValue),
            "safetyStatus": .string(selection.safetyStatus.rawValue),
            "seed": .string(String(seed)),
            "source": .string("MaeumjaroPersistence.Bundle.module"),
            "textKO": .string(selection.textKO),
            "tone": .string(selection.tone.rawValue)
        ]
    )
}

private struct PhraseHistory {
    let phraseIDs: [String]
    let categories: [PhraseCategory]

    init(phraseIDs: [String] = [], categories: [PhraseCategory] = []) {
        self.phraseIDs = phraseIDs
        self.categories = categories
    }
}

private func parseIntensity(_ value: String?) throws -> Intensity {
    guard let value, let rawValue = Int(value), let intensity = Intensity(rawValue: rawValue) else {
        throw ProbeCommandError.invalidArguments(command: "phrases", detail: "invalid-intensity")
    }
    return intensity
}

private func parseTone(_ value: String?) throws -> PhraseTonePreference {
    let rawValue = value ?? "automatic"
    guard let tone = PhraseTonePreference(rawValue: rawValue) else {
        throw ProbeCommandError.invalidArguments(command: "phrases", detail: "invalid-tone")
    }
    return tone
}

private func parseSeed(_ value: String?) throws -> UInt64 {
    let rawValue = value ?? "0"
    guard let seed = UInt64(rawValue) else {
        throw ProbeCommandError.invalidArguments(command: "phrases", detail: "invalid-seed")
    }
    return seed
}
