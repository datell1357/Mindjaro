import Foundation

public protocol UUIDGenerator: Sendable {
    func makeUUID() -> UUID
}

public struct SystemUUIDGenerator: UUIDGenerator, Sendable {
    public init() {}

    public func makeUUID() -> UUID { UUID() }
}

