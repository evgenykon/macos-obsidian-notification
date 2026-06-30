import SwiftUI

struct TaskListView: View {
    let tasks: [TaskItem]
    let onMarkDone: (TaskItem) -> Void

    private var sections: [TaskSection] {
        let calendar = Calendar.current

        var overdue: [TaskItem] = []
        var today: [TaskItem] = []
        var tomorrow: [TaskItem] = []
        var upcoming: [TaskItem] = []
        var noDate: [TaskItem] = []

        for task in tasks where !task.isDone {
            if let dueDate = task.dueDate {
                if task.isOverdue {
                    overdue.append(task)
                } else if calendar.isDateInToday(dueDate) {
                    today.append(task)
                } else if calendar.isDateInTomorrow(dueDate) {
                    tomorrow.append(task)
                } else {
                    upcoming.append(task)
                }
            } else {
                noDate.append(task)
            }
        }

        var sections: [TaskSection] = []
        if !overdue.isEmpty { sections.append(TaskSection(title: "Просрочено", tasks: overdue, color: .red)) }
        if !today.isEmpty { sections.append(TaskSection(title: "Сегодня", tasks: today, color: .accentColor)) }
        if !tomorrow.isEmpty { sections.append(TaskSection(title: "Завтра", tasks: tomorrow, color: .orange)) }
        if !upcoming.isEmpty { sections.append(TaskSection(title: "Предстоящие", tasks: upcoming, color: .secondary)) }
        if !noDate.isEmpty { sections.append(TaskSection(title: "Без даты", tasks: noDate, color: .gray)) }

        return sections
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(section.color)
                                .frame(width: 8, height: 8)
                            Text(section.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text("(\(section.tasks.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ForEach(section.tasks) { task in
                            TaskRowView(task: task, onMarkDone: onMarkDone)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct TaskSection: Identifiable {
    let id = UUID()
    let title: String
    let tasks: [TaskItem]
    let color: Color
}
