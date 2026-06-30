import Foundation

struct HistoryService {
    let config: AppConfig

    func append(notification: AINotification) throws {
        let url = try historyFileURL()

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "HH:mm"

        let timeString = dateFormatter.string(from: notification.timestamp)

        let entry = """
        ## ⏰ \(timeString) — \(notification.taskTitle)
        > *Модель: \(notification.model)*

        \(notification.aiMessage)

        ---

        """

        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            if let data = entry.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } else {
            try createHistoryFile(at: url, entry: entry)
        }
    }

    private func historyFileURL() throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        let fileName = config.historyFilePattern
            .replacingOccurrences(of: "{date}", with: dateString)

        return config.historyFolderURL.appendingPathComponent(fileName)
    }

    private func createHistoryFile(at url: URL, entry: String) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "EEEE, d MMMM yyyy"
        let dateString = dateFormatter.string(from: Date())

        let header = "# Уведомления — \(dateString)\n\n"
        try (header + entry).write(to: url, atomically: true, encoding: .utf8)
    }
}
