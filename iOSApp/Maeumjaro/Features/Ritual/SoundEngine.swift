import AVFoundation
protocol RitualSoundEngine: AnyObject { func completion() }
final class SystemRitualSoundEngine: RitualSoundEngine { var enabled: Bool; private var player: AVAudioPlayer?; init(enabled: Bool = false) { self.enabled = enabled }; func completion() { guard enabled, let url = Bundle.main.url(forResource: "ritual-complete-v1", withExtension: "caf") else { return }; player = try? AVAudioPlayer(contentsOf: url); player?.play() } }
final class NoopRitualSoundEngine: RitualSoundEngine { func completion() {} }
