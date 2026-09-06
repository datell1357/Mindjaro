import Foundation
import MaeumjaroDomain

public enum MaeumjaroDeepLinkRoute: Equatable, Sendable {
    case inject(source: EventSource)

    public var source: EventSource {
        switch self {
        case let .inject(source):
            return source
        }
    }
}

public enum MaeumjaroDeepLink {
    public static func parse(_ url: URL) -> MaeumjaroDeepLinkRoute? {
        guard url.scheme == AppIdentifiers.urlScheme,
              url.host == "inject",
              url.path.isEmpty,
              url.fragment == nil,
              url.user == nil,
              url.password == nil,
              url.port == nil,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return nil
        }

        var sourceValues: [String] = []
        for item in queryItems {
            switch item.name {
            case "source":
                guard let value = item.value else { return nil }
                sourceValues.append(value)
            case "intensity":
                continue
            default:
                return nil
            }
        }
        guard sourceValues.count == 1, let source = EventSource(rawValue: sourceValues[0]) else {
            return nil
        }
        return .inject(source: source)
    }

    public static func route(for url: URL) -> MaeumjaroDeepLinkRoute? {
        parse(url)
    }
}
