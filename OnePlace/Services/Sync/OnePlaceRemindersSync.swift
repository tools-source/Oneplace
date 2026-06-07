import EventKit
import Foundation
import UIKit
import WidgetKit

@MainActor
final class OnePlaceRemindersSync {
    static let shared = OnePlaceRemindersSync()

    private let store = EKEventStore()
    private let listName = "OnePlace Tasks"

    private init() {}

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    var hasAccess: Bool {
        authorizationStatus == .fullAccess
    }

    func requestAccessIfNeeded() async -> Bool {
        switch authorizationStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            do {
                return try await store.requestFullAccessToReminders()
            } catch {
                return false
            }
        default:
            return false
        }
    }

    func sync(
        ownerUserId: String,
        tasks: [TaskItemRecord],
        repository: TaskRepository,
        preferOnePlaceChanges: Bool = false
    ) async throws -> [TaskItemRecord] {
        guard await requestAccessIfNeeded(),
              let list = ensureList() else {
            return tasks
        }

        var currentTasks = tasks
        currentTasks = try await reconcileLiveActivityToggles(in: currentTasks, repository: repository)

        let reminders = await fetchReminders(in: list)
        var seenReminderIDs = Set<String>()
        var matchedTaskIDs = Set<String>()

        for reminder in reminders {
            let reminderID = reminder.calendarItemIdentifier
            seenReminderIDs.insert(reminderID)

            if let taskIndex = currentTasks.firstIndex(where: { $0.remindersID == reminderID }) {
                matchedTaskIDs.insert(currentTasks[taskIndex].id)

                if preferOnePlaceChanges {
                    if apply(task: currentTasks[taskIndex], to: reminder) {
                        try store.save(reminder, commit: false)
                    }
                } else {
                    var task = currentTasks[taskIndex]
                    if apply(reminder: reminder, to: &task) {
                        try await repository.updateTask(task)
                        currentTasks[taskIndex] = task
                    }
                }
                continue
            }

            if let taskIndex = bestTaskMatchIndex(
                for: reminder,
                in: currentTasks,
                excluding: matchedTaskIDs
            ) {
                var task = currentTasks[taskIndex]
                task.remindersID = reminderID

                if preferOnePlaceChanges {
                    if apply(task: task, to: reminder) {
                        try store.save(reminder, commit: false)
                    }
                } else {
                    _ = apply(reminder: reminder, to: &task)
                }

                try await repository.updateTask(task)
                currentTasks[taskIndex] = task
                matchedTaskIDs.insert(task.id)
            } else {
                let created = try await repository.createTask(
                    for: ownerUserId,
                    draft: draft(from: reminder),
                    remindersID: reminderID
                )
                currentTasks.append(created)
                matchedTaskIDs.insert(created.id)
            }
        }

        for taskIndex in currentTasks.indices {
            var task = currentTasks[taskIndex]

            if task.remindersID == nil {
                if let reminderID = createReminder(from: task, in: list) {
                    task.remindersID = reminderID
                    try await repository.updateTask(task)
                    currentTasks[taskIndex] = task
                }
                continue
            }

            guard let remindersID = task.remindersID,
                  !seenReminderIDs.contains(remindersID) else {
                continue
            }

            if let reminder = bestReminderMatch(for: task, in: reminders) {
                task.remindersID = reminder.calendarItemIdentifier

                if preferOnePlaceChanges {
                    if apply(task: task, to: reminder) {
                        try store.save(reminder, commit: false)
                    }
                } else {
                    _ = apply(reminder: reminder, to: &task)
                }

                try await repository.updateTask(task)
                currentTasks[taskIndex] = task
            } else {
                if let reminderID = createReminder(from: task, in: list) {
                    task.remindersID = reminderID
                    try await repository.updateTask(task)
                    currentTasks[taskIndex] = task
                }
            }
        }

        try? store.commit()
        OnePlaceTaskCache.save(currentTasks.map(\.liveActivityTask))
        WidgetCenter.shared.reloadAllTimelines()
        OnePlaceTaskCache.clearLockScreenToggle()

        return currentTasks.sortedForOrganizer()
    }

    func deleteReminder(withID remindersID: String) async {
        guard hasAccess,
              let reminder = store.calendarItem(withIdentifier: remindersID) as? EKReminder else {
            return
        }

        try? store.remove(reminder, commit: true)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func reconcileLiveActivityToggles(
        in tasks: [TaskItemRecord],
        repository: TaskRepository
    ) async throws -> [TaskItemRecord] {
        guard OnePlaceTaskCache.hasRecentLockScreenToggle() else {
            return tasks
        }

        let cachedCompletion = Dictionary(
            uniqueKeysWithValues: OnePlaceTaskCache.load().map { ($0.id, $0.isCompleted) }
        )

        var reconciled = tasks
        for index in reconciled.indices {
            guard let isCompleted = cachedCompletion[reconciled[index].id],
                  reconciled[index].completed != isCompleted else {
                continue
            }

            reconciled[index].completed = isCompleted
            try await repository.updateTask(reconciled[index])
        }

        return reconciled
    }

    private func ensureList() -> EKCalendar? {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == listName }) {
            return existing
        }

        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = listName
        calendar.cgColor = UIColor.systemTeal.cgColor

        if let source = store.defaultCalendarForNewReminders()?.source {
            calendar.source = source
        } else if let local = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = local
        } else if let source = store.sources.first {
            calendar.source = source
        } else {
            return nil
        }

        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }

    private func fetchReminders(in list: EKCalendar) async -> [EKReminder] {
        let predicate = store.predicateForReminders(in: [list])
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func createReminder(from task: TaskItemRecord, in list: EKCalendar) -> String? {
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        apply(task: task, to: reminder)

        do {
            try store.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            return nil
        }
    }

    private func draft(from reminder: EKReminder) -> TaskItemDraft {
        let dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }

        return TaskItemDraft(
            title: reminder.title ?? "Reminder",
            notes: reminder.notes,
            priority: priority(from: reminder.priority),
            dueDate: dueDate,
            completed: reminder.isCompleted,
            reminderEnabled: dueDate != nil,
            reminderDate: dueDate,
            reminderRepeat: .oneTime
        )
    }

    @discardableResult
    private func apply(task: TaskItemRecord, to reminder: EKReminder) -> Bool {
        var changed = false

        if reminder.title != task.title {
            reminder.title = task.title
            changed = true
        }
        if reminder.notes != task.notes {
            reminder.notes = task.notes
            changed = true
        }
        if reminder.isCompleted != task.completed {
            reminder.isCompleted = task.completed
            reminder.completionDate = task.completed ? Date() : nil
            changed = true
        }

        let reminderPriority = reminderPriority(from: task.priority)
        if reminder.priority != reminderPriority {
            reminder.priority = reminderPriority
            changed = true
        }

        let dueComponents = task.dueDate.map {
            Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
        }
        if reminder.dueDateComponents != dueComponents {
            reminder.dueDateComponents = dueComponents
            changed = true
        }

        return changed
    }

    @discardableResult
    private func apply(reminder: EKReminder, to task: inout TaskItemRecord) -> Bool {
        var changed = false

        if task.title != reminder.title {
            task.title = reminder.title ?? "Reminder"
            changed = true
        }
        if task.notes != reminder.notes {
            task.notes = reminder.notes
            changed = true
        }
        if task.completed != reminder.isCompleted {
            task.completed = reminder.isCompleted
            changed = true
        }

        let dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        if task.dueDate != dueDate {
            task.dueDate = dueDate
            changed = true
        }

        let mappedPriority = priority(from: reminder.priority)
        if task.priority != mappedPriority {
            task.priority = mappedPriority
            changed = true
        }

        return changed
    }

    private func bestTaskMatchIndex(
        for reminder: EKReminder,
        in tasks: [TaskItemRecord],
        excluding matchedTaskIDs: Set<String>
    ) -> Int? {
        let reminderTitle = normalizedTitle(reminder.title)
        let reminderDueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }

        return tasks.firstIndex { task in
            guard !matchedTaskIDs.contains(task.id),
                  task.remindersID == nil || task.remindersID != reminder.calendarItemIdentifier,
                  normalizedTitle(task.title) == reminderTitle else {
                return false
            }

            return datesMatch(task.dueDate, reminderDueDate)
        }
    }

    private func bestReminderMatch(for task: TaskItemRecord, in reminders: [EKReminder]) -> EKReminder? {
        let taskTitle = normalizedTitle(task.title)

        return reminders.first { reminder in
            normalizedTitle(reminder.title) == taskTitle &&
            datesMatch(task.dueDate, reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) })
        }
    }

    private func normalizedTitle(_ title: String?) -> String {
        (title ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func datesMatch(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return Calendar.current.isDate(lhs, inSameDayAs: rhs)
        default:
            return false
        }
    }

    private func priority(from raw: Int) -> TaskPriority {
        switch raw {
        case 1...3: return .high
        case 7...9: return .low
        default: return .normal
        }
    }

    private func reminderPriority(from priority: TaskPriority) -> Int {
        switch priority {
        case .high: return 1
        case .normal: return 5
        case .low: return 9
        }
    }
}
