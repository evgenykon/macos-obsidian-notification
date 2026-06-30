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

    static func loadFromEnv() -> AppConfig {
        let envDict = ProcessInfo.processInfo.environment

        func getEnv(_ key: String, default: String = "") -> String {
            envDict[key] ?? `default`
        }

        let checkInterval = TimeInterval(getEnv("CHECK_INTERVAL", default: "30")) ?? 30

        return AppConfig(
            vaultPath: getEnv("OBSIDIAN_VAULT_PATH"),
            tasksFolder: getEnv("TASKS_FOLDER", default: "Inbox/tasks"),
            promptFile: getEnv("PROMPT_FILE", default: "Inbox/tasks/_prompt.md"),
            historyFilePattern: getEnv("HISTORY_FILE_PATTERN", default: "Inbox/tasks/history-{date}.md"),
            apiKey: getEnv("OPENROUTER_API_KEY"),
            model: getEnv("AI_MODEL", default: "openai/gpt-4o-mini"),
            baseURL: getEnv("AI_BASE_URL", default: "https://openrouter.ai/api/v1"),
            checkInterval: checkInterval
        )
    }

    var tasksFolderURL: URL {
        URL(fileURLWithPath: vaultPath).appendingPathComponent(tasksFolder)
    }
}
