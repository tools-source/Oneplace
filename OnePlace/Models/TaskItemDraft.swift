import Foundation

struct TaskItemDraft: Sendable {
    var title: String = ""
    var notes: String? = nil
    var priority: TaskPriority = .normal
    var dueDate: Date? = nil
    var completed: Bool = false
    var reminderEnabled: Bool = false
    var reminderDate: Date? = nil
    var reminderRepeat: ReminderRepeat = .oneTime
}
