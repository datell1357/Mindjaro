import SwiftUI
import MaeumjaroDomain

struct HeatmapGrid: View {
    let report: AnalyticsReport
    let metric: HeatmapMetric
    let palette: ThemePalette
    let plan: HistoryPlan
    let onSelect: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if plan == .pro {
                GeometryReader { geometry in
                    let gap: CGFloat = 4
                    let columnWidth = max(12, (geometry.size.width - (15 * gap)) / 16)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .bottom, spacing: gap) {
                                ForEach(Array(report.period.dates.chunked(into: 7).enumerated()), id: \.offset) { index, week in
                                    VStack(spacing: 2) { ForEach(week, id: \.self) { compactCell(for: $0, width: columnWidth) } }.frame(width: columnWidth).id(index)
                                }
                            }
                        }.onAppear { proxy.scrollTo(max(0, report.period.dates.chunked(into: 7).count - 16), anchor: .leading) }
                    }
                }.frame(height: 7 * 18 + 6 * 2)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 4) { ForEach(report.period.dates, id: \.self) { date in cell(for: date) } }
                }.accessibilityLabel("날짜별 상세 선택")
            } else {
                Text("최근 30일").font(DesignTokens.font(for: .sectionTitle))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        VStack(spacing: 4) {
                            ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { weekday in
                                Text(weekday).font(.caption).foregroundStyle(palette.secondaryInk.color)
                                    .frame(width: 20, height: 44)
                            }
                        }.accessibilityHidden(true)
                        let dates = Self.weekAlignedDates(report.period.dates)
                        ForEach(Array(dates.chunked(into: 7).enumerated()), id: \.offset) { _, week in
                            VStack(spacing: 4) {
                                ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                                    if let date { cell(for: date).accessibilityAddTraits(.isButton) }
                                    else { Color.clear.frame(width: 44, height: 44).accessibilityHidden(true) }
                                }
                            }
                        }
                    }
                }.accessibilityIdentifier("free-history-grid")
            }
        }.padding(.vertical, 8).frame(minHeight: 44).accessibilityLabel(metric == .count ? "기록 수 히트맵" : "강도 합 히트맵")
    }
    nonisolated static func weekAlignedDates(_ dates: [String]) -> [String?] {
        guard let first = dates.first.flatMap({ AnalyticsDate($0) }) else { return [] }
        let leading = first.weekdayIndexMondayFirst
        let trailing = (7 - (leading + dates.count) % 7) % 7
        return Array(repeating: nil, count: leading) + dates.map(Optional.some) + Array(repeating: nil, count: trailing)
    }
    @ViewBuilder private func cell(for date: String) -> some View { let day = report.daily[date] ?? DailyAnalytics(localDate: date, count: 0, intensitySum: 0); Button { onSelect(date) } label: { ZStack { Color.clear; RoundedRectangle(cornerRadius: 4).fill(palette.accent.color.opacity(opacity(day))).frame(width: 18, height: 18).overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border.color)) }.frame(width: 44, height: 44) }.accessibilityElement(children: .ignore).accessibilityLabel(date).accessibilityValue(String(localized: "\(day.count)회, 강도 합 \(day.intensitySum)")).accessibilityHint(String(localized: "날짜 상세 보기")) }
    @ViewBuilder private func compactCell(for date: String, width: CGFloat) -> some View { let day = report.daily[date] ?? DailyAnalytics(localDate: date, count: 0, intensitySum: 0); RoundedRectangle(cornerRadius: 2).fill(palette.accent.color.opacity(opacity(day))).frame(width: width, height: 18).overlay(RoundedRectangle(cornerRadius: 2).stroke(palette.border.color)) }
    private func opacity(_ day: DailyAnalytics) -> Double { let value = metric == .count ? day.count : day.intensitySum; return value == 0 ? 0.12 : min(1, 0.25 + Double(value) / 10) }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] { stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) } }
}
