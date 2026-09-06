import SwiftUI

struct PersistenceFailureView: View {
    let message: String
    let onRetry: () -> Void

    init(error: Error, onRetry: @escaping () -> Void) {
        message = error.localizedDescription
        self.onRetry = onRetry
    }

    init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing5) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 32))
                .accessibilityHidden(true)
            Text("기록 저장소를 열지 못했어요")
                .font(DesignTokens.font(for: .screenTitle))
                .accessibilityAddTraits(.isHeader)
            Text("기존 기록을 삭제하지 않고 다시 시도할 수 있어요.")
                .font(DesignTokens.font(for: .body))
            Text(message)
                .font(DesignTokens.font(for: .secondary))
                .foregroundStyle(.secondary)
            Button("다시 시도", action: onRetry)
                .buttonStyle(.borderedProminent)
                .frame(minHeight: DesignTokens.minimumTouchTarget)
                .accessibilityHint("기록 저장소를 다시 엽니다")
        }
        .padding(DesignTokens.spacing6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
