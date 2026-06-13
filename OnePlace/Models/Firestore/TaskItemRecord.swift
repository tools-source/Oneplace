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
    var manualOrder: Double?
    var dueDate: Date?
    var completed: Bool
    var reminderEnabled: Bool
    var reminderDate: Date?
    var reminderRepeat: ReminderRepeat
    var remindersID: String?
}

extension TaskPriority {
    var displayName: String {
        rawValue.capitalized
    }

    var sortRank: Int {
        switch self {
        case .high:
            return 0
        case .normal:
            return 1
        case .low:
            return 2
        }
    }
}

extension Array where Element == TaskItemRecord {
    func sortedForOrganizer() -> [TaskItemRecord] {
        sorted { lhs, rhs in
            if lhs.completed != rhs.completed {
                return !lhs.completed && rhs.completed
            }

            if lhs.priority != rhs.priority {
                return lhs.priority.sortRank < rhs.priority.sortRank
            }

            if let leftOrder = lhs.manualOrder,
               let rightOrder = rhs.manualOrder,
               leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

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

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
