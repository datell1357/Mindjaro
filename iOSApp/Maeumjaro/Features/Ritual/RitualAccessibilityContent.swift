import Foundation
import MaeumjaroDomain
struct RitualAccessibilityContent: Equatable, Sendable {
    let label: String; let value: String; let hint: String
    static func forState(_ state: RitualState) -> Self {
        let hint: String = switch state.phase {
        case .locked: String(localized: "좌우로 밀어 잠금을 풀어 주세요."); case .unlocking: String(localized: "손가락을 좌우로 움직여 잠금을 풀어 주세요."); case .ready: String(localized: "잠시 누르고 있으면 진행을 시작합니다."); case .holdPending: String(localized: "조금 더 유지하면 진행을 시작합니다."); case .holding: String(localized: "누르고 있는 동안 진행합니다. 떼면 일시정지합니다."); case .paused: String(localized: "다시 눌러 이어서 진행합니다."); case .relocking: String(localized: "좌우로 밀어 잠글 수 있습니다."); case .saving: String(localized: "완료를 기록하는 중입니다."); case .saveFailed: String(localized: "기록하지 못했습니다. 다시 시도해 주세요."); case .completed: String(localized: "의식이 완료되었습니다.")
        }
        return Self(label: String(localized: "마음 정리 의식, 강도 \(state.intensity.rawValue)"), value: String(localized: "진행률 \(Int((state.progress * 100).rounded()))퍼센트"), hint: hint)
    }
}
