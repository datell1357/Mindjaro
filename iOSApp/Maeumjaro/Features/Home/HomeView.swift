import SwiftUI
import MaeumjaroDomain

struct HomeView: View {
    let onStart: () -> Void
    let palette: ThemePalette

    init(palette: ThemePalette = .quietIvory, onStart: @escaping () -> Void) {
        self.onStart = onStart
        self.palette = palette
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            palette.background.color.ignoresSafeArea()
            GeometryReader { proxy in
                let penHeight = max(0, proxy.size.height - 100)
                VStack(spacing: DesignTokens.spacing3) {
                    Spacer().frame(height: 56)
                    Button(action: onStart) {
                        Image("PenLocked")
                            .resizable()
                            .frame(width: penHeight * 1024 / 1536, height: penHeight)
                            .frame(width: min(proxy.size.width, penHeight * 300 / 1536))
                            .clipped()
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ritual-start")
                    .accessibilityLabel("펜 열기")
                    Capsule()
                        .fill(palette.border.color)
                        .frame(width: min(proxy.size.width * 0.38, 180), height: 3)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        }
    }
}
