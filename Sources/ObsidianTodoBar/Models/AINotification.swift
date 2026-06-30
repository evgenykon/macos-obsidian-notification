import Foundation

struct AINotification: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    var taskTitle: String
    var aiMessage: String
    var model: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskTitle: String,
        aiMessage: String,
        model: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskTitle = taskTitle
        self.aiMessage = aiMessage
        self.model = model
    }
}
