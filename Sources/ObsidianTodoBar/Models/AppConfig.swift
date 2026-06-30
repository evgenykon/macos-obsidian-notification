import Foundation

struct AppConfig: Sendable {
    var vaultPath: String
    var tasksFolder: String
    var promptFile: String
    var historyFilePattern: String
    var apiKey: String
    var model: String
    var baseURL: String
    var checkInterval: TimeInterval

    static func load() -> AppConfig {
        let defaults = UserDefaults.standard
        let env = ProcessInfo.processInfo.environment

        func envOrUserDefaults(key: String, envKey: String, fallback: String) -> String {
            if let saved = defaults.string(forKey: key), !saved.isEmpty {
                return saved
            }
            return env[envKey] ?? fallback
        }

        let checkInterval: TimeInterval
        if defaults.object(forKey: "checkInterval") != nil {
            checkInterval = defaults.double(forKey: "checkInterval")
        } else if let envVal = env["CHECK_INTERVAL"], let val = TimeInterval(envVal) {
            checkInterval = val
        } else {
            checkInterval = 30
        }

        return AppConfig(
            vaultPath: envOrUserDefaults(key: "vaultPath", envKey: "OBSIDIAN_VAULT_PATH", fallback: ""),
            tasksFolder: envOrUserDefaults(key: "tasksFolder", envKey: "TASKS_FOLDER", fallback: "Inbox/tasks"),
            promptFile: envOrUserDefaults(key: "promptFile", envKey: "PROMPT_FILE", fallback: "Inbox/tasks/_prompt_task.md"),
            historyFilePattern: envOrUserDefaults(key: "historyFilePattern", envKey: "HISTORY_FILE_PATTERN", fallback: "Inbox/tasks/history-{date}.md"),
            apiKey: envOrUserDefaults(key: "apiKey", envKey: "OPENROUTER_API_KEY", fallback: ""),
            model: envOrUserDefaults(key: "model", envKey: "AI_MODEL", fallback: "openai/gpt-4o-mini"),
            baseURL: envOrUserDefaults(key: "baseURL", envKey: "AI_BASE_URL", fallback: "https://openrouter.ai/api/v1"),
            checkInterval: checkInterval
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
    }

    var tasksFolderURL: URL {
        URL(fileURLWithPath: vaultPath).appendingPathComponent(tasksFolder)
    }
}
