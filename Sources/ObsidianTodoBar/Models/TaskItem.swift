import Foundation

struct TaskItem: Identifiable, Sendable {
    let id: UUID
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var time: String?
    var filePath: String
    var lineNumber: Int
    var fileContent: String

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        time: String? = nil,
        filePath: String,
        lineNumber: Int,
        fileContent: String = ""
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.time = time
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
}
