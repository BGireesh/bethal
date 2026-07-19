import SwiftUI

struct HomeShellView: View {
    @StateObject private var controller: HomeShellController
    @State private var calendarPollTask: Task<Void, Never>?

    init(controller: HomeShellController? = nil) {
        _controller = StateObject(wrappedValue: controller ?? HomeShellController())
    }

    var body: some View {
        NavigationSplitView {
            List(selection: sectionBinding) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                        .accessibilityLabel(section.accessibilityLabel)
                }
            }
            .navigationSplitViewColumnWidth(
                min: DesignSpacing.sidebarMinWidth,
                ideal: DesignSpacing.sidebarMinWidth + 20
            )
            .navigationTitle(AppIdentity.displayName)
        } detail: {
            VStack(spacing: 0) {
                if let event = controller.activeReminder {
                    MeetingReminderBanner(
                        event: event,
                        minutesBefore: controller.calendarMinutesBefore,
                        onStartRecording: { controller.startRecordingFromReminder() },
                        onDismiss: { controller.dismissReminder() }
                    )
                    .padding([.horizontal, .top], DesignSpacing.md)
                }

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: DesignSpacing.contentMinWidth)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        controller.select(.record)
                    } label: {
                        Label("Record", systemImage: "record.circle")
                    }
                    .help("Start a new meeting recording")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        controller.refresh()
                        Task { await controller.refreshCalendar() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Reload meetings, todos, settings, and calendar")
                }
            }
        }
        .task {
            await controller.refreshCalendar()
            calendarPollTask?.cancel()
            calendarPollTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    await controller.refreshCalendar()
                }
            }
        }
        .onDisappear {
            calendarPollTask?.cancel()
        }
    }

    private var sectionBinding: Binding<AppSection?> {
        Binding(
            get: { controller.navigation.selectedSection },
            set: { newValue in
                if let newValue {
                    controller.select(newValue)
                }
            }
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch controller.navigation.selectedSection {
        case .meetings:
            meetingsDetail
        case .record:
            RecordingSessionView(prefilledTitle: controller.pendingRecordingTitle) {
                controller.refresh()
                controller.clearPendingRecordingTitle()
            }
        case .todos:
            todosDetail
        case .settings:
            SettingsView(controller: controller)
        }
    }

    @ViewBuilder
    private var meetingsDetail: some View {
        Group {
            if controller.showsMeetingsEmpty {
                VStack(spacing: DesignSpacing.lg) {
                    EmptyStateView(content: controller.meetingsEmptyState)
                    Button("Start recording") {
                        controller.select(.record)
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                }
            } else {
                List(controller.meetingPresentations) { item in
                    VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                        Text(item.title)
                            .font(.headline)
                        HStack(spacing: DesignSpacing.sm) {
                            Text(item.statusLabel)
                            Text("·")
                            Text(item.modeLabel)
                            Text("·")
                            Text(item.whenLabel)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(AppSection.meetings.title)
    }

    @ViewBuilder
    private var todosDetail: some View {
        Group {
            if controller.showsTodosEmpty {
                EmptyStateView(content: controller.todosEmptyState)
            } else {
                List(controller.todos) { todo in
                    VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                        Text(todo.title)
                            .font(.headline)
                        Text("From: \(todo.meetingTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(AppSection.todos.title)
    }
}
