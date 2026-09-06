import SwiftUI
import MaeumjaroDomain

struct DailyDetailSheet: View {
    let date: String
    let report: AnalyticsReport
    let events: [InjectionEvent]
    let palette: ThemePalette
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: InjectionEvent?
    var body: some View { let day = report.daily[date] ?? DailyAnalytics(localDate: date, count: 0, intensitySum: 0); NavigationStack { List { Section("요약") { LabeledContent("기록", value: "\(day.count)회"); LabeledContent("강도 합", value: "\(day.intensitySum)") }.listRowBackground(palette.surface.color); Section("기록") { ForEach(events.filter { $0.eventLocalDate == date }, id: \.id) { event in HStack { Text("강도 \(event.intensity.rawValue)").foregroundStyle(palette.ink.color); Spacer(); Menu { Button("삭제", role: .destructive) { pendingDelete = event } } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("기록 메뉴").tint(palette.accent.color) } }.listRowBackground(palette.surface.color) } }.scrollContentBackground(.hidden).background(palette.background.color).foregroundStyle(palette.ink.color).navigationTitle(date).toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() }.tint(palette.accent.color) } }.alert("기록을 삭제할까요?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) { Button("취소", role: .cancel) { pendingDelete = nil }; Button("삭제", role: .destructive) { if let id = pendingDelete?.id { onDelete(id) }; pendingDelete = nil; dismiss() } } message: { Text("선택한 기록만 삭제됩니다.") } } }
}
