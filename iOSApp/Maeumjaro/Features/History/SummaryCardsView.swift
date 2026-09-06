import SwiftUI
import MaeumjaroDomain

struct SummaryCardsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let report: AnalyticsReport
    let palette: ThemePalette
    var body: some View {
        let today = report.daily[report.period.todayDate]
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: DesignTokens.spacing3) {
                card(String(localized: "오늘 기록"), String(localized: "\(today?.count ?? 0)회"), String(localized: "오늘 완료한 기록 수"))
                card(String(localized: "오늘 강도 합"), String(localized: "\(today?.intensitySum ?? 0)"), String(localized: "오늘 강도의 합"))
                card(String(localized: "활동일 평균"), String(localized: "\(report.activeDayAverage, specifier: "%.1f")회"), String(localized: "기록이 있는 날의 평균"))
            }
        } else { ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: DesignTokens.spacing3) {
                card(String(localized: "오늘 기록"), String(localized: "\(today?.count ?? 0)회"), String(localized: "오늘 완료한 기록 수"))
                card(String(localized: "오늘 강도 합"), String(localized: "\(today?.intensitySum ?? 0)"), String(localized: "오늘 강도의 합"))
                card(String(localized: "활동일 평균"), String(localized: "\(report.activeDayAverage, specifier: "%.1f")회"), String(localized: "기록이 있는 날의 평균"))
            }
            VStack(spacing: DesignTokens.spacing3) {
                card(String(localized: "오늘 기록"), String(localized: "\(today?.count ?? 0)회"), String(localized: "오늘 완료한 기록 수"))
                card(String(localized: "오늘 강도 합"), String(localized: "\(today?.intensitySum ?? 0)"), String(localized: "오늘 강도의 합"))
                card(String(localized: "활동일 평균"), String(localized: "\(report.activeDayAverage, specifier: "%.1f")회"), String(localized: "기록이 있는 날의 평균"))
            }
        } }
    }
    private func card(_ title: String, _ value: String, _ hint: String) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(DesignTokens.font(for: .secondary)).foregroundStyle(palette.secondaryInk.color); Text(value).font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(palette.surface.color).clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)).overlay(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius).stroke(palette.border.color)).accessibilityElement(children: .combine).accessibilityLabel(title).accessibilityValue(value).accessibilityHint(hint) }
}
