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
        statusItem.button?.image = NSImage(systemSymbolName: "bell", accessibilityDescription: "Obsidian Todo Bar")
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                taskStore: taskStore,
                onOpenSettings: { [weak self] in self?.openSettings() },
                onReloadPrompt: { [weak self] in self?.reloadPrompt() },
                onEditPrompt: { [weak self] in self?.editPrompt() },
                onOpenTasksFolder: { [weak self] in self?.openTasksFolder() },
                onMarkDone: { [weak self] task in self?.markDone(task: task) }
            )
        )

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let reloadItem = NSMenuItem(title: "Reload prompt", action: #selector(reloadPrompt), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let editItem = NSMenuItem(title: "Edit prompt in Obsidian", action: #selector(editPrompt), keyEquivalent: "e")
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let folderItem = NSMenuItem(title: "Open tasks folder", action: #selector(openTasksFolder), keyEquivalent: "o")
        folderItem.target = self
        menu.addItem(folderItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }

    @objc private func reloadPrompt() {
        promptService = PromptService(config: config)
        print("Prompt reloaded")
    }

    @objc private func editPrompt() {
        let url = promptService.promptURL()
        guard let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        if let obsidianURL = URL(string: "obsidian://open?path=\(encodedPath)") {
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
