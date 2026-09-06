public enum HeatmapScale {
    public static func countBucket(for value: Int) -> CountBucket {
        switch max(0, value) {
        case 0: .zero
        case 1: .one
        case 2: .two
        case 3...4: .threeToFour
        case 5...6: .fiveToSix
        default: .sevenOrMore
        }
    }

    public static func intensitySumBucket(for value: Int) -> IntensitySumBucket {
        switch max(0, value) {
        case 0: .zero
        case 1...3: .oneToThree
        case 4...7: .fourToSeven
        case 8...12: .eightToTwelve
        case 13...19: .thirteenToNineteen
        default: .twentyOrMore
        }
    }

    public static func countLevel(for value: Int) -> CountBucket {
        countBucket(for: value)
    }

    public static func intensityLevel(for value: Int) -> IntensitySumBucket {
        intensitySumBucket(for: value)
    }
}
