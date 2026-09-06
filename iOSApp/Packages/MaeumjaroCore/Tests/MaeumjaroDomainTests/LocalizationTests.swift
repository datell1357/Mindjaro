import Testing
import MaeumjaroDomain

@Test
func analyticsLabelsAreKoreanAndDoNotChangeWireValues() {
    #expect(HeatmapMetric.count.rawValue == "count")
    #expect(HeatmapMetric.count.displayName == "횟수")
    #expect(HeatmapMetric.intensitySum.rawValue == "intensitySum")
    #expect(HeatmapMetric.intensitySum.displayName == "강도 합")
    #expect(SampleTier.insufficient.displayName == "기록 부족")
    #expect(CountBucket.sevenOrMore.displayName == "7회 이상")
}

@Test
func phraseDisplayTextUsesTheCatalogValueWhileKeepingStableID() {
    let phrase = Phrase(
        phraseID: "phrase.separation.gentle.001",
        category: .autonomy,
        tone: .neutral,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "카탈로그에 없는 fallback"
    )

    #expect(phrase.phraseID == "phrase.separation.gentle.001")
    #expect(phrase.displayText == "떠오른 생각과 다음 행동을 잠시 나누어 살핍니다.")
}
