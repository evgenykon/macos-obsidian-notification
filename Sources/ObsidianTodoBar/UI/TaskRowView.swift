import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onMarkDone: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onSkipToday: (TaskItem) -> Void
    let onPostpone: (TaskItem) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onMarkDone(task)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isDone ? .green : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isDone)
                    .foregroundColor(task.isDone ? .secondary : .primary)
                    .lineLimit(2)

                if let overrideTime = task.overrideTime {
                    HStack(spacing: 4) {
                        if let time = task.time {
                            Text(time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .strikethrough()
                        }
                        Text(overrideTime)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                } else if let time = task.time {
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if task.isOverdue {
                Text("Просрочено")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }

            Menu {
                Button("Отменить сегодня", systemImage: "forward") {
                    onSkipToday(task)
                }
                Button("Перенести на час", systemImage: "clock.arrow.2.circlepath") {
                    onPostpone(task)
                }
                Divider()
                Button("Редактировать", systemImage: "pencil") {
                    onEdit(task)
                }
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    onDelete(task)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
