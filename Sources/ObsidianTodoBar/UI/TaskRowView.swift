import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onMarkDone: (TaskItem) -> Void

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

                if let time = task.time {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
