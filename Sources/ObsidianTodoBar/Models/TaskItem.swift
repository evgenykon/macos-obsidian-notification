import Foundation

enum Recurring: String, Sendable {
    case daily
    case weekdays
    case weekly
    case monthly
}

struct TaskItem: Identifiable, Sendable {
    let id: String
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var time: String?
    var recurring: Recurring?
    var filePath: String
    var lineNumber: Int
    var fileContent: String

    init(
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        time: String? = nil,
        recurring: Recurring? = nil,
        filePath: String,
        lineNumber: Int,
        fileContent: String = ""
    ) {
        self.id = "\(filePath):\(lineNumber)"
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.time = time
        self.recurring = recurring
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.fileContent = fileContent
    }

    var effectiveDate: Date? {
        guard let dueDate else { return nil }
        if let time {
            let parts = time.split(separator: ":")
            if parts.count == 2,
               let hour = Int(parts[0]),
               let minute = Int(parts[1])
            {
                return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dueDate)
            }
        }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate)
    }

    var isOverdue: Bool {
        guard let effectiveDate else { return false }
        return effectiveDate < Date() && !isDone
    }

    var isDueToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueTomorrow: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }

    var checkboxPattern: String {
        isDone ? "- [x]" : "- [ ]"
    }

    var nextDueDate: Date? {
        guard let dueDate, let recurring else { return nil }
        let calendar = Calendar.current
        switch recurring {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekdays:
            let next = calendar.date(byAdding: .day, value: 1, to: dueDate)!
            let weekday = calendar.component(.weekday, from: next)
            if weekday == 7 {
                return calendar.date(byAdding: .day, value: 2, to: next)
            }
            if weekday == 1 {
                return calendar.date(byAdding: .day, value: 1, to: next)
            }
            return next
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: dueDate)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: dueDate)
        }
    }
}
