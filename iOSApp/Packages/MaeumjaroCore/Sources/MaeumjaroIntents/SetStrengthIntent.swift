import AppIntents
import Foundation
import MaeumjaroDomain

public enum SetStrengthIntentError: Error, Equatable, Sendable {
    case invalidParameters
    case invalidTarget(Int)
    case invalidDelta(Int)
    case dependencyUnavailable
    case persistFailed(previousIntensity: Intensity)
    case readBackFailed(previousIntensity: Intensity, observedIntensity: Intensity?)

    public var previousIntensity: Intensity? {
        switch self {
        case let .persistFailed(previousIntensity),
             let .readBackFailed(previousIntensity, _):
            previousIntensity
        default:
            nil
        }
    }
}

enum StrengthIntentStoreError: Error, Equatable, Sendable {
    case persistFailed
    case persistReadBackFailed(observedIntensity: Intensity?)
}

extension SetStrengthIntentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidParameters:
            return String(localized: "intent.error.invalidParameters", defaultValue: "강도 하나를 지정하거나 한 단계만 변경해 주세요.", bundle: .module)
        case let .invalidTarget(value):
            return String(localized: "intent.error.invalidTarget", defaultValue: "강도는 1에서 5 사이여야 합니다. 입력값: \(value)", bundle: .module)
        case let .invalidDelta(value):
            return String(localized: "intent.error.invalidDelta", defaultValue: "강도 변경은 한 단계씩만 가능합니다. 입력값: \(value)", bundle: .module)
        case .dependencyUnavailable:
            return String(localized: "intent.error.dependencyUnavailable", defaultValue: "공유 강도 저장소를 사용할 수 없습니다.", bundle: .module)
        case .persistFailed:
            return String(localized: "intent.error.persistFailed", defaultValue: "강도를 저장하지 못했습니다. 현재 저장 상태를 확인하지 못했습니다.", bundle: .module)
        case let .readBackFailed(_, observedIntensity):
            if let observedIntensity {
                return String(localized: "intent.error.readBackMismatch", defaultValue: "저장한 강도와 읽은 강도가 일치하지 않습니다. 읽은 강도는 \(observedIntensity.rawValue)입니다.", bundle: .module)
            }
            return String(localized: "intent.error.readBackUnavailable", defaultValue: "저장한 강도의 결과를 확인하지 못했습니다. 현재 저장 상태를 확인하지 못했습니다.", bundle: .module)
        }
    }
}

public struct SetStrengthIntent: AppIntent {
    public typealias PerformResult = IntentResultContainer<Int, Never, Never, IntentDialog>

    public static let title = LocalizedStringResource("intent.title", defaultValue: "강도 변경", bundle: .module)
    public static let description = IntentDescription(LocalizedStringResource("intent.description", defaultValue: "마음자로 위젯의 현재 강도를 변경합니다.", bundle: .module))
    public static let openAppWhenRun = false

    @Parameter(title: LocalizedStringResource("intent.parameter.target", defaultValue: "목표 강도", bundle: .module))
    public var target: Int?

    @Parameter(title: LocalizedStringResource("intent.parameter.delta", defaultValue: "강도 변경량", bundle: .module))
    public var delta: Int?

    private let dependencies: IntentDependencies

    public init() {
        self.init(dependencies: .live)
    }

    public init(
        target: Int? = nil,
        delta: Int? = nil,
        dependencies: IntentDependencies = .live
    ) {
        self.dependencies = dependencies
        self.target = target
        self.delta = delta
    }

    public func perform() async throws -> PerformResult {
        guard (target == nil) != (delta == nil) else {
            throw SetStrengthIntentError.invalidParameters
        }

        let directTarget: Intensity?
        if let target {
            guard let targetIntensity = Intensity(rawValue: target) else {
                throw SetStrengthIntentError.invalidTarget(target)
            }
            directTarget = targetIntensity
        } else {
            directTarget = nil
        }

        if let delta, delta != -1, delta != 1 {
            throw SetStrengthIntentError.invalidDelta(delta)
        }

        let current: Intensity
        do {
            current = try await dependencies.read()
        } catch {
            throw SetStrengthIntentError.dependencyUnavailable
        }

        let requested: Intensity
        if let directTarget {
            requested = directTarget
        } else if let delta {
            requested = Intensity(rawValue: current.rawValue + delta) ?? current
        } else {
            throw SetStrengthIntentError.invalidParameters
        }

        if requested == current {
            return .result(
                value: current.rawValue,
                dialog: IntentDialog(LocalizedStringResource(
                    "intent.dialog.unchanged",
                    defaultValue: "현재 강도는 \(current.rawValue)입니다.",
                    bundle: .module
                ))
            )
        }

        do {
            try await dependencies.persist(requested)
        } catch let error as StrengthIntentStoreError {
            switch error {
            case .persistFailed:
                throw SetStrengthIntentError.persistFailed(previousIntensity: current)
            case let .persistReadBackFailed(observedIntensity):
                throw SetStrengthIntentError.readBackFailed(
                    previousIntensity: current,
                    observedIntensity: observedIntensity
                )
            }
        } catch {
            throw SetStrengthIntentError.persistFailed(previousIntensity: current)
        }

        let readBack: Intensity
        do {
            readBack = try await dependencies.readBack()
        } catch {
            throw SetStrengthIntentError.readBackFailed(
                previousIntensity: current,
                observedIntensity: nil
            )
        }

        guard readBack == requested else {
            throw SetStrengthIntentError.readBackFailed(
                previousIntensity: current,
                observedIntensity: readBack
            )
        }

        return .result(
            value: readBack.rawValue,
            dialog: IntentDialog(LocalizedStringResource(
                "intent.dialog.changed",
                defaultValue: "강도를 \(readBack.rawValue)로 변경했습니다.",
                bundle: .module
            ))
        )
    }
}
