import UIKit
@MainActor protocol RitualHapticEngine: AnyObject { func start(); func progress(index: Int); func completion() }
@MainActor final class SystemRitualHapticEngine: RitualHapticEngine { var enabled: Bool; init(enabled: Bool = true) { self.enabled = enabled }; func start() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }; func progress(index: Int) { guard enabled else { return }; UIImpactFeedbackGenerator(style: .soft).impactOccurred() }; func completion() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) } }
@MainActor final class NoopRitualHapticEngine: RitualHapticEngine { func start() {}; func progress(index: Int) {}; func completion() {} }
