import SwiftUI

struct HomeShellView: View {
    @StateObject private var controller: HomeShellController

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
            detail
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
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Reload meetings, todos, and settings from disk")
                    }
                }
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
            RecordingSessionView {
                controller.refresh()
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
