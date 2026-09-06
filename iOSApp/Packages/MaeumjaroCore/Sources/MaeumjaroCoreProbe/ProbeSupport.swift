import Foundation

enum ProbeJSONKey {
    static let error = "error"
}

struct ProbeArguments: Sendable {
    let command: String
    let options: [String: String]
    let flags: Set<String>

    private static let knownOptions: [String: Set<String>] = [
        "contracts": ["intensity"],
        "ritual": ["intensity", "actions"],
        "phrases": ["intensity", "tone", "seed", "fixture", "history"],
        "analytics": ["fixture", "access"],
        "persistence": ["store", "scenario"],
        "shared": ["suite", "writes", "read", "fixture"],
        "intent": ["current", "delta", "target", "revision", "fixture"]
    ]

    private static let knownFlags: Set<String> = ["trace", "fail-write"]
    private static let allowedFlags: [String: Set<String>] = [
        "contracts": [],
        "ritual": [],
        "phrases": [],
        "analytics": [],
        "persistence": [],
        "shared": [],
        "intent": ["trace", "fail-write"]
    ]

    init(_ arguments: [String]) throws {
        guard let command = arguments.first, !command.hasPrefix("-") else {
            throw ProbeCommandError.invalidArguments(command: "unknown", detail: "missing-command")
        }

        var parsed: [String: String] = [:]
        var parsedFlags: Set<String> = []
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else {
                throw ProbeCommandError.invalidArguments(command: command, detail: "unexpected-argument")
            }

            let body = String(argument.dropFirst(2))
            guard !body.isEmpty else {
                throw ProbeCommandError.invalidArguments(command: command, detail: "empty-option")
            }

            if let separator = body.firstIndex(of: "=") {
                let key = String(body[..<separator])
                let value = String(body[body.index(after: separator)...])
                guard !key.isEmpty, !value.isEmpty, parsed[key] == nil else {
                    throw ProbeCommandError.invalidArguments(command: command, detail: "invalid-option")
                }
                parsed[key] = value
                index += 1
            } else {
                if Self.knownFlags.contains(body) {
                    guard parsedFlags.insert(body).inserted else {
                        throw ProbeCommandError.invalidArguments(command: command, detail: "invalid-option")
                    }
                    index += 1
                    continue
                }
                guard index + 1 < arguments.count else {
                    throw ProbeCommandError.invalidArguments(command: command, detail: "missing-option-value")
                }
                let key = body
                let value = arguments[index + 1]
                guard !value.hasPrefix("--"), parsed[key] == nil else {
                    throw ProbeCommandError.invalidArguments(command: command, detail: "invalid-option")
                }
                parsed[key] = value
                index += 2
            }
        }

        guard let allowedOptions = Self.knownOptions[command] else {
            throw ProbeCommandError.invalidArguments(command: command, detail: "unknown-command")
        }
        guard parsed.keys.allSatisfy({ allowedOptions.contains($0) }),
              parsedFlags.isSubset(of: Self.allowedFlags[command, default: []]) else {
            throw ProbeCommandError.invalidArguments(command: command, detail: "unsupported-option")
        }

        self.command = command
        self.options = parsed
        self.flags = parsedFlags
    }

    func value(for key: String) -> String? {
        options[key]
    }

    func hasFlag(_ key: String) -> Bool {
        flags.contains(key)
    }
}

indirect enum ProbeJSONValue: Encodable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case null
    case array([ProbeJSONValue])
    case object([String: ProbeJSONValue])

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .integer(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .boolean(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case let .object(values):
            var container = encoder.container(keyedBy: ProbeCodingKey.self)
            for key in values.keys.sorted() {
                guard let value = values[key] else { continue }
                try container.encode(value, forKey: ProbeCodingKey(key))
            }
        }
    }
}

struct ProbeCodingKey: CodingKey {
    let stringValue: String

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    var intValue: Int?

    init?(intValue: Int) {
        return nil
    }
}

struct ProbeResponse: Encodable, Sendable {
    let command: String
    let status: String
    let data: [String: ProbeJSONValue]
}

enum ProbeCommandError: Error, Sendable {
    case invalidArguments(command: String, detail: String)
    case invalidIntensity(value: String)
    case notImplemented(command: String)

    var response: ProbeResponse {
        switch self {
        case let .invalidArguments(command, detail):
            return ProbeResponse(
                command: command,
                status: "error",
                data: [ProbeJSONKey.error: .string(detail)]
            )
        case let .invalidIntensity(value):
            return ProbeResponse(
                command: "contracts",
                status: "error",
                data: [
                    ProbeJSONKey.error: .string("invalid-intensity"),
                    "value": .string(value)
                ]
            )
        case let .notImplemented(command):
            return ProbeResponse(
                command: command,
                status: "notImplemented",
                data: [ProbeJSONKey.error: .string("not-implemented")]
            )
        }
    }
}

enum ProbeSupport {
    static let helpText = """
    MaeumjaroCoreProbe <command> [options]
    commands: contracts, ritual, phrases, analytics, persistence, shared, intent
    contracts options: --intensity <comma-separated raw values>
    """

    static func print(_ response: ProbeResponse) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(response)
        Swift.print(String(decoding: data, as: UTF8.self))
    }
}
