public enum ThemeID: String, Codable, CaseIterable, Hashable, Sendable {
    case quietIvory
    case midnightInk
    case forestMist

    public static let `default` = Self.quietIvory
}

