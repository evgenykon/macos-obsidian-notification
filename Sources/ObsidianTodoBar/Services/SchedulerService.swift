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
        tick()

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

        let dueTasks = taskStore.tasksNeedingNotification()

        for task in dueTasks {
            Task {
                await processNotification(for: task)
            }
        }

        isProcessing = false
    }

    private func processNotification(for task: TaskItem) async {
        guard config.isWithinNotificationWindow else {
            // Outside window — advance recurring tasks, mark non-recurring as notified
            if task.recurring != nil {
                try? taskStore.advanceRecurringTask(task)
            } else {
                taskStore.markNotified(task)
            }
            return
        }

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

            if task.recurring != nil {
                try taskStore.advanceRecurringTask(task)
            } else {
                taskStore.markNotified(task)
            }

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

            if task.recurring != nil {
                try? taskStore.advanceRecurringTask(task)
            } else {
                taskStore.markNotified(task)
            }
        }
    }
}
