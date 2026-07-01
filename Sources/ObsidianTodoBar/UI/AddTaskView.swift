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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleSection
                    Divider()
                    dateSection
                    Divider()
                    recurringSection
                    Divider()
                    checklistSection
                }
                .padding(20)
            }

            footer
        }
        .frame(width: 500, height: 580)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Название")
                .font(.headline)
            TextField("Например: Купить продукты", text: $data.title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Срок")
                .font(.headline)

            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Text("Дата:")
                        .foregroundColor(.secondary)
                    DatePicker(
                        selection: $data.dueDate,
                        in: Date()...,
                        displayedComponents: .date
                    ) {
                        EmptyView()
                    }
                    .datePickerStyle(.field)
                    .frame(width: 130)
                }

                HStack(spacing: 8) {
                    Toggle(isOn: $data.hasTime) {
                        Text("Время")
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .fixedSize()

                    if data.hasTime {
                        DatePicker(
                            selection: $data.time,
                            displayedComponents: .hourAndMinute
                        ) {
                            EmptyView()
                        }
                        .datePickerStyle(.field)
                        .frame(width: 80)
                    }
                }
            }
        }
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Повторение")
                .font(.headline)

            Picker("", selection: $data.recurring) {
                ForEach(AddTaskData.RecurringOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Чеклист")
                .font(.headline)

            if data.checklistItems.isEmpty {
                Text("Нет пунктов")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(Array(data.checklistItems.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Пункт \(index + 1)", text: $data.checklistItems[index].text)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        withAnimation {
                            let id = data.checklistItems[index].id
                            data.checklistItems.removeAll { $0.id == id }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(data.checklistItems.count > 1 ? 1 : 0)
                    .disabled(data.checklistItems.count <= 1)
                }
            }

            Button {
                withAnimation {
                    data.checklistItems.append(.init(text: ""))
                }
            } label: {
                Label("Добавить пункт", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Button("Отмена", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Создать задачу") {
                    onSave(data)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(data.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }
}
