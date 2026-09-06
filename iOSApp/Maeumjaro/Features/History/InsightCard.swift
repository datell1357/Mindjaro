import SwiftUI
import MaeumjaroDomain

struct InsightCard: View {
    let tier: SampleTier
    let palette: ThemePalette
    var body: some View { let text: String = switch tier { case .insufficient: String(localized: "조금 더 기록하면 패턴을 확인할 수 있어요."); case .facts: String(localized: "현재까지의 기록을 사실 그대로 보여드려요."); case .patterns: String(localized: "기록 분포에서 반복되는 패턴을 살펴볼 수 있어요."); case .comparison: String(localized: "최근 기간과 이전 기간을 비교해 볼 수 있어요.") }; return Text(text).font(DesignTokens.font(for: .body)).foregroundStyle(palette.ink.color).frame(maxWidth: .infinity, alignment: .leading).padding(16).background(palette.surface.color).clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)).overlay(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius).stroke(palette.border.color)).accessibilityLabel(String(localized: "분석 안내")).accessibilityValue(text) }
}
