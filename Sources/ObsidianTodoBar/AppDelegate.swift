import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager!
    private var taskStore: TaskStore!
    private var schedulerService: SchedulerService!
    private var notificationService: NotificationService!
    private var config: AppConfig!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        config = AppConfig.load()

        taskStore = TaskStore(config: config)

        notificationService = NotificationService()

        // Request permission at startup — this registers the bundle with TCC
        Task { @MainActor in
            await notificationService.requestPermissionIfNeeded()
        }

        let aiService = AIService(config: config)
        let promptService = PromptService(config: config)
        let historyService = HistoryService(config: config)

        schedulerService = SchedulerService(
            taskStore: taskStore,
            config: config,
            aiService: aiService,
            promptService: promptService,
            notificationService: notificationService,
            historyService: historyService
        )

        menuBarManager = MenuBarManager()
        menuBarManager.setup(
            taskStore: taskStore,
            config: config,
            schedulerService: schedulerService,
            notificationService: notificationService,
            promptService: promptService
        )

        schedulerService.start()
    }
}
