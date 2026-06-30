import SwiftUI

struct SettingsView: View {
    @State private var vaultPath: String
    @State private var tasksFolder: String
    @State private var apiKey: String
    @State private var model: String
    @State private var startHour: Int
    @State private var endHour: Int

    let onSave: (AppConfig) -> Void
    let config: AppConfig

    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        _vaultPath = State(initialValue: config.vaultPath)
        _tasksFolder = State(initialValue: config.tasksFolder)
        _apiKey = State(initialValue: config.apiKey)
        _model = State(initialValue: config.model)
        _startHour = State(initialValue: config.notificationsStartHour)
        _endHour = State(initialValue: config.notificationsEndHour)
    }

    var body: some View {
        Form {
            Section("Obsidian Vault") {
                TextField("Vault path", text: $vaultPath)
                    .font(.body)
                TextField("Tasks folder", text: $tasksFolder)
                    .font(.body)
            }

            Section("OpenRouter AI") {
                SecureField("API Key", text: $apiKey)
                    .font(.body)
                TextField("Model", text: $model)
                    .font(.body)
                    .help("e.g. openai/gpt-4o-mini, claude-3-haiku")
            }

            Section("Notification window") {
                HStack {
                    Stepper("Start hour: \(startHour):00", value: $startHour, in: 0...23)
                }
                HStack {
                    Stepper("End hour: \(endHour):00", value: $endHour, in: 1...24)
                }
                Text("Notifications only between \(startHour):00 and \(endHour):00")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("Save") {
                    var newConfig = config
                    newConfig.vaultPath = vaultPath
                    newConfig.tasksFolder = tasksFolder
                    newConfig.apiKey = apiKey
                    newConfig.model = model
                    newConfig.notificationsStartHour = startHour
                    newConfig.notificationsEndHour = endHour
                    newConfig.save()
                    onSave(newConfig)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 460)
    }
}
