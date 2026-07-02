import Foundation

enum Recurring: String, CaseIterable, Sendable {
    case daily
    case weekdays
    case weekly
    case monthly
    case daysOfWeek
}

struct Weekday: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let monday    = Weekday(rawValue: 1 << 0)
    static let tuesday   = Weekday(rawValue: 1 << 1)
    static let wednesday = Weekday(rawValue: 1 << 2)
    static let thursday  = Weekday(rawValue: 1 << 3)
    static let friday    = Weekday(rawValue: 1 << 4)
    static let saturday  = Weekday(rawValue: 1 << 5)
    static let sunday    = Weekday(rawValue: 1 << 6)

    static let weekdays: Weekday = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let all: Weekday = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var calendarWeekday: Int {
        switch self {
        case .monday:    return 2
        case .tuesday:   return 3
        case .wednesday: return 4
        case .thursday:  return 5
        case .friday:    return 6
        case .saturday:  return 7
        case .sunday:    return 1
        default:         return 0
        }
    }

    var fileFriendlyName: String {
        switch self {
        case .monday:    return "mon"
        case .tuesday:   return "tue"
        case .wednesday: return "wed"
        case .thursday:  return "thu"
        case .friday:    return "fri"
        case .saturday:  return "sat"
        case .sunday:    return "sun"
        default:         return ""
        }
    }

    var shortName: String {
        switch self {
        case .monday:    return "Пн"
        case .tuesday:   return "Вт"
        case .wednesday: return "Ср"
        case .thursday:  return "Чт"
        case .friday:    return "Пт"
        case .saturday:  return "Сб"
        case .sunday:    return "Вс"
        default:         return ""
        }
    }

    static func from(calendarWeekday: Int) -> Weekday? {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    static func fromFileFriendly(_ name: String) -> Weekday? {
        switch name.lowercased() {
        case "mon": return .monday
        case "tue": return .tuesday
        case "wed": return .wednesday
        case "thu": return .thursday
        case "fri": return .friday
        case "sat": return .saturday
        case "sun": return .sunday
        default: return nil
        }
    }

    static func from(intValues: [Int]) -> Weekday {
        var result: Weekday = []
        for v in intValues {
            switch v {
            case 1: result.insert(.sunday)
            case 2: result.insert(.monday)
            case 3: result.insert(.tuesday)
            case 4: result.insert(.wednesday)
            case 5: result.insert(.thursday)
            case 6: result.insert(.friday)
            case 7: result.insert(.saturday)
            default: break
            }
        }
        return result
    }

    var fileFriendlyValues: [String] {
        var result: [String] = []
        if contains(.monday)    { result.append("mon") }
        if contains(.tuesday)   { result.append("tue") }
        if contains(.wednesday) { result.append("wed") }
        if contains(.thursday)  { result.append("thu") }
        if contains(.friday)    { result.append("fri") }
        if contains(.saturday)  { result.append("sat") }
        if contains(.sunday)    { result.append("sun") }
        return result
    }
}

struct TaskItem: Identifiable, Sendable {
    let id: String
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var time: String?
    var overrideTime: String?
    var skipDate: String?
    var recurring: Recurring?
    var selectedWeekdays: Weekday
    var filePath: String
    var lineNumber: Int

    init(
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        time: String? = nil,
        overrideTime: String? = nil,
        skipDate: String? = nil,
        recurring: Recurring? = nil,
        selectedWeekdays: Weekday = [],
        filePath: String,
        lineNumber: Int
    ) {
        self.id = "\(filePath):\(lineNumber)"
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.time = time
        self.overrideTime = overrideTime
        self.skipDate = skipDate
        self.recurring = recurring
        self.selectedWeekdays = selectedWeekdays
        self.filePath = filePath
        self.lineNumber = lineNumber
    }

    var effectiveDate: Date? {
        guard let dueDate else { return nil }
        let effectiveTime = overrideTime ?? time
        if let effectiveTime {
            let parts = effectiveTime.split(separator: ":")
            if parts.count == 2,
               let hour = Int(parts[0]),
               let minute = Int(parts[1])
            {
                return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dueDate)
            }
        }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate)
    }

    var isOverdue: Bool {
        guard let effectiveDate else { return false }
        return effectiveDate < Date() && !isDone && isMatchingWeekdayToday
    }

    var isDueToday: Bool {
        guard let dueDate else { return false }
        guard Calendar.current.isDateInToday(dueDate) else { return false }
        return isMatchingWeekdayToday
    }

    var isDueTomorrow: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }

    var isMatchingWeekdayToday: Bool {
        guard recurring == .daysOfWeek else { return true }
        let today = Calendar.current.component(.weekday, from: Date())
        guard let weekday = Weekday.from(calendarWeekday: today) else { return false }
        return selectedWeekdays.contains(weekday)
    }

    var isSkippedToday: Bool {
        guard let skipDate else { return false }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date()) == skipDate
    }

    var checkboxPattern: String {
        isDone ? "- [x]" : "- [ ]"
    }

    var nextDueDate: Date? {
        guard let dueDate, let recurring else { return nil }
        let calendar = Calendar.current
        switch recurring {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekdays:
            let next = calendar.date(byAdding: .day, value: 1, to: dueDate)!
            let weekday = calendar.component(.weekday, from: next)
            if weekday == 7 {
                return calendar.date(byAdding: .day, value: 2, to: next)
            }
            if weekday == 1 {
                return calendar.date(byAdding: .day, value: 1, to: next)
            }
            return next
        case .daysOfWeek:
            let days = selectedWeekdays.isEmpty ? Weekday.weekdays : selectedWeekdays
            var candidate = calendar.date(byAdding: .day, value: 1, to: dueDate)!
            for _ in 0..<7 {
                let wd = calendar.component(.weekday, from: candidate)
                if let weekday = Weekday.from(calendarWeekday: wd), days.contains(weekday) {
                    return candidate
                }
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate)!
            }
            return nil
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: dueDate)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: dueDate)
        }
    }
}
