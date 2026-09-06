import SwiftUI
import MaeumjaroDomain

struct AdvancedAnalyticsView: View {
    let report: AnalyticsReport
    let palette: ThemePalette
    var body: some View { VStack(alignment: .leading, spacing: 20) { Text("상세 패턴").font(DesignTokens.font(for: .sectionTitle)); DistributionChart(title: String(localized: "시간대 분포"), values: report.threeHourCounts, palette: palette); DistributionChart(title: String(localized: "요일 분포"), values: report.weekdayCounts, palette: palette); DistributionChart(title: String(localized: "강도 분포"), values: report.intensityCounts, palette: palette); if let comparison = report.comparison { Text(String(localized: "최근 4주 \(comparison.recent.count)회 · 이전 4주 \(comparison.previous.count)회")).font(DesignTokens.font(for: .body)).accessibilityLabel(String(localized: "기간 비교")).accessibilityValue(String(localized: "최근 \(comparison.recent.count)회, 이전 \(comparison.previous.count)회")) } }.foregroundStyle(palette.ink.color) }
}
