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
        case .todos:
            todosDetail
        case .settings:
            SettingsView(controller: controller)
        }
    }

    @ViewBuilder
    private var meetingsDetail: some View {
        if controller.showsMeetingsEmpty {
            EmptyStateView(content: controller.meetingsEmptyState)
                .navigationTitle(AppSection.meetings.title)
        } else {
            List(controller.meetings) { meeting in
                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(meeting.title)
                        .font(.headline)
                    Text(meeting.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(AppSection.meetings.title)
        }
    }

    @ViewBuilder
    private var todosDetail: some View {
        if controller.showsTodosEmpty {
            EmptyStateView(content: controller.todosEmptyState)
                .navigationTitle(AppSection.todos.title)
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
            .navigationTitle(AppSection.todos.title)
        }
    }
}
