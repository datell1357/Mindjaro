import AppIntents
import MaeumjaroIntents

struct MaeumjaroWidgetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MaeumjaroAppIntentsPackage.self]
    }
}
