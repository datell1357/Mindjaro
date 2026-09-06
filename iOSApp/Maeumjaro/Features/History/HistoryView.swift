import SwiftUI
import MaeumjaroDomain

struct HistoryView: View {
    @State private var model: HistoryViewModel
    let palette: ThemePalette
    init(viewModel: HistoryViewModel, palette: ThemePalette = .quietIvory) { _model = State(initialValue: viewModel); self.palette = palette }
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 24) { Text("기록").font(DesignTokens.font(for: .screenTitle)); if model.isLoading { ProgressView().frame(maxWidth: .infinity) } else if let error = model.errorMessage { Text(error).font(DesignTokens.font(for: .body)); Button("다시 시도") { Task { await model.load() } }.frame(minWidth: 44, minHeight: 44) } else if let report = model.report { SummaryCardsView(report: report, palette: palette); RecentEventsView(events: model.recentEvents, palette: palette) { model.selectedDate = $0 }; if model.policy.canAccess(.heatmap) { Picker("표시", selection: $model.metric) { Text("횟수").tag(HeatmapMetric.count); Text("강도 합").tag(HeatmapMetric.intensitySum) }.pickerStyle(.segmented).accessibilityLabel("히트맵 표시"); HeatmapGrid(report: report, metric: model.metric, palette: palette, plan: report.period.plan) { model.selectedDate = $0 } } else { FreeDailyListView(report: report, palette: palette) { model.selectedDate = $0 } }; if model.policy.isPro { AdvancedAnalyticsView(report: report, palette: palette) } else { Text("Pro에서 52주 기록과 상세 패턴을 확인할 수 있어요.").font(DesignTokens.font(for: .body)).foregroundStyle(palette.ink.color).padding(16).background(palette.surface.color).clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)).accessibilityLabel("상세 패턴 잠금").accessibilityValue("Pro에서 52주 기록과 상세 패턴을 확인할 수 있음") }; InsightCard(tier: report.sampleTier, palette: palette) } else { Text("아직 기록이 없어요. 오늘의 작은 선택을 남겨 보세요.").font(DesignTokens.font(for: .body)).foregroundStyle(palette.ink.color).padding(20) } }.padding(20) }.foregroundStyle(palette.ink.color).tint(palette.accent.color).background(palette.background.color.ignoresSafeArea()).task { await model.load() }.sheet(item: Binding(get: { model.selectedDate.map(HistoryDate.init) }, set: { model.selectedDate = $0?.value })) { item in if let report = model.report { DailyDetailSheet(date: item.value, report: report, events: model.events, palette: palette) { id in Task { await model.delete(id: id) } } } } }.navigationTitle("기록").toolbarTitleDisplayMode(.inline) } }
private struct HistoryDate: Identifiable { let value: String; var id: String { value } }

private struct FreeDailyListView: View {
    let report: AnalyticsReport
    let palette: ThemePalette
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 30일").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color)
            ForEach(report.period.dates.reversed(), id: \.self) { date in
                let day = report.daily[date] ?? DailyAnalytics(localDate: date, count: 0, intensitySum: 0)
                Button { onSelect(date) } label: {
                    HStack {
                        Text(date).font(DesignTokens.font(for: .body))
                        Spacer()
                        Text("\(day.count)회").font(DesignTokens.font(for: .secondary))
                    }
                    .foregroundStyle(palette.ink.color)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(date)
                .accessibilityValue(String(localized: "\(day.count)회"))
                .accessibilityHint("날짜 상세 보기")
            }
        }
    }
}
