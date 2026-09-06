import Foundation
import MaeumjaroDomain
import MaeumjaroShared
import WidgetKit

struct MaeumjaroTimelineEntry: TimelineEntry {
    let date: Date
    let strength: Intensity
    let today: TodaySummarySnapshot
    let theme: ThemeID
    let isPlaceholder: Bool
    var palette: ThemePalette { ThemePalette.palette(for: theme) }
}
