import Foundation

@MainActor
final class SchedulerService {
    private var timer: Timer?
    private let taskStore: TaskStore
    private let config: AppConfig
    private let aiService: AIService
    private let promptService: PromptService
    private let notificationService: NotificationService
    private let historyService: HistoryService

    private var isProcessing = false

    init(
        taskStore: TaskStore,
        config: AppConfig,
        aiService: AIService,
        promptService: PromptService,
        notificationService: NotificationService,
        historyService: HistoryService
    ) {
        self.taskStore = taskStore
        self.config = config
        self.aiService = aiService
        self.promptService = promptService
        self.notificationService = notificationService
        self.historyService = historyService
    }

    func start() {
        taskStore.refreshTasks()

        // Delay first tick to next runloop so AppKit/SwiftUI finishes setup
        DispatchQueue.main.async { [weak self] in
            self?.tick()
        }

        timer = Timer.scheduledTimer(withTimeInterval: config.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isProcessing else { return }
        isProcessing = true

        taskStore.refreshTasks()

        // Advance recurring tasks that need it:
        //   1. Done tasks — reset checkbox and move to next date
        //   2. Tasks whose due date passed (yesterday or earlier) — catch up to today
        let todayStart = Calendar.current.startOfDay(for: Date())
        var advancedFiles = Set<String>()
        for task in taskStore.tasks where task.recurring != nil && !advancedFiles.contains(task.filePath) {
            guard let dueDate = task.dueDate else { continue }
            if task.isDone || dueDate < todayStart {
                try? taskStore.advanceRecurringTask(task)
                advancedFiles.insert(task.filePath)
            }
        }

        taskStore.refreshTasks()

        let dueTasks = taskStore.tasksNeedingNotification()

        // Mark siblings as notified to prevent double-fire on next tick.
        // Do NOT advance recurring tasks here — they stay on today's date so
        // the popover continues showing them after the notification fires.
        for task in dueTasks {
            for sibling in taskStore.tasks where sibling.filePath == task.filePath {
                taskStore.markNotified(sibling)
            }
        }

        // Now process notifications asynchronously
        for task in dueTasks {
            Task {
                await processNotification(for: task)
            }
        }

        isProcessing = false
    }

    private func processNotification(for task: TaskItem) async {
        guard config.isWithinNotificationWindow else { return }

        do {
            let promptTemplate = try promptService.readPrompt()
            let context = task.fileContent
            let prompt = promptService.substitute(
                prompt: promptTemplate,
                tasks: taskStore.tasks,
                context: context
            )

            let aiMessage = try await aiService.generateNotification(prompt: prompt)

            notificationService.show(
                title: task.title,
                body: aiMessage
            )

            let notification = AINotification(
                taskTitle: task.title,
                aiMessage: aiMessage,
                model: config.model
            )

            taskStore.addNotification(notification)

            try historyService.append(notification: notification)

        } catch {
            let fallback: String
            if let effectiveDate = task.effectiveDate {
                let df = DateFormatter()
                df.locale = Locale(identifier: "ru_RU")
                df.dateFormat = "HH:mm"
                fallback = "Напоминание: «\(task.title)» — \(df.string(from: effectiveDate))"
            } else {
                fallback = "Напоминание: «\(task.title)»"
            }

            notificationService.show(title: task.title, body: fallback)

            let notification = AINotification(
                taskTitle: task.title,
                aiMessage: fallback,
                model: "fallback"
            )

            taskStore.addNotification(notification)
        }
    }
}
