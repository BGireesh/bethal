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
                Text("Full provider discovery and defaults arrive in a later update. You can change this later as processing ships.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Capture") {
                LabeledContent("Default mode") {
                    Text(controller.settingsCaptureMode)
                }
            }

            Section("Calendar") {
                LabeledContent("Auto-detect") {
                    Text(controller.settingsCalendar)
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
