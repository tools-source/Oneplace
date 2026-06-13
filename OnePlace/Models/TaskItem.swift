import Foundation
import SwiftData

enum TaskPriority: String, CaseIterable, Codable {
    case low
    case normal
    case high
}

@Model
final class TaskItem {
    var id: UUID = UUID()
    var ownerUserId: String = ""
    var title: String = ""
    var notes: String?
    var priority: TaskPriority = TaskPriority.normal
    var manualOrder: Double?
    var dueDate: Date?
    var completed: Bool = false
    var reminderEnabled: Bool = false
    var reminderDate: Date?
    var notificationId: String = ""

    init(
        id: UUID = UUID(),
        ownerUserId: String,
        title: String = "",
        notes: String? = nil,
        priority: TaskPriority = TaskPriority.normal,
        manualOrder: Double? = nil,
        dueDate: Date? = nil,
        completed: Bool = false,
        reminderEnabled: Bool = false,
        reminderDate: Date? = nil,
        notificationId: String? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.title = title
        self.notes = notes
        self.priority = priority
        self.manualOrder = manualOrder
        self.dueDate = dueDate
        self.completed = completed
        self.reminderEnabled = reminderEnabled
        self.reminderDate = reminderDate
        self.notificationId = notificationId ?? id.uuidString
    }
}
