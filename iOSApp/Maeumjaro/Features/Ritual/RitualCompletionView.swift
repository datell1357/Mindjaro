import SwiftUI
import MaeumjaroDomain
struct RitualCompletionView: View {
    let intensity: Intensity; let completedAt: Date; let palette: ThemePalette; let onRestart: () -> Void; let onRecords: () -> Void
    init(intensity: Intensity, completedAt: Date, palette: ThemePalette = .quietIvory, onRestart: @escaping () -> Void, onRecords: @escaping () -> Void) { self.intensity = intensity; self.completedAt = completedAt; self.palette = palette; self.onRestart = onRestart; self.onRecords = onRecords }
    var body: some View { ScrollView { VStack(spacing: 20) { Text("의식 완료").font(.title).fontWeight(.bold).foregroundStyle(palette.ink.color); Text("강도 \(intensity.rawValue) 의식 완료").font(.title3).foregroundStyle(palette.ink.color); Text("자동 기록 \(completedAt.formatted(date: .omitted, time: .shortened))").foregroundStyle(palette.secondaryInk.color); Text("이 화면은 자기 조절을 위한 짧은 의식 기록입니다.").font(.body).foregroundStyle(palette.ink.color).multilineTextAlignment(.center); Button("다시 실행", action: onRestart).buttonStyle(.borderedProminent).tint(palette.accent.color).foregroundStyle(palette.accentForeground.color).frame(minHeight: DesignTokens.minimumTouchTarget); Button("기록 보기", action: onRecords).buttonStyle(.bordered).tint(palette.accent.color).frame(minHeight: DesignTokens.minimumTouchTarget) }.padding() }.background(palette.background.color).accessibilityElement(children: .contain) }
}
