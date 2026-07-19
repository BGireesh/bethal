import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: HomeShellController

    var body: some View {
        Form {
            Section("Working directory") {
                LabeledContent("Path") {
                    Text(controller.settingsPath ?? "Not set")
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                Button("Open in Finder") {
                    controller.openWorkingDirectory()
                }
                .disabled(controller.settingsPath == nil || controller.settingsPath?.isEmpty == true)

                if let open = controller.lastOpenSucceeded {
                    Text(open ? "Opened in Finder." : "Could not open folder.")
                        .font(.caption)
                        .foregroundStyle(open ? Color.secondary : Color.red)
                }
            }

            Section("AI processing") {
                LabeledContent("Default tool") {
                    Text(controller.settingsProvider)
                }
                Text("Full provider discovery and defaults arrive in a later update.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Capture") {
                LabeledContent("Default mode") {
                    Text(controller.settingsCaptureMode)
                }
            }

            Section("Calendar") {
                Toggle(
                    "Auto-detect upcoming meetings",
                    isOn: Binding(
                        get: { controller.calendarEnabled },
                        set: { controller.updateCalendarPreferences(enabled: $0, minutesBefore: controller.calendarMinutes) }
                    )
                )
                Stepper(
                    value: Binding(
                        get: { controller.calendarMinutes },
                        set: { controller.updateCalendarPreferences(enabled: controller.calendarEnabled, minutesBefore: $0) }
                    ),
                    in: 0...60,
                    step: 1
                ) {
                    Text("Remind \(controller.calendarMinutes) min before")
                }
                LabeledContent("Access") {
                    Text(controller.calendarAuthLabel)
                }
                Button("Request calendar access") {
                    controller.requestCalendarAccess()
                }
                Text("Bethal never auto-starts recording. Reminders offer a 1-click path to the Record screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let calendarError = controller.calendarError {
                    Text(calendarError)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }

            if let error = controller.settingsLoadError {
                Section("Status") {
                    Text(error)
                        .foregroundStyle(Color.red)
                }
            }

            if let refreshError = controller.refreshError {
                Section {
                    Text(refreshError)
                        .foregroundStyle(Color.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding(DesignSpacing.lg)
        .navigationTitle(AppSection.settings.title)
    }
}
