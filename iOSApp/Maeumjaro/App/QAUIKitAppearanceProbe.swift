#if DEBUG && MAEUMJARO_QA_FIXTURES
import SwiftUI
import UIKit

/// Read-only diagnostic: never overrides traits or appearance preferences.
struct QAUIKitAppearanceProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeLabel { ProbeLabel() }
    func updateUIView(_ uiView: ProbeLabel, context: Context) { uiView.refresh() }

    final class ProbeLabel: UILabel {
        override init(frame: CGRect) {
            super.init(frame: frame)
            text = "UIKit"
            font = .preferredFont(forTextStyle: .caption2)
            textColor = .label
            backgroundColor = .systemBackground
            isAccessibilityElement = true
            accessibilityIdentifier = "qa-uikit-appearance"
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProbeLabel, _: UITraitCollection) in
                view.refresh()
            }
        }
        required init?(coder: NSCoder) { nil }
        override func didMoveToWindow() { super.didMoveToWindow(); refresh() }
        func refresh() {
            accessibilityValue = "view=\(style(traitCollection.userInterfaceStyle));window=\(style(window?.traitCollection.userInterfaceStyle));scene=\(style(window?.windowScene?.traitCollection.userInterfaceStyle))"
        }
        private func style(_ value: UIUserInterfaceStyle?) -> String {
            switch value {
            case .dark: "dark"
            case .light: "light"
            case .unspecified: "unspecified"
            default: "missing"
            }
        }
    }
}
#endif
