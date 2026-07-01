import Foundation

struct Frontmatter {
    var dueDate: Date?
    var time: String?
    var recurring: Recurring?
    var selectedWeekdays: Weekday = []
}

struct FrontmatterParser {

    func parse(from content: String) -> Frontmatter {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("---") else { return Frontmatter() }

        let withoutStart = trimmed.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let endRange = withoutStart.range(of: "\n---") ?? withoutStart.range(of: "\n---\n") else {
            return Frontmatter()
        }

        let frontmatterLines = withoutStart[..<endRange.lowerBound]
            .split(separator: "\n")
            .map(String.init)

        var dueDate: Date?
        var time: String?
        var recurring: Recurring?
        var selectedWeekdays = Weekday()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for line in frontmatterLines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            switch key {
            case "due", "date":
                if dateFormatter.date(from: value) != nil {
                    dueDate = dateFormatter.date(from: value)
                } else {
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                    dueDate = isoFormatter.date(from: value)
                }
            case "time":
                time = value
            case "recurring":
                recurring = Recurring.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
            case "days":
                let values = value
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                selectedWeekdays = Weekday.from(intValues: values)
            default:
                break
            }
        }

        return Frontmatter(
            dueDate: dueDate,
            time: time,
            recurring: recurring,
            selectedWeekdays: selectedWeekdays
        )
    }
}
