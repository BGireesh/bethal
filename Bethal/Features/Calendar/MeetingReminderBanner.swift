import SwiftUI

/// In-app banner offering 1-click start for an upcoming calendar meeting (never auto-records).
struct MeetingReminderBanner: View {
    let event: CalendarMeetingEvent
    let minutesBefore: Int
    let onStartRecording: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignSpacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Upcoming meeting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(event.recordingTitle)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DesignSpacing.sm)

            Button("Start recording") {
                onStartRecording()
            }
            .buttonStyle(.borderedProminent)
            .help("Opens Record with this meeting title. Recording only starts when you click Start.")

            Button("Dismiss", role: .cancel) {
                onDismiss()
            }
        }
        .padding(DesignSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: event.startDate)
        return "Starts \(start) · reminder \(minutesBefore) min before · never auto-records"
    }
}
