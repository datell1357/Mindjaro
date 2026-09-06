import MaeumjaroDomain

enum AppRoute: Hashable, Sendable {
    case ritual(source: EventSource)
    case widgetHelp
    case safetyNotice
}
