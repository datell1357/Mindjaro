import SwiftUI

struct WidgetHelpView: View {
    let palette: ThemePalette
    var onDismiss: (() -> Void)? = nil

    init(palette: ThemePalette = .quietIvory, onDismiss: (() -> Void)? = nil) {
        self.palette = palette
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
            Text("위젯으로 바로 시작하기").font(DesignTokens.font(for: .screenTitle)).foregroundStyle(palette.ink.color).accessibilityAddTraits(.isHeader)
            Text("홈 화면에 마음자로 위젯을 추가하면 펜 화면으로 바로 들어갈 수 있어요.").font(DesignTokens.font(for: .body)).foregroundStyle(palette.ink.color)
            Label("홈 화면을 길게 누르고 작은 마음자로 위젯을 추가하세요.", systemImage: "plus.app").foregroundStyle(palette.ink.color)
            Label("위젯 어디든 누르면 펜 화면이 열려요. 강도는 앱 설정에서 바꿀 수 있어요.", systemImage: "hand.tap").foregroundStyle(palette.ink.color)
            Label("잠금화면 사용자화에서 원형 마음자로 위젯도 추가할 수 있어요.", systemImage: "lock.circle").foregroundStyle(palette.ink.color)
            if let onDismiss { Button("나중에", action: onDismiss).frame(minHeight: DesignTokens.minimumTouchTarget).tint(palette.accent.color) }
        }
        .padding(DesignTokens.spacing6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background.color.ignoresSafeArea()).navigationTitle("위젯 도움말").tint(palette.accent.color)
    }
}

struct WidgetHelpBanner: View {
    let palette: ThemePalette
    let onDismiss: () -> Void
    let onOpen: () -> Void

    init(palette: ThemePalette = .quietIvory, onDismiss: @escaping () -> Void, onOpen: @escaping () -> Void = {}) {
        self.palette = palette
        self.onDismiss = onDismiss
        self.onOpen = onOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing2) {
            Text("위젯으로 더 빠르게 시작해 보세요").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color)
            Text("설정에서 언제든 도움말을 다시 볼 수 있어요.").font(DesignTokens.font(for: .secondary)).foregroundStyle(palette.secondaryInk.color)
            HStack { Button("도움말 보기", action: onOpen).frame(minHeight: DesignTokens.minimumTouchTarget); Spacer(); Button("닫기", action: onDismiss).frame(minHeight: DesignTokens.minimumTouchTarget) }.tint(palette.accent.color)
        }.padding(DesignTokens.spacing4).background(palette.surface.color).clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
    }
}
