import SwiftUI

struct PopoverContentView: View {
    @Bindable var taskStore: TaskStore
    let notificationService: NotificationService
    let onOpenSettings: () -> Void
    let onOpenHistory: () -> Void
    let onMarkDone: (TaskItem) -> Void
    let onAddTask: () -> Void
    let onEditTask: (TaskItem) -> Void
    let onDeleteTask: (TaskItem) -> Void

    private var todayTasks: [TaskItem] {
        taskStore.tasks.filter { !$0.isDone && ($0.isOverdue || $0.isDueToday) }
    }

    private var missedCount: Int {
        taskStore.tasks.filter { !$0.isDone && $0.isOverdue }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            if missedCount > 0 {
                missedBanner
            }
            Divider()

            notificationBannerIfNeeded

            VStack(spacing: 0) {
                if taskStore.isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                } else if todayTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("На сегодня нет задач")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    TaskListView(
                        tasks: todayTasks,
                        onMarkDone: onMarkDone,
                        onEdit: onEditTask,
                        onDelete: onDeleteTask
                    )
                }

                if !taskStore.recentNotifications.isEmpty {
                    Divider()
                    NotificationHistoryView(notifications: taskStore.recentNotifications, onTap: onOpenHistory)
                }
            }
            .frame(minHeight: 0, maxHeight: .infinity)

            Divider()
            footerView
        }
        .frame(width: 380)
    }

    @ViewBuilder
    private var notificationBannerIfNeeded: some View {
        switch notificationService.authorizationStatus {
        case .denied:
            notificationBanner(
                icon: "bell.slash",
                text: "Уведомления отключены",
                button: "Настройки",
                action: { NotificationService.openSystemSettings() }
            )
            Divider()
        case .notDetermined:
            notificationBanner(
                icon: "bell",
                text: "Разрешить уведомления?",
                button: "Включить",
                action: {
                    Task { @MainActor in
                        await notificationService.requestPermissionIfNeeded()
                    }
                }
            )
            Divider()
        default:
            EmptyView()
        }
    }

    private var missedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red)
            Text("Пропущено: \(missedCount)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.red)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.1))
    }

    private func notificationBanner(icon: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(text)
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
            Button(button) { action() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "bell.badge")
                .foregroundColor(.accentColor)
            Text("AI Obsidian Todo Bar")
                .font(.headline)
            Spacer()
            Button {
                onAddTask()
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .help("Добавить задачу")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footerView: some View {
        HStack {
            Spacer()
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
