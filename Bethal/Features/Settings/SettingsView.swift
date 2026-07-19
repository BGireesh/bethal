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
                Picker("Default tool", selection: defaultProviderBinding) {
                    Text("None").tag(String?.none)
                    ForEach(KnownAIProviderOption.catalog) { option in
                        Text(option.displayName).tag(String?.some(option.id))
                    }
                }
                Toggle(
                    "Ask every time",
                    isOn: Binding(
                        get: { controller.askEveryTimeForProvider },
                        set: { controller.updateAIPreferences(defaultProviderID: controller.defaultAIProviderID, askEveryTime: $0) }
                    )
                )
                Text("Current: \(controller.settingsProvider)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if controller.discoveredProviders.isEmpty {
                    Text("No tools discovered yet.")
                        .font(.caption)
                } else {
                    ForEach(controller.discoveredProviders) { provider in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                Text(provider.isAvailable ? (provider.executablePath ?? "") : provider.howToInstall)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            Text(provider.isAvailable ? "Available" : "Missing")
                                .font(.caption)
                                .foregroundStyle(provider.isAvailable ? Color.secondary : Color.orange)
                        }
                    }
                }
                Button("Refresh local tools") {
                    controller.refreshDiscoveredProviders()
                }
                Text("Bethal runs tools already on your Mac. Meeting data is not uploaded by Bethal.")
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
        .onAppear {
            controller.refreshDiscoveredProviders()
        }
    }

    private var defaultProviderBinding: Binding<String?> {
        Binding(
            get: { controller.defaultAIProviderID },
            set: { controller.updateAIPreferences(defaultProviderID: $0, askEveryTime: controller.askEveryTimeForProvider) }
        )
    }
}
