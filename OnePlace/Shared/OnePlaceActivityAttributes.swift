import ActivityKit
import Foundation

struct OnePlaceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var tasks: [OnePlaceLiveTask]
        var totalOpenCount: Int
        var updatedAt: Date

        init(tasks: [OnePlaceLiveTask], totalOpenCount: Int? = nil, updatedAt: Date = .now) {
            self.tasks = tasks
            self.totalOpenCount = totalOpenCount ?? tasks.filter { !$0.isCompleted }.count
            self.updatedAt = updatedAt
        }
    }

    var title: String = "OnePlace"
}

enum OnePlaceDeepLink {
    static let scheme = "oneplace"

    /// Opens the app on the Tasks (Organizer) tab.
    static let tasks = URL(string: "\(scheme)://tasks")!

    /// Resolves an incoming deep link to the tab it should select, if any.
    static func tabRawValue(for url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        switch url.host {
        case "tasks": return "organizer"
        default: return nil
        }
    }
}

enum OnePlaceLivePriority: Int, Codable, Hashable, CaseIterable, Sendable {
    case none = 0
    case low = 1
    case normal = 2
    case high = 3
}

struct OnePlaceLiveTask: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var title: String
    var isCompleted: Bool
    var priority: OnePlaceLivePriority
    var dueDate: Date?
    var remindersID: String?

    init(
        id: String,
        title: String,
        isCompleted: Bool,
        priority: OnePlaceLivePriority = .normal,
        dueDate: Date? = nil,
        remindersID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.remindersID = remindersID
    }
}
