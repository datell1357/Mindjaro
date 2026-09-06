import CoreGraphics
import Foundation

public struct PenCanvasSize: Equatable, Hashable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

public struct PenFrame: Equatable, Hashable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public func scaled(to canvas: PenCanvasSize) -> CGRect {
        let scaleX = CGFloat(canvas.width) / CGFloat(PenAssetContract.canvasSize.width)
        let scaleY = CGFloat(canvas.height) / CGFloat(PenAssetContract.canvasSize.height)
        let scale = min(scaleX, scaleY)
        return CGRect(
            x: CGFloat(x) * scale,
            y: CGFloat(y) * scale,
            width: CGFloat(width) * scale,
            height: CGFloat(height) * scale
        )
    }
}

public enum PenAssetID: String, CaseIterable, Hashable, Sendable {
    case penLocked = "PenLocked"
    case penReady = "PenReady"
    case penComplete = "PenComplete"
    case penRingLocked = "PenRingLocked"
    case penRingReady = "PenRingReady"
    case penWindowEmpty = "PenWindowEmpty"
    case penLiquidFull = "PenLiquidFull"
}

public typealias PenArtifactID = PenAssetID

public enum PenState: String, CaseIterable, Hashable, Sendable {
    case locked
    case ready
    case complete
}

public enum PenComponent: String, CaseIterable, Hashable, Sendable {
    case ringLocked
    case ringReady
    case windowEmpty
    case liquidFull
}

public enum PenLayer: String, CaseIterable, Hashable, Sendable {
    case readyBase
    case windowEmpty
    case maskedLiquidFull
    case ringCylinder
}

public enum PenRingDirection: Int, CaseIterable, Hashable, Sendable {
    case left = -1
    case right = 1
}

public enum PenRingFace: String, Hashable, Sendable {
    case source
    case destination
}

public struct PenRingPresentation: Equatable, Sendable {
    public let face: PenRingFace
    public let rotationDegrees: Double

    public init(face: PenRingFace, rotationDegrees: Double) {
        self.face = face
        self.rotationDegrees = rotationDegrees
    }
}

public enum PenAssetContract {
    public static let schemaVersion = 5
    public static let canvasSize = PenCanvasSize(width: 1024, height: 1536)
    public static let ringFrame = PenFrame(x: 362, y: 136, width: 300, height: 112)
    public static let liquidWindowFrame = PenFrame(x: 449, y: 650, width: 126, height: 414)
    public static let minimumTouchTarget: CGFloat = 44

    public static let assetIDs = PenAssetID.allCases
    public static let layerOrder: [PenLayer] = [
        .readyBase,
        .windowEmpty,
        .maskedLiquidFull,
        .ringCylinder
    ]

    public static func frame(for layer: PenLayer) -> PenFrame? {
        switch layer {
        case .readyBase:
            nil
        case .windowEmpty, .maskedLiquidFull:
            liquidWindowFrame
        case .ringCylinder:
            ringFrame
        }
    }

    public static func asset(for state: PenState) -> PenAssetID {
        switch state {
        case .locked:
            .penLocked
        case .ready:
            .penReady
        case .complete:
            .penComplete
        }
    }

    public static func asset(for component: PenComponent) -> PenAssetID {
        switch component {
        case .ringLocked:
            .penRingLocked
        case .ringReady:
            .penRingReady
        case .windowEmpty:
            .penWindowEmpty
        case .liquidFull:
            .penLiquidFull
        }
    }

    public static func readyBaseExclusionRect(in canvas: PenCanvasSize = canvasSize) -> CGRect {
        ringFrame.scaled(to: canvas)
    }

    public static func ringPresentation(
        progress: Double,
        direction: PenRingDirection
    ) -> PenRingPresentation {
        let q = progress.clamped(to: 0...1)
        if q < 0.5 {
            return PenRingPresentation(
                face: .source,
                rotationDegrees: Double(direction.rawValue) * 180 * q
            )
        }
        return PenRingPresentation(
            face: .destination,
            rotationDegrees: Double(direction.rawValue) * 180 * (q - 1)
        )
    }

    public static func liquidTopOffset(initialFill: Double, progress: Double) -> Double {
        let fill = initialFill.clamped(to: 0...1)
        let value = progress.clamped(to: 0...1)
        return Double(liquidWindowFrame.height) * (1 - (fill * (1 - value)))
    }

    public static func liquidTopY(initialFill: Double, progress: Double) -> Double {
        Double(liquidWindowFrame.y) + liquidTopOffset(initialFill: initialFill, progress: progress)
    }

    public static func remainingLiquidHeight(initialFill: Double, progress: Double) -> Double {
        Double(liquidWindowFrame.height) * initialFill.clamped(to: 0...1)
            * (1 - progress.clamped(to: 0...1))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
