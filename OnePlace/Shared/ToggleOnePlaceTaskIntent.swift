import ActivityKit
import AppIntents
import EventKit
import Foundation
import WidgetKit

struct ToggleOnePlaceTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle OnePlace Task"
    static var description = IntentDescription("Mark a OnePlace task complete or incomplete.")
    static var isDiscoverable = false
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Task ID")
    var taskID: String

    init() {
        taskID = ""
    }

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        var tasks = OnePlaceTaskCache.load()

        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else {
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }

        tasks[index].isCompleted.toggle()
        let updatedTask = tasks[index]

        OnePlaceTaskCache.save(tasks)
        OnePlaceTaskCache.markLockScreenToggle()

        let state = Self.makeState(from: tasks)
        for activity in Activity<OnePlaceActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }

        await updateReminderDirectly(for: updatedTask)
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }

    private func updateReminderDirectly(for task: OnePlaceLiveTask) async {
        guard let remindersID = task.remindersID,
              EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            return
        }

        let store = EKEventStore()
        guard let reminder = store.calendarItem(withIdentifier: remindersID) as? EKReminder else {
            return
        }

        reminder.isCompleted = task.isCompleted
        reminder.completionDate = task.isCompleted ? Date() : nil
        try? store.save(reminder, commit: true)
    }

    private static func makeState(from tasks: [OnePlaceLiveTask]) -> OnePlaceActivityAttributes.ContentState {
        let openTasks = sortedOpenTasks(from: tasks)
        return OnePlaceActivityAttributes.ContentState(
            tasks: Array(openTasks.prefix(12)),
            totalOpenCount: openTasks.count,
            updatedAt: .now
        )
    }

    private static func sortedOpenTasks(from tasks: [OnePlaceLiveTask]) -> [OnePlaceLiveTask] {
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
}

