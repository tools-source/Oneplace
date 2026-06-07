import Foundation

enum ReminderRepeat: String, CaseIterable, Identifiable {
    case oneTime = "oneTime"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneTime: return "One time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

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
    var reminderRepeat: ReminderRepeat
    var remindersID: String?
}

extension Array where Element == TaskItemRecord {
    func sortedForOrganizer() -> [TaskItemRecord] {
        sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?):
                if left != right {
                    return left < right
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            if lhs.completed != rhs.completed {
                return !lhs.completed && rhs.completed
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
