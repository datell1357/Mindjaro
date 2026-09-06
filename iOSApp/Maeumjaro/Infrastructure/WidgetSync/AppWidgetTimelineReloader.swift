import WidgetKit

protocol WidgetTimelineReloader: Sendable {
    func reloadTimelines(ofKind kind: String)
}

struct AppWidgetTimelineReloader: WidgetTimelineReloader {
    func reloadTimelines(ofKind kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
