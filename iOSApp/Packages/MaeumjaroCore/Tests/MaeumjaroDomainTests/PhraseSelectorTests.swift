import Foundation
import Testing

import MaeumjaroDomain

@Test
func selectionUsesIntensityAndPreferredToneBeforeHistoryRules() {
    let gentle = Phrase(
        phraseID: "fixture.gentle.low",
        category: .nonjudgment,
        tone: .gentle,
        minimumIntensity: .one,
        maximumIntensity: .two,
        textKO: "지금의 마음을 부드럽게 바라봅니다."
    )
    let neutral = Phrase(
        phraseID: "fixture.neutral.high",
        category: .redirect,
        tone: .neutral,
        minimumIntensity: .four,
        maximumIntensity: .five,
        textKO: "다음 선택을 차분히 정합니다."
    )
    let selector = PhraseSelector(catalog: [gentle, neutral])
    let request = PhraseSelectionRequest(
        intensity: .five,
        tonePreference: .neutral,
        seed: 7
    )

    let selected = selector.select(request)

    #expect(selected.phraseID == neutral.phraseID)
}

@Test
func selectionExcludesRecentTenAndAThirdConsecutiveCategory() throws {
    let catalog = try PhraseCatalogFixture.load()
    let recent = Array(catalog.prefix(10))
    let request = PhraseSelectionRequest(
        intensity: .five,
        tonePreference: .neutral,
        recentPhraseIDs: recent.map(\.phraseID),
        recentCategories: [.autonomy, .autonomy],
        seed: 42
    )

    let selected = PhraseSelector(catalog: catalog).select(request)

    #expect(!recent.map(\.phraseID).contains(selected.phraseID))
    #expect(selected.category != .autonomy)
    #expect(selected.tone == .neutral)
}

@Test
func selectionIsDeterministicForTheSameSeedAndContext() throws {
    let catalog = try PhraseCatalogFixture.load()
    let request = PhraseSelectionRequest(
        intensity: .three,
        tonePreference: .automatic,
        recentPhraseIDs: ["phrase.separation.gentle.001"],
        recentCategories: [.redirect, .redirect],
        seed: 123_456
    )
    let selector = PhraseSelector(catalog: catalog)

    let first = selector.select(request)
    let second = selector.select(request)

    #expect(first == second)
}

@Test
func selectionReturnsStableSafeFallbackWhenEveryCandidateIsBlocked() {
    let blocked = Phrase(
        phraseID: "fixture.blocked",
        category: .separation,
        tone: .neutral,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "후보에서 제외할 문구입니다.",
        safetyStatus: .approved
    )
    let selector = PhraseSelector(catalog: [blocked])
    let request = PhraseSelectionRequest(
        intensity: .three,
        recentPhraseIDs: [blocked.phraseID],
        seed: 1
    )

    let selected = selector.select(request)

    #expect(selected == PhraseSelector.safeFallback)
    #expect(selected.phraseID == "phrase.safe-fallback.v1")
    #expect(selected.safetyStatus == .approved)
}

@Test
func selectionDoesNotRelaxToneOrCategorySafetyConstraints() {
    let recentNeutral = Phrase(
        phraseID: "fixture.recent-neutral",
        category: .separation,
        tone: .neutral,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "이미 선택한 중립 문구입니다."
    )
    let unblockedGentle = Phrase(
        phraseID: "fixture.unblocked-gentle",
        category: .separation,
        tone: .gentle,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "다른 어조의 문구입니다."
    )
    let selector = PhraseSelector(catalog: [recentNeutral, unblockedGentle])

    let selected = selector.select(
        PhraseSelectionRequest(
            intensity: .three,
            tonePreference: .neutral,
            recentPhraseIDs: [recentNeutral.phraseID],
            recentCategories: [.separation, .separation],
            seed: 42
        )
    )

    #expect(selected == PhraseSelector.safeFallback)
}

private enum PhraseCatalogFixture {
    static func load() throws -> [Phrase] {
        let sourceDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = sourceDirectory
            .appendingPathComponent("Sources")
            .appendingPathComponent("MaeumjaroPersistence")
            .appendingPathComponent("Resources")
            .appendingPathComponent("PhraseCatalog.ko.json")
        return try JSONDecoder().decode([Phrase].self, from: Data(contentsOf: catalogURL))
    }
}
