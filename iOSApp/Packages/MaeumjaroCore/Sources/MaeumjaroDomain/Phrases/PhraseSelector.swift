import Foundation

public struct PhraseSelectionRequest: Sendable {
    public let intensity: Intensity
    public let tonePreference: PhraseTonePreference
    public let recentPhraseIDs: [String]
    public let recentCategories: [PhraseCategory]
    public let seed: UInt64

    public init(
        intensity: Intensity,
        tonePreference: PhraseTonePreference = .automatic,
        recentPhraseIDs: [String] = [],
        recentCategories: [PhraseCategory] = [],
        seed: UInt64 = 0
    ) {
        self.intensity = intensity
        self.tonePreference = tonePreference
        self.recentPhraseIDs = recentPhraseIDs
        self.recentCategories = recentCategories
        self.seed = seed
    }
}

public struct PhraseSelector: Sendable {
    public static let safeFallback = Phrase(
        phraseID: "phrase.safe-fallback.v1",
        category: .nonjudgment,
        tone: .neutral,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "지금의 마음을 바라보고 다음 선택을 천천히 고릅니다."
    )

    private let catalog: [Phrase]

    public init(catalog: [Phrase]) {
        self.catalog = catalog
    }

    public func select(_ request: PhraseSelectionRequest) -> Phrase {
        let eligible = catalog.filter { phrase in
            phrase.safetyStatus == .approved
                && !phrase.phraseID.isEmpty
                && !phrase.textKO.isEmpty
                && phrase.minimumIntensity <= phrase.maximumIntensity
                && phrase.minimumIntensity <= request.intensity
                && request.intensity <= phrase.maximumIntensity
        }

        let preferred = eligible.filter { phrase in
            request.tonePreference == .automatic || phrase.tone == request.tonePreference.tone
        }
        let recentIDs = Set(request.recentPhraseIDs.suffix(10))
        let categoryTail = request.recentCategories.suffix(2)
        let repeatedCategory = categoryTail.count == 2 && categoryTail.first == categoryTail.last

        let candidates = preferred.filter {
            !recentIDs.contains($0.phraseID)
                && (!repeatedCategory || $0.category != categoryTail.last)
        }

        guard !candidates.isEmpty else {
            return Self.safeFallback
        }

        var generator = SplitMix64(seed: request.seed)
        let index = Int(generator.next() % UInt64(candidates.count))
        return candidates[index]
    }

}

private extension PhraseTonePreference {
    var tone: PhraseTone {
        switch self {
        case .automatic:
            .neutral
        case .gentle:
            .gentle
        case .neutral:
            .neutral
        case .firm:
            .firm
        }
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
