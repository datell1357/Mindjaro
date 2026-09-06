import Foundation
import MaeumjaroDomain

public struct HistoryExporter: Sendable {
    public static let fields = [
        "completedAtUTC", "eventLocalDate", "timezoneOffsetMinutes",
        "intensity", "source", "phraseID"
    ]

    public init() {}

    public func export(_ events: [InjectionEvent], format: ExportDocument.Format) -> ExportDocument? {
        guard !events.isEmpty else { return nil }
        switch format {
        case .csv:
            return ExportDocument(format: .csv, data: csvData(events), filename: "maeumjaro-history.csv")
        case .json:
            return ExportDocument(format: .json, data: jsonData(events), filename: "maeumjaro-history.json")
        }
    }

    private func csvData(_ events: [InjectionEvent]) -> Data {
        let rows = events.map { event in
            [
                ISO8601DateFormatter().string(from: event.completedAtUTC), event.eventLocalDate,
                String(event.timezoneOffsetMinutes), String(event.intensity.rawValue),
                event.source.rawValue, event.phraseID
            ]
        }
        let header = Self.fields.joined(separator: ",")
        let body = rows.map { $0.map(Self.quote).joined(separator: ",") }.joined(separator: "\r\n")
        // Emit the UTF-8 BOM as bytes so consumers can recognize the CSV
        // without relying on Foundation's String decoding behavior.
        return Data([0xEF, 0xBB, 0xBF]) + Data("\(header)\r\n\(body)\r\n".utf8)
    }

    private func jsonData(_ events: [InjectionEvent]) -> Data {
        let values: [[String: Any]] = events.map { event in
            [
                "completedAtUTC": ISO8601DateFormatter().string(from: event.completedAtUTC),
                "eventLocalDate": event.eventLocalDate,
                "timezoneOffsetMinutes": event.timezoneOffsetMinutes,
                "intensity": event.intensity.rawValue,
                "source": event.source.rawValue,
                "phraseID": event.phraseID
            ]
        }
        let payload: [String: Any] = ["schemaVersion": 1, "fields": Self.fields, "events": values]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    }

    private static func quote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
