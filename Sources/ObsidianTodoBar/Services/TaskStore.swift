import Foundation
import Observation

@MainActor
@Observable
final class TaskStore {
    var tasks: [TaskItem] = []
    var recentNotifications: [AINotification] = []
    var isLoading = false
    var errorMessage: String?

    private var notifiedTaskIDs: Set<UUID> = []

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
        return tasks.filter { task in
            guard !task.isDone else { return false }
            guard !notifiedTaskIDs.contains(task.id) else { return false }
            guard let effectiveDate = task.effectiveDate else { return false }
            return effectiveDate <= now
        }
    }

    func markNotified(_ task: TaskItem) {
        notifiedTaskIDs.insert(task.id)
    }

    func addNotification(_ notification: AINotification) {
        recentNotifications.insert(notification, at: 0)
        if recentNotifications.count > 50 {
            recentNotifications = Array(recentNotifications.prefix(50))
        }
    }

    func markDone(task: TaskItem) throws {
        guard task.isDone == false else { return }

        let fileURL = config.tasksFolderURL.appendingPathComponent(task.filePath)
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
    }
}
