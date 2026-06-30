import SwiftUI

struct SettingsView: View {
    @State private var vaultPath: String
    @State private var tasksFolder: String
    @State private var apiKey: String
    @State private var model: String

    let onSave: (AppConfig) -> Void
    let config: AppConfig

    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        _vaultPath = State(initialValue: config.vaultPath)
        _tasksFolder = State(initialValue: config.tasksFolder)
        _apiKey = State(initialValue: config.apiKey)
        _model = State(initialValue: config.model)
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

            HStack {
                Spacer()
                Button("Save") {
                    let newConfig = AppConfig(
                        vaultPath: vaultPath,
                        tasksFolder: tasksFolder,
                        promptFile: config.promptFile,
                        historyFilePattern: config.historyFilePattern,
                        apiKey: apiKey,
                        model: model,
                        baseURL: config.baseURL,
                        checkInterval: config.checkInterval
                    )
                    onSave(newConfig)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 460)
    }
}
