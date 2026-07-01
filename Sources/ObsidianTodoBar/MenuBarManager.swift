import AppKit
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var taskStore: TaskStore!
    private var config: AppConfig!
    private var schedulerService: SchedulerService!
    private var notificationService: NotificationService!
    private var promptService: PromptService!

    private var settingsWindow: NSWindow?
    private var addTaskWindow: NSWindow?

    let popoverWidth: CGFloat = 380
    let popoverHeight: CGFloat = 600

    func setup(
        taskStore: TaskStore,
        config: AppConfig,
        schedulerService: SchedulerService,
        notificationService: NotificationService,
        promptService: PromptService
    ) {
        self.taskStore = taskStore
        self.config = config
        self.schedulerService = schedulerService
        self.notificationService = notificationService
        self.promptService = promptService

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let image = NSImage(systemSymbolName: "bell", accessibilityDescription: "Obsidian Todo Bar")
        let customView = StatusBarButtonView(image: image)
        customView.onLeftClick = { [weak self] in self?.togglePopover() }
        customView.onRightClick = { [weak self] in self?.showMenu() }
        statusItem.view = customView

        popover = NSPopover()
        popover.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                taskStore: taskStore,
                notificationService: notificationService,
                onOpenSettings: { [weak self] in self?.openSettings() },
                onOpenHistory: { [weak self] in self?.openHistory() },
                onMarkDone: { [weak self] task in self?.markDone(task: task) },
                onAddTask: { [weak self] in self?.openAddTask() }
            )
        )
    }

    private func buildMenu() -> NSMenu {
        let m = NSMenu()

        let refreshItem = NSMenuItem(title: "🔄 Refresh tasks", action: #selector(refreshTasks), keyEquivalent: "")
        refreshItem.target = self
        m.addItem(refreshItem)

        m.addItem(.separator())

        let addTaskItem = NSMenuItem(title: "✏️ Add task...", action: #selector(openAddTask), keyEquivalent: "n")
        addTaskItem.target = self
        m.addItem(addTaskItem)

        let folderItem = NSMenuItem(title: "Open tasks folder", action: #selector(openTasksFolder), keyEquivalent: "o")
        folderItem.target = self
        m.addItem(folderItem)

        m.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        m.addItem(settingsItem)

        let testItem = NSMenuItem(title: "🔔 Test notification", action: #selector(testNotification), keyEquivalent: "t")
        testItem.target = self
        m.addItem(testItem)

        let forceItem = NSMenuItem(title: "▶ Force notify now", action: #selector(forceNotify), keyEquivalent: "f")
        forceItem.target = self
        m.addItem(forceItem)

        m.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)

        return m
    }

    private func showMenu() {
        let m = buildMenu()
        guard let view = statusItem.view else { return }
        m.popUp(positioning: nil, at: CGPoint(x: 0, y: view.bounds.height + 5), in: view)
    }

    @objc private func togglePopover() {
        guard let view = statusItem.view else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { @MainActor in
                await notificationService.checkAuthorization()
            }
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }

    @objc private func refreshTasks() {
        taskStore.refreshTasks()
    }

    @objc private func forceNotify() {
        let overdue = taskStore.tasks.filter { !$0.isDone && $0.isOverdue }
        if overdue.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Нет просроченных задач"
            alert.runModal()
            return
        }
        for task in overdue {
            notificationService.show(title: task.title, body: "Напоминание: задача просрочена")
        }
        let alert = NSAlert()
        alert.messageText = "Отправлено \(overdue.count) уведомлений"
        alert.runModal()
    }

    private func openHistory() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateString = df.string(from: Date())

        let fileName = (config.historyFolder as NSString).appendingPathComponent(
            config.historyFilePattern.replacingOccurrences(of: "{date}", with: dateString)
        )

        let vaultName = (config.vaultPath as NSString).lastPathComponent

        guard let encodedVault = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedFile = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "obsidian://open?vault=\(encodedVault)&file=\(encodedFile)")
        else { return }

        let alert = NSAlert()
        alert.messageText = "openHistory called"
        alert.informativeText = url.absoluteString
        alert.runModal()

        NSWorkspace.shared.open(url)
    }

    @objc private func testNotification() {
        Task { @MainActor in
            await notificationService.requestPermissionIfNeeded()
            let status = notificationService.authorizationStatus

            if status == .authorized {
                notificationService.show(title: "🧪 Тест", body: "Уведомления работают!")
                let alert = NSAlert()
                alert.messageText = "Уведомление отправлено"
                alert.informativeText = "Статус \(status.rawValue). Должно появиться в центре уведомлений."
                alert.runModal()
            } else {
                let alert = NSAlert()
                alert.messageText = "Статус: \(status.rawValue)"
                alert.informativeText = """
                UNAuthorizationStatus:
                0 = notDetermined
                1 = denied
                2 = authorized

                API возвращает \(status.rawValue). Если диалог не появился — \
                возможно система заблокировала запрос для этого бандла.
                """
                alert.runModal()
            }
        }
    }

    @objc private func reloadPrompt() {
        promptService = PromptService(config: config)
        print("Prompt reloaded")
    }

    @objc private func editPrompt() {
        let url = promptService.promptURL()
        let vaultName = (config.vaultPath as NSString).lastPathComponent
        let relativePath = url.path
            .replacingOccurrences(of: config.vaultPath, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let encodedFile = relativePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedVault = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return }

        if let obsidianURL = URL(string: "obsidian://open?vault=\(encodedVault)&file=\(encodedFile)") {
            NSWorkspace.shared.open(obsidianURL)
        }
    }

    @objc private func openSettings() {
        if settingsWindow?.isVisible == true {
            settingsWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(
            config: config,
            onSave: { [weak self] newConfig in
                self?.config = newConfig
                self?.restartScheduler()
            },
            onClose: { [weak self] in
                self?.settingsWindow?.orderOut(nil)
                self?.settingsWindow = nil
            }
        )

        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 480, height: 360))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAddTask() {
        if addTaskWindow?.isVisible == true {
            addTaskWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(
            rootView: AddTaskView(
                onSave: { [weak self] data in
                    guard let self else { return }
                    do {
                        try self.taskStore.createTask(from: data)
                        self.addTaskWindow?.orderOut(nil)
                        self.addTaskWindow = nil
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Ошибка при создании задачи"
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                },
                onCancel: { [weak self] in
                    self?.addTaskWindow?.orderOut(nil)
                    self?.addTaskWindow = nil
                }
            )
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Новая задача"
        window.setContentSize(NSSize(width: 500, height: 580))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false

        self.addTaskWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openTasksFolder() {
        let url = config.tasksFolderURL
        NSWorkspace.shared.open(url)
    }

    private func markDone(task: TaskItem) {
        do {
            try taskStore.markDone(task: task)
        } catch {
            print("Failed to mark done: \(error.localizedDescription)")
        }
    }

    private func restartScheduler() {
        schedulerService.stop()
        schedulerService = SchedulerService(
            taskStore: taskStore,
            config: config,
            aiService: AIService(config: config),
            promptService: PromptService(config: config),
            notificationService: notificationService,
            historyService: HistoryService(config: config)
        )
        schedulerService.start()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func hidePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
}

// MARK: - Status bar custom view

private final class StatusBarButtonView: NSView {
    private let imageView: NSImageView

    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    init(image: NSImage?) {
        self.imageView = NSImageView()
        super.init(frame: NSRect(x: 0, y: 0, width: 28, height: 22))
        self.imageView.image = image
        self.imageView.frame = bounds
        self.imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        onLeftClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
