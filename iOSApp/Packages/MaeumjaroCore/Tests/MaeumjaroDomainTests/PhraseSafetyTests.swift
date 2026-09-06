import Foundation
import Testing

import MaeumjaroDomain

@Test
func bundledCatalogHasStableApprovedEntriesAcrossEveryCategoryAndTone() throws {
    let catalog = try PhraseCatalogFixture.load()

    #expect(catalog.count >= 100)
    #expect(Set(catalog.map(\.phraseID)).count == catalog.count)
    #expect(catalog.allSatisfy { $0.phraseID.hasPrefix("phrase.") && !$0.phraseID.contains(" ") })
    #expect(Set(catalog.map(\.category)) == Set(PhraseCategory.allCases))
    #expect(Set(catalog.map(\.tone)) == Set(PhraseTone.allCases))
    for phrase in catalog {
        #expect(!phrase.phraseID.isEmpty)
        #expect(!phrase.textKO.isEmpty)
        #expect(phrase.minimumIntensity <= phrase.maximumIntensity)
        #expect(phrase.safetyStatus == .approved)
        #expect(phrase.contentVersion == 1)
    }
}

@Test
func bundledCatalogContainsNoMedicalOrJudgmentClaims() throws {
    let catalog = try PhraseCatalogFixture.load()
    let forbiddenTerms = [
        "식욕", "체중", "칼로리", "약물", "의약", "의료", "치료", "완치", "예방", "진단",
        "질환", "처방", "복용", "투여", "용량", "도즈", "mg", "효과", "효능", "성공",
        "실패", "의지력", "의지", "죄책", "수치심", "비난", "잘못", "게으", "정상",
        "비정상", "금지", "명령", "참아", "억제", "제거", "차단", "감량", "감소", "빠짐",
        "빼기", "마운자로", "Mounjaro"
    ]

    for phrase in catalog {
        for term in forbiddenTerms {
            #expect(!phrase.textKO.contains(term))
        }
    }
}

@Test
func safeFallbackIsStableAndPassesTheSameContentBoundary() {
    let fallback = PhraseSelector.safeFallback

    #expect(fallback.phraseID == "phrase.safe-fallback.v1")
    #expect(fallback.category == .nonjudgment)
    #expect(fallback.tone == .neutral)
    #expect(fallback.minimumIntensity == .one)
    #expect(fallback.maximumIntensity == .five)
    #expect(fallback.safetyStatus == .approved)
    #expect(fallback.contentVersion == 1)
    #expect(!fallback.textKO.contains("식욕"))
    #expect(!fallback.textKO.contains("체중"))
    #expect(!fallback.textKO.contains("치료"))
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
