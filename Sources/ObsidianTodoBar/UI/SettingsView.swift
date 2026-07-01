import SwiftUI

struct SettingsView: View {
    @State private var vaultPath: String
    @State private var tasksFolder: String
    @State private var historyFolder: String
    @State private var archiveFolder: String
    @State private var apiKey: String
    @State private var model: String
    @State private var startHour: Int
    @State private var endHour: Int

    let onSave: (AppConfig) -> Void
    let onClose: () -> Void
    let onTestNotification: () -> Void
    let onForceNotify: () -> Void
    let config: AppConfig

    init(
        config: AppConfig,
        onSave: @escaping (AppConfig) -> Void,
        onClose: @escaping () -> Void,
        onTestNotification: @escaping () -> Void,
        onForceNotify: @escaping () -> Void
    ) {
        self.config = config
        self.onSave = onSave
        self.onClose = onClose
        self.onTestNotification = onTestNotification
        self.onForceNotify = onForceNotify
        _vaultPath = State(initialValue: config.vaultPath)
        _tasksFolder = State(initialValue: config.tasksFolder)
        _historyFolder = State(initialValue: config.historyFolder)
        _archiveFolder = State(initialValue: config.archiveFolder)
        _apiKey = State(initialValue: config.apiKey)
        _model = State(initialValue: config.model)
        _startHour = State(initialValue: config.notificationsStartHour)
        _endHour = State(initialValue: config.notificationsEndHour)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Obsidian Vault") {
                    TextField("Vault path", text: $vaultPath)
                    TextField("Tasks folder", text: $tasksFolder)
                    TextField("History folder", text: $historyFolder)
                    TextField("Archive folder", text: $archiveFolder)
                }

                section("OpenRouter AI") {
                    SecureField("API Key", text: $apiKey)
                    TextField("Model", text: $model)
                }

                section("Notification window") {
                    Stepper("Start hour: \(startHour):00", value: $startHour, in: 0...23)
                    Stepper("End hour: \(endHour):00", value: $endHour, in: 1...24)
                    Text("Notifications only between \(startHour):00 and \(endHour):00")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                section("Debug") {
                    HStack(spacing: 12) {
                        Button("🔔 Test notification") {
                            onTestNotification()
                        }
                        Button("▶ Force notify now") {
                            onForceNotify()
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Save") {
                        var newConfig = config
                        newConfig.vaultPath = vaultPath
                        newConfig.tasksFolder = tasksFolder
                        newConfig.historyFolder = historyFolder
                        newConfig.archiveFolder = archiveFolder
                        newConfig.apiKey = apiKey
                        newConfig.model = model
                        newConfig.notificationsStartHour = startHour
                        newConfig.notificationsEndHour = endHour
                        newConfig.save()
                        onSave(newConfig)
                        onClose()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 460)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(spacing: 6) {
                content()
            }
        }
    }
}
