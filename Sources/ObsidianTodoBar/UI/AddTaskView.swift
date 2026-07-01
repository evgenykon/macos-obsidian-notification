import SwiftUI

struct AddTaskData {
    var title: String = ""
    var dueDate: Date = Date()
    var hasTime: Bool = false
    var time: Date = Self.defaultTime
    var recurring: RecurringOption = .none
    var checklistItems: [ChecklistItem] = [ChecklistItem(text: "")]

    enum RecurringOption: String, CaseIterable, Sendable {
        case none = "Нет"
        case daily = "Ежедневно"
        case weekdays = "По будням"
        case weekly = "Еженедельно"
        case monthly = "Ежемесячно"

        var asRecurring: Recurring? {
            switch self {
            case .none: nil
            case .daily: .daily
            case .weekdays: .weekdays
            case .weekly: .weekly
            case .monthly: .monthly
            }
        }
    }

    struct ChecklistItem: Identifiable, Sendable {
        let id = UUID()
        var text: String
    }

    private static var defaultTime: Date {
        Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    }
}

struct AddTaskView: View {
    @State private var data = AddTaskData()
    let onSave: (AddTaskData) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    titleSection
                    dateSection
                    recurringSection
                    checklistSection
                }
            }

            footer
        }
        .padding(20)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title3)
            Text("Новая задача")
                .font(.headline)
            Spacer()
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Название").font(.caption).foregroundColor(.secondary)
            TextField("Введите название задачи", text: $data.title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var dateSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Срок").font(.caption).foregroundColor(.secondary)
                DatePicker(
                    selection: $data.dueDate,
                    in: Date()...,
                    displayedComponents: .date
                ) {
                    EmptyView()
                }
                .datePickerStyle(.field)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $data.hasTime) {
                    Text("Время").font(.caption).foregroundColor(.secondary)
                }
                if data.hasTime {
                    DatePicker(
                        selection: $data.time,
                        displayedComponents: .hourAndMinute
                    ) {
                        EmptyView()
                    }
                    .datePickerStyle(.field)
                }
            }
        }
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Повторение").font(.caption).foregroundColor(.secondary)
            Picker("", selection: $data.recurring) {
                ForEach(AddTaskData.RecurringOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Чеклист").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation { data.checklistItems.append(.init(text: "")) }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            VStack(spacing: 4) {
                ForEach(Array(data.checklistItems.enumerated()), id: \.element.id) { index, _ in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        TextField("Пункт \(index + 1)", text: $data.checklistItems[index].text)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                        if data.checklistItems.count > 1 {
                            Button {
                                withAnimation {
                                    let idx = data.checklistItems.index(data.checklistItems.startIndex, offsetBy: index)
                                    data.checklistItems.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Отмена", role: .cancel) {
                onCancel()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button("Сохранить") {
                onSave(data)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(data.title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
