@MainActor
public protocol SettingsRepository {
    func load() async throws -> AppSettings
    func save(_ settings: AppSettings) async throws
}
