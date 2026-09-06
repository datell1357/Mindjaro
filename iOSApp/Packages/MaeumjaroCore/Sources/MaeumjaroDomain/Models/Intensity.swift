import Foundation

public struct Intensity: RawRepresentable, Codable, Hashable, Comparable, CaseIterable, Sendable {
    public static let minimumRawValue = 1
    public static let maximumRawValue = 5

    public let rawValue: Int

    public init?(rawValue: Int) {
        guard (Self.minimumRawValue...Self.maximumRawValue).contains(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public static let one = Intensity(rawValue: 1)!
    public static let two = Intensity(rawValue: 2)!
    public static let three = Intensity(rawValue: 3)!
    public static let four = Intensity(rawValue: 4)!
    public static let five = Intensity(rawValue: 5)!
    public static let `default` = three

    public static let allCases: [Intensity] = [.one, .two, .three, .four, .five]

    public static func < (lhs: Intensity, rhs: Intensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard let intensity = Intensity(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Intensity must be an integer in 1...5."
            )
        }
        self = intensity
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
