import SwiftUI
import MaeumjaroDomain

struct RecentEventsView: View {
    let events: [InjectionEvent]
    let palette: ThemePalette
    let onSelect: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 기록").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color)
            if events.isEmpty { Text("아직 기록이 없어요. 오늘의 작은 선택을 남겨 보세요.").font(DesignTokens.font(for: .body)).foregroundStyle(palette.secondaryInk.color).padding(.vertical, 12) }
            ForEach(events, id: \.id) { event in Button { onSelect(event.eventLocalDate) } label: { HStack { Text(event.eventLocalDate).font(DesignTokens.font(for: .body)); Spacer(); Text(String(localized: "강도 \(event.intensity.rawValue)")).font(DesignTokens.font(for: .secondary)) }.foregroundStyle(palette.ink.color).frame(minHeight: 44).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel(event.eventLocalDate).accessibilityValue(String(localized: "강도 \(event.intensity.rawValue)")).accessibilityHint(String(localized: "날짜 상세 보기")) }
        }
    }
}
