import SwiftUI
import MaeumjaroDomain

struct SettingsView: View {
    @State private var model: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let onPro: () -> Void
    let onDataManagement: () -> Void
    let onWidgetHelp: () -> Void
    let onSafety: () -> Void

    init(model: SettingsViewModel, onPro: @escaping () -> Void = {}, onDataManagement: @escaping () -> Void = {}, onWidgetHelp: @escaping () -> Void = {}, onSafety: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        self.onPro = onPro
        self.onDataManagement = onDataManagement
        self.onWidgetHelp = onWidgetHelp
        self.onSafety = onSafety
    }

    private var palette: ThemePalette {
        ThemePalette.palette(for: model.settings.themeID, colorScheme: colorScheme, contrast: colorSchemeContrast)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacing6) {
                VStack(alignment: .leading, spacing: DesignTokens.spacing2) {
                    Text("설정").font(DesignTokens.font(for: .screenTitle)).accessibilityAddTraits(.isHeader)
                    Text("나에게 맞는 마음 정리")
                        .font(DesignTokens.font(for: .body))
                        .foregroundStyle(palette.secondaryInk.color)
                }
                card("기본 강도", icon: "slider.horizontal.3") {
                    Text("펜을 누르고 머무는 시간을 골라 주세요.")
                        .font(DesignTokens.font(for: .secondary))
                        .foregroundStyle(palette.secondaryInk.color)
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: DesignTokens.spacing2) {
                            ForEach(Intensity.allCases, id: \.self) { intensity in intensityButton(intensity) }
                        }
                    } else {
                        HStack(spacing: DesignTokens.spacing2) {
                            ForEach(Intensity.allCases, id: \.self) { intensity in intensityButton(intensity) }
                        }
                    }
                }
                card("피드백", icon: "waveform") {
                    Toggle("햅틱", isOn: binding(get: { model.settings.hapticsEnabled }, set: { value in Task { await model.setHapticsEnabled(value) } }))
                        .accessibilityIdentifier("settings-haptics-toggle")
                        .frame(minHeight: DesignTokens.minimumTouchTarget)
                    Divider().overlay(palette.border.color)
                    Toggle("소리", isOn: binding(get: { model.settings.soundEnabled }, set: { value in Task { await model.setSoundEnabled(value) } }))
                        .frame(minHeight: DesignTokens.minimumTouchTarget)
                    Divider().overlay(palette.border.color)
                    Toggle("앱 동작 줄이기", isOn: binding(get: { model.settings.reducedMotionEnabled }, set: { value in Task { await model.setReducedMotionEnabled(value) } }))
                        .frame(minHeight: DesignTokens.minimumTouchTarget)
                    if systemReduceMotion {
                        Text("시스템 동작 줄이기가 켜져 있어요.")
                            .font(DesignTokens.font(for: .secondary))
                            .foregroundStyle(palette.secondaryInk.color)
                    }
                    Divider().overlay(palette.border.color)
                    LabeledContent("문구 톤") {
                        Picker("문구 톤", selection: binding(get: { model.settings.phraseTonePreference }, set: { value in Task { await model.setPhraseTonePreference(value) } })) {
                            Text("자동").tag(PhraseTonePreference.automatic)
                            Text("부드럽게").tag(PhraseTonePreference.gentle)
                            Text("중립").tag(PhraseTonePreference.neutral)
                            Text("단호하게").tag(PhraseTonePreference.firm)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget, alignment: .leading)
                }
                card("내 마음자로", icon: "square.grid.2x2") {
                    destinationRow("Pro 기능 보기", icon: "sparkles", action: onPro)
                    Divider().overlay(palette.border.color)
                    destinationRow("데이터 관리", icon: "externaldrive", action: onDataManagement)
                }
                card("도움말", icon: "questionmark.circle") {
                    destinationRow("위젯 도움말", icon: "square.on.square", action: onWidgetHelp)
                    Divider().overlay(palette.border.color)
                    destinationRow("안전 안내", icon: "heart", action: onSafety)
                }
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                        .accessibilityLabel(String(localized: "설정 오류: \(error)"))
                }
            }
            .padding(DesignTokens.spacing6)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("settings-screen")
        .font(DesignTokens.font(for: .body))
        .foregroundStyle(palette.ink.color)
        .tint(palette.accent.color)
        .background(palette.background.color.ignoresSafeArea())
        .navigationTitle("설정")
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }

    private func card<Content: View>(_ title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
            Label(title, systemImage: icon)
                .font(DesignTokens.font(for: .sectionTitle))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(DesignTokens.spacing5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
    }

    private func intensityButton(_ intensity: Intensity) -> some View {
        let isSelected = model.selectedIntensity == intensity
        return Button { Task { await model.setIntensity(intensity) } } label: {
            HStack(spacing: DesignTokens.spacing2) {
                Text(dynamicTypeSize.isAccessibilitySize ? "강도 \(intensity.rawValue)" : "\(intensity.rawValue)")
                    .font(DesignTokens.font(for: .body).weight(.semibold))
                if isSelected { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
            }
            .frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget)
            .foregroundStyle(isSelected ? palette.accentForeground.color : palette.ink.color)
            .background(isSelected ? palette.accent.color : palette.background.color, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("강도 \(intensity.rawValue)")
        .accessibilityValue(isSelected ? "선택됨" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("settings-intensity-\(intensity.rawValue)")
    }

    private func destinationRow(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacing3) {
                Image(systemName: icon).foregroundStyle(palette.accent.color).frame(width: 24)
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DesignTokens.spacing2)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(palette.secondaryInk.color)
            }
            .frame(minHeight: DesignTokens.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }

    private func binding<Value>(get: @escaping @MainActor @Sendable () -> Value, set: @escaping @MainActor @Sendable (Value) -> Void) -> Binding<Value> { Binding(get: get, set: set) }
}
