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

        isLoading = false
    }

    func tasksNeedingNotification() -> [TaskItem] {
        let now = Date()
        var seenFiles = Set<String>()

        return tasks.filter { task in
            guard !task.isDone else { return false }
            guard !notifiedTaskIDs.contains(task.id) else { return false }
            guard let effectiveDate = task.effectiveDate else { return false }
            guard effectiveDate <= now else { return false }
            // Only one notification per file
            guard !seenFiles.contains(task.filePath) else { return false }
            seenFiles.insert(task.filePath)
            return true
        }
    }

    func markNotified(_ task: TaskItem) {
        notifiedTaskIDs.insert(task.id)
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

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        refreshTasks()
    }

    func addNotification(_ notification: AINotification) {
        recentNotifications.insert(notification, at: 0)
        if recentNotifications.count > 50 {
            recentNotifications = Array(recentNotifications.prefix(50))
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
