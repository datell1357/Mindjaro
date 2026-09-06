import SwiftUI

struct RootView: View {
    @State private var dependencies: AppShellDependencies?
    @State private var startupError: Error?
    @State private var router = AppRouter()

    init() {
        do { _dependencies = State(initialValue: try AppShellDependencies.makeProduction()) }
        catch { _dependencies = State(initialValue: nil); _startupError = State(initialValue: error) }
    }

    var body: some View {
        if let dependencies {
            AppShellView(dependencies: dependencies, router: router)
        } else {
            PersistenceFailureView(message: startupError?.localizedDescription ?? "알 수 없는 저장소 오류") {
                do { dependencies = try AppShellDependencies.makeProduction(); startupError = nil }
                catch { startupError = error }
            }
        }
    }
}

#Preview {
    RootView()
}
