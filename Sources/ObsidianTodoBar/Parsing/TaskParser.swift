import Foundation

struct TaskParser {

    func parse(from content: String, filePath: String) -> [TaskItem] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var tasks: [TaskItem] = []

        for (index, line) in lines.enumerated() {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
            else { continue }

            let isDone = trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
            let title = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)

            guard !title.isEmpty else { continue }

            let frontmatterParser = FrontmatterParser()
            let frontmatter = frontmatterParser.parse(from: content)

            tasks.append(TaskItem(
                title: title,
                isDone: isDone,
                dueDate: frontmatter.dueDate,
                time: frontmatter.time,
                overrideTime: frontmatter.overrideTime,
                skipDate: frontmatter.skipDate,
                recurring: frontmatter.recurring,
                selectedWeekdays: frontmatter.selectedWeekdays,
                filePath: filePath,
                lineNumber: index + 1
            ))
        }

        return tasks
    }
}
