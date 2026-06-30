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
                notificationService: notificationService,
                onOpenSettings: { [weak self] in self?.openSettings() },
                onReloadPrompt: { [weak self] in self?.reloadPrompt() },
                onEditPrompt: { [weak self] in self?.editPrompt() },
                onOpenTasksFolder: { [weak self] in self?.openTasksFolder() },
                onMarkDone: { [weak self] task in self?.markDone(task: task) }
            )
        )

    }

    private var menu: NSMenu {
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

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)

        return m
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        let event = NSApp.currentEvent

        // Right-click or option-click → show context menu
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.option) == true {
            let m = menu
            m.popUp(positioning: nil, at: CGPoint(x: 0, y: button.bounds.height + 5), in: button)
            return
        }

        // Left-click → toggle popover
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { @MainActor in
                await notificationService.checkAuthorization()
            }
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
