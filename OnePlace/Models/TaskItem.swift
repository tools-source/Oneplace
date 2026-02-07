import Foundation
import SwiftData

enum TaskPriority: String, CaseIterable, Codable {
    case low
    case normal
    case high
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var notes: String?
    var priority: TaskPriority
    var dueDate: Date?
    var completed: Bool

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        priority: TaskPriority = .normal,
        dueDate: Date? = nil,
        completed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.priority = priority
        self.dueDate = dueDate
        self.completed = completed
    }
}
