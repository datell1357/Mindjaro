import Foundation

public struct IntensityProfile: Equatable, Sendable {
    public let intensity: Intensity
    public let initialFill: Double
    public let durationMilliseconds: Int
    public let progressPulseCount: Int
    public let progressPulseThresholds: [Double]

    public init(intensity: Intensity) {
        let duration: Int = switch intensity.rawValue {
        case 1: 1200
        case 2: 1500
        case 3: 1800
        case 4: 2200
        case 5: 3200
        default: 1800
        }
        self.intensity = intensity
        initialFill = 1.0
        durationMilliseconds = duration
        progressPulseCount = intensity.rawValue
        progressPulseThresholds = (1...intensity.rawValue).map {
            Double($0) / Double(intensity.rawValue + 1)
        }
    }

    public func progress(atElapsedMilliseconds elapsed: Int64) -> Double {
        min(1, max(0, Double(max(0, elapsed)) / Double(durationMilliseconds)))
    }
}
