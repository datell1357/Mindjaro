import Observation

@MainActor
@Observable
final class AppRouter {
    private(set) var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func reset() {
        path.removeAll(keepingCapacity: false)
    }

    func replacePath(_ path: [AppRoute]) {
        self.path = path
    }
}
