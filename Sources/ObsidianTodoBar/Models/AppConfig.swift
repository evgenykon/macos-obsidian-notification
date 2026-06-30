import Foundation

struct AppConfig: Sendable {
    var vaultPath: String
    var tasksFolder: String
    var promptFile: String
    var historyFolder: String
    var historyFilePattern: String
    var archiveFolder: String
    var apiKey: String
    var model: String
    var baseURL: String
    var checkInterval: TimeInterval
    var notificationsStartHour: Int
    var notificationsEndHour: Int

    static func load() -> AppConfig {
        let defaults = UserDefaults.standard
        let env = ProcessInfo.processInfo.environment

        func envOrUserDefaults(key: String, envKey: String, fallback: String) -> String {
            if let saved = defaults.string(forKey: key), !saved.isEmpty {
                return saved
            }
            return env[envKey] ?? fallback
        }

        func intEnvOrUserDefaults(key: String, envKey: String, fallback: Int) -> Int {
            if defaults.object(forKey: key) != nil {
                return defaults.integer(forKey: key)
            }
            if let val = env[envKey], let intVal = Int(val) {
                return intVal
            }
            return fallback
        }

        func migrate(_ key: String) -> String {
            let val = envOrUserDefaults(key: key, envKey: key, fallback: "")
            let prefix = "Inbox/tasks/"
            if val.hasPrefix(prefix) {
                return String(val.dropFirst(prefix.count))
            }
            return val
        }

        let checkInterval: TimeInterval
        if defaults.object(forKey: "checkInterval") != nil {
            checkInterval = defaults.double(forKey: "checkInterval")
        } else if let envVal = env["CHECK_INTERVAL"], let val = TimeInterval(envVal) {
            checkInterval = val
        } else {
            checkInterval = 30
        }

        let defaultPromptFile = "_prompt_task.md"
        let defaultHistoryPattern = "history-{date}.md"

        return AppConfig(
            vaultPath: envOrUserDefaults(key: "vaultPath", envKey: "OBSIDIAN_VAULT_PATH", fallback: ""),
            tasksFolder: envOrUserDefaults(key: "tasksFolder", envKey: "TASKS_FOLDER", fallback: "Inbox/tasks"),
            promptFile: migrate("promptFile").nilIfEmpty ?? defaultPromptFile,
            historyFolder: envOrUserDefaults(key: "historyFolder", envKey: "HISTORY_FOLDER", fallback: "Inbox/tasks"),
            historyFilePattern: migrate("historyFilePattern").nilIfEmpty ?? defaultHistoryPattern,
            archiveFolder: envOrUserDefaults(key: "archiveFolder", envKey: "ARCHIVE_FOLDER", fallback: "Archives/Задачи"),
            apiKey: envOrUserDefaults(key: "apiKey", envKey: "OPENROUTER_API_KEY", fallback: ""),
            model: envOrUserDefaults(key: "model", envKey: "AI_MODEL", fallback: "openai/gpt-4o-mini"),
            baseURL: envOrUserDefaults(key: "baseURL", envKey: "AI_BASE_URL", fallback: "https://openrouter.ai/api/v1"),
            checkInterval: checkInterval,
            notificationsStartHour: intEnvOrUserDefaults(key: "notificationsStartHour", envKey: "NOTIFICATIONS_START_HOUR", fallback: 9),
            notificationsEndHour: intEnvOrUserDefaults(key: "notificationsEndHour", envKey: "NOTIFICATIONS_END_HOUR", fallback: 18)
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(vaultPath, forKey: "vaultPath")
        defaults.set(tasksFolder, forKey: "tasksFolder")
        defaults.set(promptFile, forKey: "promptFile")
        defaults.set(historyFilePattern, forKey: "historyFilePattern")
        defaults.set(apiKey, forKey: "apiKey")
        defaults.set(model, forKey: "model")
        defaults.set(baseURL, forKey: "baseURL")
        defaults.set(checkInterval, forKey: "checkInterval")
        defaults.set(notificationsStartHour, forKey: "notificationsStartHour")
        defaults.set(notificationsEndHour, forKey: "notificationsEndHour")
        defaults.set(archiveFolder, forKey: "archiveFolder")
        defaults.set(historyFolder, forKey: "historyFolder")
    }

    var tasksFolderURL: URL {
        URL(fileURLWithPath: vaultPath).appendingPathComponent(tasksFolder)
    }

    var historyFolderURL: URL {
        URL(fileURLWithPath: vaultPath).appendingPathComponent(historyFolder)
    }

    var isWithinNotificationWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= notificationsStartHour && hour < notificationsEndHour
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
