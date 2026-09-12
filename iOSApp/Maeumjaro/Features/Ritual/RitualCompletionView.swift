import SwiftUI
import MaeumjaroDomain
struct RitualCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    let phraseText: String
    let intensity: Intensity; let completedAt: Date; let palette: ThemePalette; let onRestart: () -> Void; let onRecords: (() -> Void)?
    init(intensity: Intensity, completedAt: Date, phraseText: String, palette: ThemePalette = .quietIvory, onRestart: @escaping () -> Void, onRecords: (() -> Void)? = nil) { self.intensity = intensity; self.completedAt = completedAt; self.phraseText = phraseText; self.palette = palette; self.onRestart = onRestart; self.onRecords = onRecords }
    var body: some View {
        VStack(spacing: DesignTokens.spacing6) {
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(palette.accent.color)
                .frame(width: 48, height: 48)
                .accessibilityLabel("기록 저장됨")
            Text(phraseText)
                .font(DesignTokens.font(for: .screenTitle))
                .foregroundStyle(palette.ink.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("completion-phrase")
            Text("자동 기록 \(completedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(palette.secondaryInk.color)
            HStack(spacing: DesignTokens.spacing8) {
                Button(action: onRestart) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: DesignTokens.minimumTouchTarget, height: DesignTokens.minimumTouchTarget)
                }
                .accessibilityLabel("다시 실행")
                .tint(palette.accent.color)
                Button(action: showRecords) {
                    Image(systemName: "clock")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: DesignTokens.minimumTouchTarget, height: DesignTokens.minimumTouchTarget)
                }
                .accessibilityLabel("기록 보기")
                .tint(palette.accent.color)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(palette.background.color)
        .accessibilityElement(children: .contain)
    }

    private func showRecords() {
        onRecords?()
        dismiss()
    }
}
