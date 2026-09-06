import Foundation

public struct IntensityProfile: Equatable, Sendable {
    public let intensity: Intensity
    public let initialFill: Double
    public let durationMilliseconds: Int
    public let progressPulseCount: Int
    public let progressPulseThresholds: [Double]

    public init(intensity: Intensity) {
        let value: (fill: Double, duration: Int) = switch intensity.rawValue {
        case 1: (0.2, 1200)
        case 2: (0.4, 1500)
        case 3: (0.6, 1800)
        case 4: (0.8, 2200)
        case 5: (1.0, 3200)
        default: (0.6, 1800)
        }
        self.intensity = intensity
        initialFill = value.fill
        durationMilliseconds = value.duration
        progressPulseCount = intensity.rawValue
        progressPulseThresholds = (1...intensity.rawValue).map {
            Double($0) / Double(intensity.rawValue + 1)
        }
    }

    public func progress(atElapsedMilliseconds elapsed: Int64) -> Double {
        min(1, max(0, Double(max(0, elapsed)) / Double(durationMilliseconds)))
    }
}
