import SwiftUI
import MaeumjaroDomain

struct SettingsView: View {
    @State private var model: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let onPro: () -> Void
    let onDataManagement: () -> Void
    let onWidgetHelp: () -> Void
    let onSafety: () -> Void

    init(model: SettingsViewModel, onPro: @escaping () -> Void = {}, onDataManagement: @escaping () -> Void = {}, onWidgetHelp: @escaping () -> Void = {}, onSafety: @escaping () -> Void = {}) {
        _model = State(initialValue: model); self.onPro = onPro; self.onDataManagement = onDataManagement; self.onWidgetHelp = onWidgetHelp; self.onSafety = onSafety
    }

    var body: some View {
        let palette = ThemePalette.palette(for: model.settings.themeID, colorScheme: colorScheme, contrast: colorSchemeContrast)
        Form {
            Section {
                ForEach(Intensity.allCases, id: \.self) { intensity in
                    Button { Task { await model.setIntensity(intensity) } } label: {
                        HStack { Text("강도 \(intensity.rawValue)"); Spacer(); if model.selectedIntensity == intensity { Image(systemName: "checkmark") } }
                    }.frame(minHeight: DesignTokens.minimumTouchTarget).accessibilityIdentifier("settings-intensity-\(intensity.rawValue)")
                }
            } header: { Text("기본 강도").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            Section {
                Toggle("햅틱", isOn: binding(get: { model.settings.hapticsEnabled }, set: { value in Task { await model.setHapticsEnabled(value) } })).accessibilityIdentifier("settings-haptics-toggle")
                Toggle("소리", isOn: binding(get: { model.settings.soundEnabled }, set: { value in Task { await model.setSoundEnabled(value) } }))
                Toggle("앱 동작 줄이기", isOn: binding(get: { model.settings.reducedMotionEnabled }, set: { value in Task { await model.setReducedMotionEnabled(value) } }))
                LabeledContent("시스템 동작 줄이기", value: systemReduceMotion ? "켬" : "꺼짐")
                Picker("문구 톤", selection: binding(get: { model.settings.phraseTonePreference }, set: { value in Task { await model.setPhraseTonePreference(value) } })) {
                    Text("자동").tag(PhraseTonePreference.automatic); Text("부드럽게").tag(PhraseTonePreference.gentle); Text("중립").tag(PhraseTonePreference.neutral); Text("단호하게").tag(PhraseTonePreference.firm)
                }
            } header: { Text("피드백").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            Section {
                Button("위젯 도움말", action: onWidgetHelp).frame(minHeight: DesignTokens.minimumTouchTarget)
                Button("안전 안내", action: onSafety).frame(minHeight: DesignTokens.minimumTouchTarget)
            } header: { Text("도움말").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            Section {
                Button("Pro 기능 보기", action: onPro).frame(minHeight: DesignTokens.minimumTouchTarget)
                Button("데이터 관리", action: onDataManagement).frame(minHeight: DesignTokens.minimumTouchTarget)
            } header: { Text("마음자로").font(DesignTokens.font(for: .sectionTitle)).foregroundStyle(palette.ink.color) }
            .listRowBackground(palette.surface.color)
            if let error = model.errorMessage { Section { Text(error).foregroundStyle(.red).accessibilityLabel(String(localized: "설정 오류: \(error)")) } }
        }.navigationTitle("설정").toolbarTitleDisplayMode(.inline)
            .foregroundStyle(palette.ink.color)
            .tint(palette.accent.color)
            .scrollContentBackground(.hidden)
            .background(palette.background.color.ignoresSafeArea())
            .task { model.refreshIntensity() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.refreshIntensity() }
            }
    }

    private func binding<Value>(get: @escaping @MainActor @Sendable () -> Value, set: @escaping @MainActor @Sendable (Value) -> Void) -> Binding<Value> { Binding(get: get, set: set) }
}
