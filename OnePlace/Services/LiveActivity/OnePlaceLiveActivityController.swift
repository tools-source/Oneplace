import ActivityKit
import Foundation
import UIKit

@MainActor
final class OnePlaceLiveActivityController {
    static let shared = OnePlaceLiveActivityController()

    private let maxVisibleTasks = 12
    private let lastStatusKey = "oneplace.liveActivity.lastStatus"
    private let userEnabledKey = "oneplace.liveActivity.userEnabled"
    private var updateTask: Task<Void, Never>?

    private init() {}

    var isRunning: Bool {
        Activity<OnePlaceActivityAttributes>.activities.contains {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var lastStatus: String {
        UserDefaults.standard.string(forKey: lastStatusKey) ?? "Not started yet."
    }

    var isUserEnabled: Bool {
        guard UserDefaults.standard.object(forKey: userEnabledKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: userEnabledKey)
    }

    func setUserEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: userEnabledKey)
        recordStatus(isEnabled ? "Live Activity is on." : "Live Activity is off.")
    }

    func startOrUpdate(with tasks: [TaskItemRecord]) {
        updateTask?.cancel()
        updateTask = Task {
            _ = await startOrUpdateAndWait(with: tasks)
        }
    }

    @discardableResult
    func startOrUpdateAndWait(with tasks: [TaskItemRecord]) async -> Bool {
        guard !Task.isCancelled else { return false }
        setUserEnabled(true)

        guard activitiesEnabled else {
            recordStatus("Live Activities are disabled for OnePlace in iOS Settings.")
            return false
        }

        let liveTasks = liveTasksForUpdate(from: tasks)
        OnePlaceTaskCache.save(liveTasks)
        return await performStartOrUpdate(with: makeState(from: liveTasks))
    }

    func updateForCurrentPreference(with tasks: [TaskItemRecord]) {
        let liveTasks = liveTasksForUpdate(from: tasks)
        OnePlaceTaskCache.save(liveTasks)

        guard isUserEnabled else {
            return
        }

        updateTask?.cancel()
        updateTask = Task {
            _ = await performStartOrUpdate(with: makeState(from: liveTasks))
        }
    }

    func stopAll() async {
        updateTask?.cancel()
        updateTask = nil
        for activity in Activity<OnePlaceActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        recordStatus("Stopped all Live Activities.")
    }

    func turnOff() async {
        setUserEnabled(false)
        await stopAll()
    }

    /// Restores a timed-out activity immediately, even while the network sync is pending.
    func restoreFromCacheIfEnabled() async {
        guard isUserEnabled, UIApplication.shared.applicationState == .active else { return }
        _ = await performStartOrUpdate(with: makeState(from: OnePlaceTaskCache.load()))
    }

    private func performStartOrUpdate(with state: OnePlaceActivityAttributes.ContentState) async -> Bool {
        guard !Task.isCancelled, isUserEnabled, activitiesEnabled else { return false }

        let activities = Activity<OnePlaceActivityAttributes>.activities
        if let existing = activities.first(where: { $0.activityState == .active || $0.activityState == .stale }) {
            await existing.update(ActivityContent(state: state, staleDate: nil))
            guard !Task.isCancelled, isUserEnabled else { return false }
            recordStatus("Updated Live Activity with \(state.totalOpenCount) open tasks.")
            return true
        }

        // iOS permits local starts in the foreground. Ended activities must never
        // be treated as updatable: they may still be visible on the Lock Screen.
        guard UIApplication.shared.applicationState == .active else {
            recordStatus("Ready to restart when you open OnePlace.")
            return false
        }
        // Request before the first suspension point so concurrent refreshes see
        // the new activity instead of creating duplicates.
        let started = requestNewActivity(with: state)
        if started {
            for activity in activities where activity.activityState == .ended {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        return started
    }

    private func requestNewActivity(with state: OnePlaceActivityAttributes.ContentState) -> Bool {
        do {
            _ = try Activity<OnePlaceActivityAttributes>.request(
                attributes: OnePlaceActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )

            recordStatus("Started Live Activity with \(state.totalOpenCount) open tasks.")
            return true
        } catch {
            recordStatus("Failed to start Live Activity: \(error.localizedDescription)")
            return false
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

                if let leftOrder = $0.manualOrder,
                   let rightOrder = $1.manualOrder,
                   leftOrder != rightOrder {
                    return leftOrder < rightOrder
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
            manualOrder: manualOrder,
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
