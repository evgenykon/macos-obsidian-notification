import Foundation
import Observation

@MainActor
@Observable
final class TaskStore {
    var tasks: [TaskItem] = []
    var recentNotifications: [AINotification] = []
    var isLoading = false
    var errorMessage: String?

    private var notifiedTaskIDs: Set<String> = []

    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func refreshTasks() {
        isLoading = true
        errorMessage = nil

        do {
            let reader = VaultReader(config: config)
            let files = try reader.readAllTaskFiles()
            let parser = TaskParser()

            tasks = files.flatMap { file in
                parser.parse(from: file.content, filePath: file.path)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // Prune orphaned notified IDs (tasks deleted externally)
        let validIDs = Set(tasks.map(\.id))
        notifiedTaskIDs = notifiedTaskIDs.intersection(validIDs)

        isLoading = false
    }

    func tasksNeedingNotification() -> [TaskItem] {
        let now = Date()
        var seenFiles = Set<String>()

        return tasks.filter { task in
            guard !task.isDone else { return false }
            guard !task.isSkippedToday else { return false }
            guard !notifiedTaskIDs.contains(task.id) else { return false }
            guard let effectiveDate = task.effectiveDate else { return false }
            guard effectiveDate <= now else { return false }
            guard task.isMatchingWeekdayToday else { return false }
            // Only one notification per file
            guard !seenFiles.contains(task.filePath) else { return false }
            seenFiles.insert(task.filePath)
            return true
        }
    }

    func markNotified(_ task: TaskItem) {
        notifiedTaskIDs.insert(task.id)
    }

    func skipToday(_ task: TaskItem) throws {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        let fileURL = URL(fileURLWithPath: config.vaultPath).appendingPathComponent(task.filePath)
        var content = try String(contentsOf: fileURL, encoding: .utf8)

        if let range = content.range(of: "skipDate:") {
            let lineStart = range.lowerBound
            let lineEnd = content[lineStart...].firstIndex(of: "\n") ?? content.endIndex
            content.replaceSubrange(lineStart..<lineEnd, with: "skipDate: \(today)")
        } else {
            if let dueRange = content.range(of: "due:") {
                let lineEnd = content[dueRange.lowerBound...].firstIndex(of: "\n") ?? content.endIndex
                content.insert(contentsOf: "\nskipDate: \(today)", at: lineEnd)
            }
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        refreshTasks()
    }

    func postponeOneHour(_ task: TaskItem) throws {
        let calendar = Calendar.current
        let now = Date()
        let newHour = calendar.component(.hour, from: now.addingTimeInterval(3600))
        let newMinute = calendar.component(.minute, from: now.addingTimeInterval(3600))
        let newTime = String(format: "%02d:%02d", newHour, newMinute)

        let fileURL = URL(fileURLWithPath: config.vaultPath).appendingPathComponent(task.filePath)
        var content = try String(contentsOf: fileURL, encoding: .utf8)

        if let range = content.range(of: "overrideTime:") {
            let lineStart = range.lowerBound
            let lineEnd = content[lineStart...].firstIndex(of: "\n") ?? content.endIndex
            content.replaceSubrange(lineStart..<lineEnd, with: "overrideTime: \(newTime)")
        } else {
            if let dueRange = content.range(of: "due:") {
                let lineEnd = content[dueRange.lowerBound...].firstIndex(of: "\n") ?? content.endIndex
                content.insert(contentsOf: "\noverrideTime: \(newTime)", at: lineEnd)
            }
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        notifiedTaskIDs.remove(task.id)
        refreshTasks()
    }

    func advanceRecurringTask(_ task: TaskItem) throws {
        guard task.recurring != nil,
              let nextDate = task.nextDueDate
        else { return }

        let vaultRootURL = URL(fileURLWithPath: config.vaultPath)
        let fileURL = vaultRootURL.appendingPathComponent(task.filePath)
        var content = try String(contentsOf: fileURL, encoding: .utf8)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: task.dueDate ?? Date())
        let nextDateString = dateFormatter.string(from: nextDate)

        content = content.replacingOccurrences(
            of: "due: \(dateString)",
            with: "due: \(nextDateString)"
        )
        content = content.replacingOccurrences(
            of: "date: \(dateString)",
            with: "date: \(nextDateString)"
        )

        content = content.replacingOccurrences(of: "- [x]", with: "- [ ]")
        content = content.replacingOccurrences(of: "- [X]", with: "- [ ]")

        // Clear temporary override fields
        content = content.replacingOccurrences(
            of: "\nskipDate: \(dateString)",
            with: ""
        )
        content = content.replacingOccurrences(
            of: "\noverrideTime: \\d{2}:\\d{2}",
            with: "",
            options: .regularExpression
        )

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        notifiedTaskIDs.remove(task.id)
        refreshTasks()
    }

    func createTask(from data: AddTaskData) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let sanitized = data.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let fileURL = config.tasksFolderURL.appendingPathComponent("\(sanitized).md")

        let content = buildTaskContent(from: data, dateFormatter: dateFormatter)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        refreshTasks()
    }

    func updateTask(from data: AddTaskData) throws {
        guard let filePath = data.editingFilePath else { return }
        let fileURL = URL(fileURLWithPath: config.vaultPath).appendingPathComponent(filePath)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let content = buildTaskContent(from: data, dateFormatter: dateFormatter)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        notifiedTaskIDs = Set(notifiedTaskIDs.filter { !$0.hasPrefix(filePath) })
        refreshTasks()
    }

    private func buildTaskContent(from data: AddTaskData, dateFormatter: DateFormatter) -> String {
        var content = "---\n"
        content += "title: \(data.title)\n"
        content += "due: \(dateFormatter.string(from: data.dueDate))\n"
        if data.hasTime {
            let tf = DateFormatter()
            tf.dateFormat = "HH:mm"
            content += "time: \(tf.string(from: data.time))\n"
        }
        if let recurring = data.recurring.asRecurring {
            content += "recurring: \(recurring.rawValue)\n"
        }
        if data.recurring == .daysOfWeek {
            let days = data.selectedDays.fileFriendlyValues.joined(separator: ",")
            content += "days: \(days)\n"
        }
        content += "---\n\n"

        let items = data.checklistItems
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if items.isEmpty {
            content += "- [ ] \(data.title)\n"
        } else {
            for item in items {
                content += "- [ ] \(item)\n"
            }
        }

        return content
    }

    func addNotification(_ notification: AINotification) {
        recentNotifications.insert(notification, at: 0)
        if recentNotifications.count > 10 {
                recentNotifications = Array(recentNotifications.prefix(10))
        }
    }

    func markDone(task: TaskItem) throws {
        guard task.isDone == false else { return }

        let fileURL = URL(fileURLWithPath: config.vaultPath).appendingPathComponent(task.filePath)
        var content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        guard task.lineNumber <= lines.count else { return }

        var line = String(lines[task.lineNumber - 1])
        guard line.contains("- [ ]") else { return }

        line = line.replacingOccurrences(of: "- [ ]", with: "- [x]")
        var updatedLines = lines.map(String.init)
        updatedLines[task.lineNumber - 1] = line
        content = updatedLines.joined(separator: "\n")

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isDone = true
        }

        // Archive if all tasks in this file are done
        try archiveIfAllDone(fileURL: fileURL, vaultRelativePath: task.filePath)
    }

    func deleteTask(_ task: TaskItem) throws {
        let fileURL = URL(fileURLWithPath: config.vaultPath).appendingPathComponent(task.filePath)
        try FileManager.default.removeItem(at: fileURL)
        notifiedTaskIDs = Set(notifiedTaskIDs.filter { !$0.hasPrefix(task.filePath) })
        refreshTasks()
    }

    private func archiveIfAllDone(fileURL: URL, vaultRelativePath: String) throws {
        // Don't archive recurring files — they need to keep running
        let hasRecurring = tasks.contains { $0.filePath == vaultRelativePath && $0.recurring != nil }
        guard !hasRecurring else { return }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let hasOpenTask = content.contains("- [ ]")
        guard !hasOpenTask else { return }

        let archiveDir = URL(fileURLWithPath: config.vaultPath)
            .appendingPathComponent(config.archiveFolder)
        try FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        let fileName = (vaultRelativePath as NSString).lastPathComponent
        let destURL = archiveDir.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: fileURL, to: destURL)

        tasks.removeAll { $0.filePath == vaultRelativePath }
    }
}
