import SwiftUI
import Charts
import MaeumjaroDomain

struct SettingsView: View {
    @State private var model: SettingsViewModel
    @State private var historyModel: HistoryViewModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let onPro: () -> Void
    let onDataManagement: () -> Void
    let onWidgetHelp: () -> Void
    let onSafety: () -> Void

    init(model: SettingsViewModel, historyModel: HistoryViewModel, onPro: @escaping () -> Void = {}, onDataManagement: @escaping () -> Void = {}, onWidgetHelp: @escaping () -> Void = {}, onSafety: @escaping () -> Void = {}) {
        _model = State(initialValue: model); _historyModel = State(initialValue: historyModel); self.onPro = onPro; self.onDataManagement = onDataManagement; self.onWidgetHelp = onWidgetHelp; self.onSafety = onSafety
    }

    var body: some View {
        let palette = ThemePalette.palette(for: model.settings.themeID, colorScheme: colorScheme, contrast: colorSchemeContrast)
        Form {
            Section {
                if historyModel.isLoading {
                    ProgressView("기록 불러오는 중")
                } else if let error = historyModel.errorMessage {
                    Text(error)
                    Button("다시 시도") { Task { await historyModel.load() } }
                } else if let report = historyModel.report {
                    SettingsHistoryChart(report: report, palette: palette)
                }
            } header: { Text("최근 7일 기록").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            Section {
                ForEach(Intensity.allCases, id: \.self) { intensity in
                    Button { Task { await model.setIntensity(intensity) } } label: {
                        HStack { Text("강도 \(intensity.rawValue)"); Spacer(); if model.selectedIntensity == intensity { Image(systemName: "checkmark") } }
                    }.frame(minHeight: DesignTokens.minimumTouchTarget).accessibilityIdentifier("settings-intensity-\(intensity.rawValue)")
                }
            } header: { Text("기본 강도").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            Section {
                Toggle("햅틱", isOn: binding(get: { model.settings.hapticsEnabled }, set: { value in Task { await model.setHapticsEnabled(value) } })).accessibilityIdentifier("settings-haptics-toggle")
                Toggle("소리", isOn: binding(get: { model.settings.soundEnabled }, set: { value in Task { await model.setSoundEnabled(value) } }))
                Toggle("앱 동작 줄이기", isOn: binding(get: { model.settings.reducedMotionEnabled }, set: { value in Task { await model.setReducedMotionEnabled(value) } }))
                LabeledContent("시스템 동작 줄이기", value: systemReduceMotion ? "켬" : "꺼짐")
                Picker("문구 톤", selection: binding(get: { model.settings.phraseTonePreference }, set: { value in Task { await model.setPhraseTonePreference(value) } })) {
                    Text("자동").tag(PhraseTonePreference.automatic); Text("부드럽게").tag(PhraseTonePreference.gentle); Text("중립").tag(PhraseTonePreference.neutral); Text("단호하게").tag(PhraseTonePreference.firm)
                }
            } header: { Text("피드백").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            Section {
                Button("위젯 도움말", action: onWidgetHelp).frame(minHeight: DesignTokens.minimumTouchTarget)
                Button("안전 안내", action: onSafety).frame(minHeight: DesignTokens.minimumTouchTarget)
            } header: { Text("도움말").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            Section {
                Button("Pro 기능 보기", action: onPro).frame(minHeight: DesignTokens.minimumTouchTarget)
                Button("데이터 관리", action: onDataManagement).frame(minHeight: DesignTokens.minimumTouchTarget)
            } header: { Text("마음자로").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            if let error = model.errorMessage { Section { Text(error).foregroundStyle(.red).accessibilityLabel(String(localized: "설정 오류: \(error)")) } }
        }.navigationTitle("설정").toolbarTitleDisplayMode(.inline)
            .foregroundStyle(palette.ink.color)
            .tint(palette.accent.color)
            .scrollContentBackground(.hidden)
            .background(palette.background.color.ignoresSafeArea())
            .task { model.refreshIntensity(); await historyModel.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.refreshIntensity(); Task { await historyModel.load() } }
            }
    }

    private func binding<Value>(get: @escaping @MainActor @Sendable () -> Value, set: @escaping @MainActor @Sendable (Value) -> Void) -> Binding<Value> { Binding(get: get, set: set) }
}

struct SettingsHistoryChart: View {
    let report: AnalyticsReport
    let palette: ThemePalette

    /// Use the same persisted local-day buckets as History, including zero days.
    static func days(in report: AnalyticsReport) -> [DailyAnalytics] {
        report.period.dates.suffix(7).map { date in
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
                .accessibilityIdentifier("settings-weekly-total")
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
            .accessibilityIdentifier("settings-weekly-chart")
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
