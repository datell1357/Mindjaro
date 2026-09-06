import Foundation

public enum AppGroupDefaultsError: Error, Equatable, Sendable {
    case unavailableSuite(String)
}

public enum AppGroupDataStoreError: Error, Equatable, Sendable {
    case writeRejected(String)
    case removeRejected(String)
}

public protocol AppGroupDataStore: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String) throws
    func remove(forKey key: String) throws
}

public final class UserDefaultsDataStore: AppGroupDataStore, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ data: Data, forKey key: String) throws {
        defaults.set(data, forKey: key)
    }

    public func remove(forKey key: String) throws {
        defaults.removeObject(forKey: key)
    }
}

public final class MemoryDataStore: AppGroupDataStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data]
    private var failWritesState = false
    private var failRemovalsState = false
    private var forceReadFailureState = false

    public init(seed: [String: Data] = [:]) {
        values = seed
    }

    public var failWrites: Bool {
        get { withLock { failWritesState } }
        set { withLock { failWritesState = newValue } }
    }

    public var failRemovals: Bool {
        get { withLock { failRemovalsState } }
        set { withLock { failRemovalsState = newValue } }
    }

    public var forceReadFailure: Bool {
        get { withLock { forceReadFailureState } }
        set { withLock { forceReadFailureState = newValue } }
    }

    public func data(forKey key: String) -> Data? {
        withLock {
            guard !forceReadFailureState else { return nil }
            return values[key]
        }
    }

    public func set(_ data: Data, forKey key: String) throws {
        try withLockThrowing {
            guard !failWritesState else { throw AppGroupDataStoreError.writeRejected(key) }
            values[key] = data
        }
    }

    public func remove(forKey key: String) throws {
        try withLockThrowing {
            guard !failRemovalsState else { throw AppGroupDataStoreError.removeRejected(key) }
            values.removeValue(forKey: key)
        }
    }

    private func withLock<T>(_ operation: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }

    private func withLockThrowing<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

public struct FileDataStore: AppGroupDataStore, Sendable {
    private let directoryURL: URL

    public init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    public func data(forKey key: String) -> Data? {
        try? Data(contentsOf: fileURL(forKey: key))
    }

    public func set(_ data: Data, forKey key: String) throws {
        try data.write(to: fileURL(forKey: key), options: .atomic)
    }

    public func remove(forKey key: String) throws {
        let url = fileURL(forKey: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func fileURL(forKey key: String) -> URL {
        let safeName = key.utf8.map { String(format: "%02x", $0) }.joined()
        return directoryURL.appendingPathComponent(safeName, isDirectory: false)
    }
}

public struct AppGroupDefaults: Sendable {
    public enum Keys {
        public static let strength = "shared.strength.v1"
        public static let todaySummary = "shared.todaySummary.v1"
        public static let widgetTheme = "shared.widgetTheme.v1"
        public static let all = [strength, todaySummary, widgetTheme]
    }

    private let storage: any AppGroupDataStore
    private let namespacePrefix: String

    public init(storage: any AppGroupDataStore) {
        self.init(storage: storage, namespacePrefix: "")
    }

    fileprivate init(storage: any AppGroupDataStore, namespacePrefix: String) {
        self.storage = storage
        self.namespacePrefix = namespacePrefix
    }

    public init(suiteName: String = AppIdentifiers.appGroupID) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw AppGroupDefaultsError.unavailableSuite(suiteName)
        }
        self.init(storage: UserDefaultsDataStore(defaults: defaults))
    }

    public func data(forKey key: String) -> Data? {
        storage.data(forKey: namespacedKey(forKey: key))
    }

    public func set(_ data: Data, forKey key: String) throws {
        try storage.set(data, forKey: namespacedKey(forKey: key))
    }

    public func remove(forKey key: String) throws {
        try storage.remove(forKey: namespacedKey(forKey: key))
    }

    public func namespacedKey(forKey key: String) -> String {
        namespacePrefix + key
    }

    #if DEBUG
    fileprivate func scoped(to namespace: DebugFixtureNamespace) -> AppGroupDefaults {
        AppGroupDefaults(storage: storage, namespacePrefix: namespace.keyPrefix)
    }
    #endif
}

#if DEBUG
public struct DebugFixtureNamespace: Equatable, Sendable {
    public static let activeFixtureIDKey = "qa.activeFixtureID"

    public let fixtureID: UUID

    public init?(fixtureID: String) {
        guard let fixtureID = UUID(uuidString: fixtureID) else { return nil }
        self.fixtureID = fixtureID
    }

    public init?(arguments: [String]) {
        let values = arguments.enumerated().compactMap { index, argument -> String? in
            guard argument == "-MaeumjaroFixtureID", arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }
        guard values.count == 1, let value = values.first else { return nil }
        self.init(fixtureID: value)
    }

    public var keyPrefix: String {
        "qa.\(fixtureID.uuidString.lowercased())."
    }

    public func scopedDefaults(from defaults: AppGroupDefaults) -> AppGroupDefaults {
        defaults.scoped(to: self)
    }

    public static func active(in defaults: AppGroupDefaults) -> Self? {
        guard let data = defaults.data(forKey: activeFixtureIDKey),
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Self(fixtureID: value)
    }

    @discardableResult
    public static func select(from arguments: [String], in defaults: AppGroupDefaults) throws -> Self? {
        guard arguments.contains("-MaeumjaroFixtureID") else { return active(in: defaults) }
        guard let namespace = Self(arguments: arguments) else { return nil }
        try defaults.set(Data(namespace.fixtureID.uuidString.utf8), forKey: activeFixtureIDKey)
        return namespace
    }
}
#endif
