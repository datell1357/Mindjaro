import Foundation

public protocol Clock: Sendable {
    var nowUTC: Date { get }
}

public struct SystemClock: Clock, Sendable {
    public init() {}

    public var nowUTC: Date { Date() }
}

public protocol CalendarProviding: Sendable {
    var calendar: Calendar { get }
}

public struct SystemCalendarProvider: CalendarProviding, Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
}

public struct EventTimeContext: Sendable {
    public let clock: any Clock
    public let calendar: Calendar

    public init(clock: any Clock = SystemClock(), calendar: Calendar = .current) {
        self.clock = clock
        self.calendar = calendar
    }
}

