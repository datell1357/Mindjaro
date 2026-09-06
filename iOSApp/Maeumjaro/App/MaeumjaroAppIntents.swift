import AppIntents
import MaeumjaroIntents

struct MaeumjaroAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MaeumjaroAppIntentsPackage.self]
    }
}
