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
                    HStack(alignment: .center) {
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
                        Spacer()
                        HStack(spacing: DesignSpacing.sm) {
                            if item.canTranscribe {
                                Button(item.transcribeButtonTitle) {
                                    controller.transcribeMeeting(id: item.id)
                                }
                                .buttonStyle(.bordered)
                                .disabled(controller.transcriptionProgress.phase.isInProgress)
                            }
                            if item.canProcess {
                                Button(item.processButtonTitle) {
                                    controller.processMeeting(id: item.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(controller.processingProgress.phase.isInProgress)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(AppSection.meetings.title)
        .sheet(isPresented: Binding(
            get: { controller.showTranscriptionSheet },
            set: { if !$0 { controller.dismissTranscriptionSheet() } }
        )) {
            TranscriptionProgressView(
                progress: controller.transcriptionProgress,
                errorMessage: controller.transcriptionError,
                onRetry: { controller.retryTranscription() },
                onDismiss: { controller.dismissTranscriptionSheet() }
            )
        }
        .sheet(isPresented: Binding(
            get: { controller.showProcessingSheet },
            set: { if !$0 { controller.dismissProcessingSheet() } }
        )) {
            ProviderChooserView(
                providers: controller.processingProviders,
                availableProviders: controller.processingAvailableProviders,
                progress: controller.processingProgress,
                errorMessage: controller.processingError,
                emptyHowTo: controller.processingEmptyHowTo,
                preferredID: controller.processingPreferredID,
                onSelect: { controller.selectProcessingProvider(id: $0) },
                onRetry: {
                    if controller.processingProgress.selectedProviderID != nil {
                        controller.retryProcessing()
                    } else {
                        controller.showProcessingChooserAgain()
                    }
                },
                onRefresh: { controller.refreshProcessingDiscovery() },
                onDismiss: { controller.dismissProcessingSheet() }
            )
        }
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
