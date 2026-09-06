import Foundation
import MaeumjaroDomain

struct HistoryAccessibilityItem: Equatable, Codable, Sendable {
    let label: String
    let value: String
    let hint: String
}

struct HistoryAccessibilityContent: Equatable, Codable, Sendable {
    let summary: [HistoryAccessibilityItem]
    let dates: [HistoryAccessibilityItem]
    let heatmap: [HistoryAccessibilityItem]
    let charts: [HistoryAccessibilityItem]
    let detail: [HistoryAccessibilityItem]

    static func make(report: AnalyticsReport, selectedDate: String? = nil) -> Self {
        let summary = [
            HistoryAccessibilityItem(label: String(localized: "오늘 기록"), value: String(localized: "\(report.daily[report.period.todayDate]?.count ?? 0)회"), hint: String(localized: "오늘 완료한 기록 수")),
            HistoryAccessibilityItem(label: String(localized: "오늘 강도 합"), value: String(localized: "\(report.daily[report.period.todayDate]?.intensitySum ?? 0)"), hint: String(localized: "오늘 강도의 합")),
            HistoryAccessibilityItem(label: String(localized: "활동일 평균"), value: String(localized: "\(report.activeDayAverage, specifier: "%.1f")회"), hint: String(localized: "기록이 있는 날의 평균"))
        ]
        let dates = report.period.dates.map { date in
            let day = report.daily[date] ?? DailyAnalytics(localDate: date, count: 0, intensitySum: 0)
            return HistoryAccessibilityItem(label: date, value: String(localized: "\(day.count)회, 강도 합 \(day.intensitySum)"), hint: String(localized: "날짜 상세 보기"))
        }
        let detail: [HistoryAccessibilityItem] = selectedDate.flatMap { date in
            guard let day = report.daily[date] else { return nil }
            return [HistoryAccessibilityItem(label: String(localized: "\(date) 상세"), value: String(localized: "\(day.count)회, 강도 합 \(day.intensitySum)"), hint: String(localized: "기록 메뉴에서 삭제할 수 있음"))]
        } ?? []
        return Self(summary: summary, dates: dates, heatmap: dates, charts: [
            HistoryAccessibilityItem(label: String(localized: "시간대 분포"), value: report.threeHourCounts.map(String.init).joined(separator: ", "), hint: String(localized: "3시간 단위 기록 수")),
            HistoryAccessibilityItem(label: String(localized: "요일 분포"), value: report.weekdayCounts.map(String.init).joined(separator: ", "), hint: String(localized: "월요일부터 일요일 순서")),
            HistoryAccessibilityItem(label: String(localized: "강도 분포"), value: report.intensityCounts.map(String.init).joined(separator: ", "), hint: String(localized: "강도 1부터 5 순서"))
        ], detail: detail)
    }
}
