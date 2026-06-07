import ActivityKit
import Foundation

@MainActor
final class OnePlaceLiveActivityController {
    static let shared = OnePlaceLiveActivityController()

    private let maxVisibleTasks = 12
    private let lastStatusKey = "oneplace.liveActivity.lastStatus"
    private var updateTask: Task<Void, Never>?

    private init() {}

    var isRunning: Bool {
        !Activity<OnePlaceActivityAttributes>.activities.isEmpty
    }

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var lastStatus: String {
        UserDefaults.standard.string(forKey: lastStatusKey) ?? "Not started yet."
    }

    func startOrUpdate(with tasks: [TaskItemRecord]) {
        guard activitiesEnabled else {
            recordStatus("Live Activities are disabled for OnePlace in iOS Settings.")
            return
        }

        let liveTasks = liveTasksForUpdate(from: tasks)
        OnePlaceTaskCache.save(liveTasks)
        startOrUpdate(with: makeState(from: liveTasks))
    }

    func stopAll() async {
        for activity in Activity<OnePlaceActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        recordStatus("Stopped all Live Activities.")
    }

    private func startOrUpdate(with state: OnePlaceActivityAttributes.ContentState) {
        updateTask?.cancel()
        updateTask = Task {
            if let existing = Activity<OnePlaceActivityAttributes>.activities.first {
                await existing.update(ActivityContent(state: state, staleDate: nil))
                recordStatus("Updated Live Activity with \(state.totalOpenCount) open tasks.")
            } else {
                requestNewActivity(with: state)
            }
        }
    }

    private func requestNewActivity(with state: OnePlaceActivityAttributes.ContentState) {
        do {
            _ = try Activity.request(
                attributes: OnePlaceActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )

            recordStatus("Started Live Activity with \(state.totalOpenCount) open tasks.")
        } catch {
            recordStatus("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    private func liveTasksForUpdate(from tasks: [TaskItemRecord]) -> [OnePlaceLiveTask] {
        var liveTasks = tasks.map(\.liveActivityTask)

        guard OnePlaceTaskCache.hasRecentLockScreenToggle() else {
            return liveTasks
        }

        let cachedTasks = OnePlaceTaskCache.load()
        let cachedCompletion = Dictionary(
            uniqueKeysWithValues: cachedTasks.map { ($0.id, $0.isCompleted) }
        )

        liveTasks = liveTasks.map { task in
            var merged = task
            if let isCompleted = cachedCompletion[task.id] {
                merged.isCompleted = isCompleted
            }
            return merged
        }

        return liveTasks
    }

    private func makeState(from tasks: [OnePlaceLiveTask]) -> OnePlaceActivityAttributes.ContentState {
        let openTasks = sortedOpenTasks(tasks)
        return OnePlaceActivityAttributes.ContentState(
            tasks: Array(openTasks.prefix(maxVisibleTasks)),
            totalOpenCount: openTasks.count,
            updatedAt: .now
        )
    }

    private func sortedOpenTasks(_ tasks: [OnePlaceLiveTask]) -> [OnePlaceLiveTask] {
        tasks
            .filter { !$0.isCompleted }
            .sorted {
                if $0.priority != $1.priority {
                    return $0.priority.rawValue > $1.priority.rawValue
                }

                if let leftDue = $0.dueDate, let rightDue = $1.dueDate {
                    return leftDue < rightDue
                }

                if $0.dueDate != nil {
                    return true
                }

                if $1.dueDate != nil {
                    return false
                }

                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private func recordStatus(_ message: String) {
        UserDefaults.standard.set(message, forKey: lastStatusKey)
        print("OnePlace Live Activity: \(message)")
    }
}

extension TaskItemRecord {
    var liveActivityTask: OnePlaceLiveTask {
        OnePlaceLiveTask(
            id: id,
            title: title,
            isCompleted: completed,
            priority: priority.liveActivityPriority,
            dueDate: dueDate,
            remindersID: remindersID
        )
    }
}

private extension TaskPriority {
    var liveActivityPriority: OnePlaceLivePriority {
        switch self {
        case .low: return .low
        case .normal: return .normal
        case .high: return .high
        }
    }
}

