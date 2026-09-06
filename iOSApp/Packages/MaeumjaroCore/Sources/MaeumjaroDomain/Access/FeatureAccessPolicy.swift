public enum Entitlement: String, Codable, CaseIterable, Hashable, Sendable {
    case free
    case pending
    case loading
    case error
    case unverified
    case revoked
    case pro
}

public enum FeatureAccess: String, Codable, CaseIterable, Hashable, Sendable {
    case todaySummary
    case recentRecords
    case basicHistory
    case heatmap
    case detailedPatterns
    case comparison
    case csvExport
    case jsonExport
    case themes
}

public struct FeatureAccessPolicy: Equatable, Hashable, Sendable {
    public let entitlement: Entitlement

    public init(entitlement: Entitlement) {
        self.entitlement = entitlement
    }

    public var isPro: Bool { entitlement == .pro }

    public func canAccess(_ feature: FeatureAccess) -> Bool {
        guard isPro else {
            switch feature {
            case .todaySummary, .recentRecords, .basicHistory:
                return true
            case .heatmap, .detailedPatterns, .comparison, .csvExport, .jsonExport, .themes:
                return false
            }
        }
        return true
    }

    public func historyWindow(today: String) -> HistoryWindow? {
        isPro ? .pro(today: today) : .free(today: today)
    }

    public func canViewHistory(today: String) -> Bool {
        historyWindow(today: today) != nil
    }
}
