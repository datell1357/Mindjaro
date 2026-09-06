import SwiftUI
import Charts
import MaeumjaroDomain

struct DistributionChart: View {
    let title: String
    let values: [Int]
    let palette: ThemePalette
    var body: some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color); Chart(Array(values.enumerated()), id: \.offset) { item in BarMark(x: .value(String(localized: "구간"), domainLabel(item.offset)), y: .value(String(localized: "기록 수"), item.element)).foregroundStyle(palette.accent.color) }.chartXAxis { AxisMarks { value in AxisValueLabel() } }.frame(height: 150).accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityValue(values.enumerated().map { String(localized: "\(domainLabel($0.offset)) \($0.element)회") }.joined(separator: ", ")).accessibilityHint(String(localized: "도메인 집계 결과")) } }
    private func domainLabel(_ index: Int) -> String { switch title { case "시간대 분포": return String(localized: "\(index * 3)–\(index * 3 + 2)시"); case "요일 분포": return [String(localized: "월"), String(localized: "화"), String(localized: "수"), String(localized: "목"), String(localized: "금"), String(localized: "토"), String(localized: "일")][safe: index] ?? String(localized: "구간 \(index + 1)"); case "강도 분포": return String(localized: "강도 \(index + 1)"); default: return String(localized: "구간 \(index + 1)") } }
}

private extension Array { subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil } }
