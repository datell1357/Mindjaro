import MaeumjaroDomain
import MaeumjaroShared
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let strengthStore: SharedStrengthStore

    private(set) var currentIntensity: Intensity

    init(strengthStore: SharedStrengthStore) {
        self.strengthStore = strengthStore
        currentIntensity = strengthStore.read()
    }

    func refresh() {
        currentIntensity = strengthStore.read()
    }
}
