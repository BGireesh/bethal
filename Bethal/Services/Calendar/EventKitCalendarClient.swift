import EventKit
import Foundation

/// Production EventKit-backed calendar client.
public final class EventKitCalendarClient: CalendarClient, @unchecked Sendable {
    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func authorizationStatus() -> CalendarAuthorizationStatus {
        Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    public func requestAccess() async -> CalendarAuthorizationStatus {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .authorized : .denied
            } else {
                let granted = try await store.requestAccess(to: .event)
                return granted ? .authorized : .denied
            }
        } catch {
            return .denied
        }
    }

    public func fetchEvents(from start: Date, to end: Date) async throws -> [CalendarMeetingEvent] {
        guard authorizationStatus().isUsable else {
            throw CalendarClientError.notAuthorized
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.map(Self.mapEvent)
    }

    public static func map(_ status: EKAuthorizationStatus) -> CalendarAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess, .authorized: return .authorized
        case .writeOnly: return .denied
        @unknown default: return .notDetermined
        }
    }

    public static func mapEvent(_ event: EKEvent) -> CalendarMeetingEvent {
        CalendarMeetingEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            calendarTitle: event.calendar?.title,
            location: event.location,
            isAllDay: event.isAllDay
        )
    }
}
