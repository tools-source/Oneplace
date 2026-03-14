import Foundation

struct TaskItemRecord: Identifiable, Equatable {
    let id: String
    let ownerUserId: String
    var title: String
    var notes: String?
    var priority: TaskPriority
    var dueDate: Date?
    var completed: Bool
    var reminderEnabled: Bool
    var reminderDate: Date?
}
