import SwiftUI

/// Global todos list with filter, complete toggle, reminders, and meeting provenance.
struct TodosView: View {
    @ObservedObject var controller: HomeShellController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Filter", selection: filterBinding) {
                ForEach(TodoListFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], DesignSpacing.md)

            if let error = controller.todosLoadError ?? controller.todosActionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, DesignSpacing.md)
                    .padding(.top, DesignSpacing.sm)
            }

            Group {
                if controller.showsTodosEmpty {
                    EmptyStateView(content: controller.todosEmptyState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(controller.todoPresentations) { item in
                        todoRow(item)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle(AppSection.todos.title)
        .onAppear {
            controller.refreshTodos()
        }
    }

    private var filterBinding: Binding<TodoListFilter> {
        Binding(
            get: { controller.todoFilter },
            set: { controller.setTodoFilter($0) }
        )
    }

    @ViewBuilder
    private func todoRow(_ item: TodoListPresentation) -> some View {
        HStack(alignment: .top, spacing: DesignSpacing.sm) {
            Button {
                controller.setTodoCompleted(id: item.id, completed: !item.isCompleted)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(item.isCompleted ? "Mark incomplete" : "Mark complete")

            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    controller.openTodoSourceMeeting(todoID: item.id)
                } label: {
                    Label(item.provenanceLabel, systemImage: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Open source meeting review")

                if let reminder = item.reminderLabel {
                    Text(reminder)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !item.isCompleted {
                    HStack(spacing: DesignSpacing.sm) {
                        Menu("Remind") {
                            ForEach(TodoReminderPreset.allCases) { preset in
                                Button(preset.displayName) {
                                    controller.scheduleTodoReminder(id: item.id, preset: preset)
                                }
                            }
                        }
                        .menuStyle(.borderlessButton)

                        if item.hasReminder {
                            Button("Clear reminder") {
                                controller.clearTodoReminder(id: item.id)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .font(.caption)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
