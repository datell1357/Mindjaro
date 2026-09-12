import SwiftUI
import MaeumjaroDomain

struct OnboardingView: View {
    @State private var model: OnboardingViewModel
    let onComplete: (AppSettings) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(model: OnboardingViewModel, onComplete: @escaping (AppSettings) -> Void) {
        _model = State(initialValue: model); self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacing5) {
            ProgressView(value: Double(model.step.number), total: 6)
                .tint(resolvedPalette.accent.color)
                .accessibilityLabel(String(localized: "온보딩 \(model.step.number)단계"))
            GeometryReader { proxy in
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: proxy.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if let error = model.errorMessage { Text(error).font(DesignTokens.font(for: .secondary)).foregroundStyle(.red) }
            if model.step == .widgetHelp {
                Button("완료") { Task { if let settings = await model.advance() { onComplete(settings) } } }
                    .buttonStyle(.borderedProminent).foregroundStyle(resolvedPalette.accentForeground.color).frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget).accessibilityIdentifier("onboarding-finish")
                Button("나중에") { Task { if let settings = await model.skipWidgetHelp() { onComplete(settings) } } }.frame(minHeight: DesignTokens.minimumTouchTarget)
            } else {
                Button(LocalizedStringKey(model.step == .purpose ? "시작하기" : "다음")) { Task { if let settings = await model.advance() { onComplete(settings) } } }
                    .buttonStyle(.borderedProminent).foregroundStyle(resolvedPalette.accentForeground.color).frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget).accessibilityIdentifier("onboarding-next")
            }
        }
        .padding(DesignTokens.spacing6)
        .foregroundStyle(resolvedPalette.ink.color)
        .tint(resolvedPalette.accent.color)
        .background(resolvedPalette.background.color.ignoresSafeArea())
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .purpose:
            step("마음자로", "잠깐 멈추고 지금의 선택을 돌아보는 짧은 비의료적 자기조절 의식이에요.")
        case .howToUse:
            step("세 단계로 사용해요", "1. 시작을 누르고\n2. 화면을 가로로 천천히 쓸어 흐름을 따라가고\n3. 새로 가볍게 눌러 잠깐 멈췄다가 놓은 뒤 기록을 확인해요.")
        case .intensity:
            VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
                Text("기본 강도를 골라 주세요").font(DesignTokens.font(for: .screenTitle)).accessibilityAddTraits(.isHeader)
                Text("나중에 설정에서 바꿀 수 있어요.").font(DesignTokens.font(for: .body))
                ForEach(Intensity.allCases, id: \.self) { intensity in
                    Button { model.selectIntensity(intensity) } label: { HStack { Text("강도 \(intensity.rawValue)"); Spacer(); if model.selectedIntensity == intensity { Image(systemName: "checkmark") } } }
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget).accessibilityIdentifier("onboarding-intensity-\(intensity.rawValue)")
                }
            }
        case .feedback:
            VStack(alignment: .leading, spacing: DesignTokens.spacing3) {
                Text("피드백을 설정해요").font(DesignTokens.font(for: .screenTitle)).accessibilityAddTraits(.isHeader)
                Toggle("햅틱 켜기", isOn: Binding(get: { model.settings.hapticsEnabled }, set: { value in Task { await model.setHapticsEnabled(value) } })).frame(minHeight: DesignTokens.minimumTouchTarget)
                Toggle("소리", isOn: Binding(get: { model.settings.soundEnabled }, set: { value in Task { await model.setSoundEnabled(value) } })).frame(minHeight: DesignTokens.minimumTouchTarget)
                Toggle("앱 동작 줄이기", isOn: Binding(get: { model.settings.reducedMotionEnabled }, set: { value in Task { await model.setReducedMotionEnabled(value) } })).frame(minHeight: DesignTokens.minimumTouchTarget)
            }
        case .safety:
            step("안전 안내", "마음자로는 진단·치료·의학적 조언을 제공하지 않아요. 불편하거나 걱정되는 상황에서는 신뢰할 수 있는 사람 또는 전문가와 상의하세요.")
        case .widgetHelp:
            WidgetHelpView(palette: resolvedPalette)
        }
    }

    private var resolvedPalette: ThemePalette {
        ThemePalette.palette(for: model.settings.themeID, colorScheme: colorScheme, contrast: colorSchemeContrast)
    }

    private func step(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing4) { Text(LocalizedStringKey(title)).font(DesignTokens.font(for: .screenTitle)).accessibilityAddTraits(.isHeader); Text(LocalizedStringKey(message)).font(DesignTokens.font(for: .body)).fixedSize(horizontal: false, vertical: true) }
    }
}
