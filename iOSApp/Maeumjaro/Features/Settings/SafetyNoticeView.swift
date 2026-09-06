import SwiftUI

struct SafetyNoticeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing4) {
            Text("안전 안내").font(DesignTokens.font(for: .screenTitle)).accessibilityAddTraits(.isHeader)
            Text("마음자로는 잠깐 멈추고 선택을 돌아보는 비의료적 자기조절 도구예요.").font(DesignTokens.font(for: .body))
            Text("진단, 치료, 의학적 조언을 제공하지 않으며 어떤 결과도 보장하지 않아요. 불편하거나 걱정되는 상황에서는 신뢰할 수 있는 사람 또는 전문가와 상의하세요.").font(DesignTokens.font(for: .body))
            Spacer()
        }.padding(DesignTokens.spacing6).frame(maxWidth: .infinity, alignment: .leading).navigationTitle("안전 안내")
    }
}
