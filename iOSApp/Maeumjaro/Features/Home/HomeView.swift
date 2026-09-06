import SwiftUI
import MaeumjaroDomain
import MaeumjaroPersistence

struct HomeView: View {
    let router: AppRouter
    let history: HistoryView
    let showWidgetHelp: Bool
    let onDismissWidgetHelp: () -> Void

    init(dependencies: AppShellDependencies, router: AppRouter, settings: AppSettings, onDismissWidgetHelp: @escaping () -> Void) {
        self.router = router
        self.showWidgetHelp = !settings.widgetHelpBannerDismissed
        self.onDismissWidgetHelp = onDismissWidgetHelp
        let events = SwiftDataEventRepository(container: dependencies.modelContainer)
        history = HistoryView(viewModel: HistoryViewModel(eventRepository: events))
    }

    var body: some View {
        history
            .safeAreaInset(edge: .top, spacing: DesignTokens.spacing2) {
                VStack(spacing: DesignTokens.spacing2) {
                    Button {
                        router.push(.ritual(source: .app))
                    } label: {
                        Label("의식 시작", systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("ritual-start")
                    if showWidgetHelp { WidgetHelpBanner(onDismiss: onDismissWidgetHelp) }
                }
                .padding(.horizontal, DesignTokens.spacing4)
                .padding(.bottom, DesignTokens.spacing2)
                .background(ThemePalette.quietIvory.background.color)
            }
    }
}
