import Foundation
import Testing

import MaeumjaroDomain

@Test
func intensityAcceptsOnlyTheClosedOneThroughFiveRange() {
    let accepted = (1...5).compactMap(Intensity.init(rawValue:)).map(\.rawValue)

    #expect(accepted == [1, 2, 3, 4, 5])
    #expect(Intensity(rawValue: 0) == nil)
    #expect(Intensity(rawValue: 6) == nil)
    #expect(Intensity.default.rawValue == 3)
}

@Test
func intensityCodableIsAValidatedScalar() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(Intensity.default)
    #expect(String(decoding: encoded, as: UTF8.self) == "3")
    #expect(try decoder.decode(Intensity.self, from: Data("3".utf8)) == .default)
    #expect((try? decoder.decode(Intensity.self, from: Data("0".utf8))) == nil)
    #expect((try? decoder.decode(Intensity.self, from: Data("6".utf8))) == nil)
    #expect((try? decoder.decode(Intensity.self, from: Data("abc".utf8))) == nil)
    #expect((try? decoder.decode(Intensity.self, from: Data("\"3\"".utf8))) == nil)
}
