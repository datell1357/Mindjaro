import CoreTransferable
import Foundation
import UniformTypeIdentifiers

public struct ExportDocument: Transferable, Sendable, Equatable, Identifiable {
    public enum Format: String, CaseIterable, Sendable {
        case csv
        case json

        public var contentType: UTType {
            self == .csv ? .commaSeparatedText : .json
        }
    }

    public let format: Format
    public let filename: String
    public let data: Data

    public var id: String { filename }

    public init(format: Format, data: Data, filename: String? = nil) {
        self.format = format
        self.data = data
        self.filename = filename ?? "maeumjaro-history.\(format.rawValue)"
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            document.data
        }
        .suggestedFileName { document in
            document.filename
        }
        .exportingCondition { document in
            document.format == .csv
        }

        DataRepresentation(exportedContentType: .json) { document in
            document.data
        }
        .suggestedFileName { document in
            document.filename
        }
        .exportingCondition { document in
            document.format == .json
        }
    }
}
