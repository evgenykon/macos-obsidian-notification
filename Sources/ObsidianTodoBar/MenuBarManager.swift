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

    let popoverWidth: CGFloat = 380
    let popoverHeight: CGFloat = 520

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
                onReloadPrompt: { [weak self] in self?.reloadPrompt() },
                onEditPrompt: { [weak self] in self?.editPrompt() },
                onOpenTasksFolder: { [weak self] in self?.openTasksFolder() },
                onMarkDone: { [weak self] task in self?.markDone(task: task) }
            )
        )
    }

    private func buildMenu() -> NSMenu {
        let m = NSMenu()

        let reloadItem = NSMenuItem(title: "Reload prompt", action: #selector(reloadPrompt), keyEquivalent: "r")
        reloadItem.target = self
        m.addItem(reloadItem)

        let editItem = NSMenuItem(title: "Edit prompt in Obsidian", action: #selector(editPrompt), keyEquivalent: "e")
        editItem.target = self
        m.addItem(editItem)

        m.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        m.addItem(settingsItem)

        let folderItem = NSMenuItem(title: "Open tasks folder", action: #selector(openTasksFolder), keyEquivalent: "o")
        folderItem.target = self
        m.addItem(folderItem)

        m.addItem(.separator())

        let testItem = NSMenuItem(title: "🔔 Test notification", action: #selector(testNotification), keyEquivalent: "t")
        testItem.target = self
        m.addItem(testItem)

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
