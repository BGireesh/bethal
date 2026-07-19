import Foundation

/// Abstraction over EventKit for testable calendar queries.
public protocol CalendarClient: Sendable {
    func authorizationStatus() -> CalendarAuthorizationStatus
    func requestAccess() async -> CalendarAuthorizationStatus
    /// Fetches events overlapping `[start, end)`.
    func fetchEvents(from start: Date, to end: Date) async throws -> [CalendarMeetingEvent]
}

public enum CalendarClientError: Error, Equatable, Sendable, LocalizedError {
    case notAuthorized
    case fetchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Calendar access is not authorized."
        case .fetchFailed(let detail): return detail
        }
    }
}

/// In-memory calendar for unit tests.
public final class MockCalendarClient: CalendarClient, @unchecked Sendable {
    public var status: CalendarAuthorizationStatus
    public var requestResult: CalendarAuthorizationStatus
    public var events: [CalendarMeetingEvent]
    public var fetchError: Error?
    public private(set) var requestCount = 0
    public private(set) var lastFetchRange: (Date, Date)?

    public init(
        status: CalendarAuthorizationStatus = .authorized,
        requestResult: CalendarAuthorizationStatus? = nil,
        events: [CalendarMeetingEvent] = []
    ) {
        self.status = status
        self.requestResult = requestResult ?? status
        self.events = events
    }

    public func authorizationStatus() -> CalendarAuthorizationStatus { status }

    public func requestAccess() async -> CalendarAuthorizationStatus {
        requestCount += 1
        status = requestResult
        return status
    }

    public func fetchEvents(from start: Date, to end: Date) async throws -> [CalendarMeetingEvent] {
        lastFetchRange = (start, end)
        if let fetchError { throw fetchError }
        guard status.isUsable else { throw CalendarClientError.notAuthorized }
        return events.filter { event in
            event.startDate < end && event.endDate > start
        }
    }
}
