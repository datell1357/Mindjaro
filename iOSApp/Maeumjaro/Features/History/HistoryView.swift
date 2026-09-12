import SwiftUI
import Charts
import MaeumjaroDomain

struct HistoryView: View {
    @State private var model: HistoryViewModel
    let palette: ThemePalette

    init(viewModel: HistoryViewModel, palette: ThemePalette = .quietIvory) {
        _model = State(initialValue: viewModel)
        self.palette = palette
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing6) {
                    Text("기록").font(DesignTokens.font(for: .screenTitle)).accessibilityAddTraits(.isHeader)
                    if model.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let error = model.errorMessage {
                        Text(error).font(DesignTokens.font(for: .body))
                        Button("다시 시도") { Task { await model.load() } }.frame(minHeight: 44)
                    } else if let report = model.report {
                        reportContent(report)
                    } else {
                        Text("아직 기록이 없어요. 오늘의 작은 선택을 남겨 보세요.")
                            .font(DesignTokens.font(for: .body)).padding(20)
                    }
                }
                .padding(DesignTokens.spacing6)
            }
            .foregroundStyle(palette.ink.color)
            .tint(palette.accent.color)
            .background(palette.background.color.ignoresSafeArea())
            .navigationTitle("기록")
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.load() }
            .sheet(item: Binding(get: { model.selectedDate.map(HistoryDate.init) }, set: { model.selectedDate = $0?.value })) { item in
                if let report = model.report {
                    DailyDetailSheet(date: item.value, report: report, events: model.events, palette: palette) { id in
                        Task { await model.delete(id: id) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func reportContent(_ report: AnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
            Text("최근 7일 기록").font(DesignTokens.font(for: .sectionTitle)).accessibilityAddTraits(.isHeader)
            WeeklyHistoryChart(report: report, palette: palette)
        }
        .padding(DesignTokens.spacing5)
        .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
        SummaryCardsView(report: report, palette: palette)
        RecentEventsView(events: model.recentEvents, palette: palette) { model.selectedDate = $0 }
        if model.policy.canAccess(.heatmap) {
            Picker("표시", selection: $model.metric) {
                Text("횟수").tag(HeatmapMetric.count)
                Text("강도 합").tag(HeatmapMetric.intensitySum)
            }
            .pickerStyle(.segmented).accessibilityLabel("히트맵 표시")
            HeatmapGrid(report: report, metric: model.metric, palette: palette, plan: report.period.plan) { model.selectedDate = $0 }
        } else {
            FreeDailyListView(report: report, palette: palette) { model.selectedDate = $0 }
        }
        if model.policy.isPro {
            AdvancedAnalyticsView(report: report, palette: palette)
        } else {
            Text("Pro에서 52주 기록과 상세 패턴을 확인할 수 있어요.")
                .font(DesignTokens.font(for: .body))
                .padding(16).background(palette.surface.color)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
                .accessibilityLabel("상세 패턴 잠금")
                .accessibilityValue("Pro에서 52주 기록과 상세 패턴을 확인할 수 있음")
        }
        InsightCard(tier: report.sampleTier, palette: palette)
    }
}
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

struct WeeklyHistoryChart: View {
    let report: AnalyticsReport
    let palette: ThemePalette

    /// Use the same persisted local-day buckets as History, including zero days.
    static func days(in report: AnalyticsReport) -> [DailyAnalytics] {
        report.period.dates.filter { $0 <= report.period.todayDate }.suffix(7).map { date in
            report.daily[date] ?? DailyAnalytics(localDate: date, count: 0, intensitySum: 0)
        }
    }

    var body: some View {
        let days = Self.days(in: report)
        let total = days.reduce(0) { $0 + $1.count }
        let maximum = max(2, days.map(\.count).max() ?? 0)
        VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
            Text("총 \(total)회")
                .font(DesignTokens.font(for: .screenTitle))
                .accessibilityIdentifier("history-weekly-total")
            Chart(days, id: \.localDate) { day in
                BarMark(x: .value("날짜", shortDate(day.localDate)), y: .value("완료 횟수", day.count))
                    .foregroundStyle(palette.accent.color)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text("\(day.count)")
                            .font(.caption)
                            .foregroundStyle(palette.ink.color)
                    }
            }
            .chartYScale(domain: 0...maximum)
            .chartYAxis {
                AxisMarks(values: [0, (maximum + 1) / 2, maximum]) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("최근 7일 완료 횟수")
            .accessibilityValue(days.map { String(localized: "\($0.localDate) \($0.count)회") }.joined(separator: ", "))
            .accessibilityIdentifier("history-weekly-chart")
            Text(total == 0 ? "아직 최근 7일 기록이 없어요. 마음 정리를 마치면 여기에 표시돼요." : "오늘을 포함한 최근 7일의 완료 횟수예요.")
                .font(DesignTokens.font(for: .secondary))
                .foregroundStyle(palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.spacing2)
    }

    private func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return date }
        return "\(month)/\(day)"
    }
}
