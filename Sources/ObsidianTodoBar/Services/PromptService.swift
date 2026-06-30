import Foundation

struct PromptService {
    let config: AppConfig

    func readPrompt() throws -> String {
        let url = config.tasksFolderURL.appendingPathComponent(config.promptFile)

        if !FileManager.default.fileExists(atPath: url.path) {
            return defaultPrompt()
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    func substitute(prompt: String, tasks: [TaskItem], context: String) -> String {
        var result = prompt

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "EEEE, d MMMM yyyy, HH:mm"

        result = result.replacingOccurrences(of: "{dateTime}", with: dateFormatter.string(from: Date()))

        let taskStrings = tasks
            .filter { !$0.isDone }
            .prefix(10)
            .map { task -> String in
                var parts = ["- \(task.title)"]
                if let dueDate = task.dueDate {
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "ru_RU")
                    df.dateFormat = "d MMM"
                    parts.append("(\(df.string(from: dueDate)))")
                }
                return parts.joined(separator: " ")
            }
            .joined(separator: "\n")

        result = result.replacingOccurrences(of: "{tasks}", with: taskStrings)

        let contextLimit = 2000
        let truncatedContext = context.count > contextLimit
            ? String(context.prefix(contextLimit)) + "\n..."
            : context
        result = result.replacingOccurrences(of: "{context}", with: truncatedContext)

        return result
    }

    func promptURL() -> URL {
        config.tasksFolderURL.appendingPathComponent(config.promptFile)
    }

    private func defaultPrompt() -> String {
        """
        Ты — поддерживающий ассистент.

        Напиши короткое (2-4 предложения) тёплое сообщение, которое поможет
        мне понять, почему эти дела важны прямо сейчас и с чего начать.

        Контекст:
        - Дата и время: {dateTime}
        - Запланированные задачи: {tasks}
        - Контекст из заметок: {context}

        Правила:
        - Пиши на русском, обращайся на «ты»
        - Без списков и маркдауна
        - Без оценок вроде «отлично», «хорошо»
        - Только текст сообщения, без лишних слов
        """
    }
}
