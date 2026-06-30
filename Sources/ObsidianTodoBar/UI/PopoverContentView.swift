import SwiftUI

struct PopoverContentView: View {
    let taskStore: TaskStore
    let onOpenSettings: () -> Void
    let onReloadPrompt: () -> Void
    let onEditPrompt: () -> Void
    let onOpenTasksFolder: () -> Void
    let onMarkDone: (TaskItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if taskStore.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if taskStore.tasks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Нет задач")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                TaskListView(
                    tasks: taskStore.tasks,
                    onMarkDone: onMarkDone
                )
            }

            if !taskStore.recentNotifications.isEmpty {
                Divider()
                NotificationHistoryView(notifications: taskStore.recentNotifications)
            }

            Divider()
            footerView
        }
        .frame(width: 380)
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "bell.badge")
                .foregroundColor(.accentColor)
            Text("AI Obsidian Todo Bar")
                .font(.headline)
            Spacer()
            Text("\(taskStore.tasks.filter { !$0.isDone }.count) active")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footerView: some View {
        HStack(spacing: 0) {
            Button("Reload prompt") {
                onReloadPrompt()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)

            Button("Edit prompt") {
                onEditPrompt()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)

            Spacer()

            Button("Open folder") {
                onOpenTasksFolder()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
