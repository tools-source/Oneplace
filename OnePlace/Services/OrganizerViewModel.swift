import Foundation
import FirebaseAuth
import UserNotifications
import WidgetKit

@MainActor
final class OrganizerViewModel: ObservableObject {

    // UI State
    @Published private(set) var tasks: [TaskItemRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let repo: TaskRepository
    private let notificationCenter: UNUserNotificationCenter
    private let remindersSync: OnePlaceRemindersSync

    init(
        repo: TaskRepository? = nil,
        notificationCenter: UNUserNotificationCenter = .current(),
        remindersSync: OnePlaceRemindersSync? = nil
    ) {
        self.repo = repo ?? TaskRepository()
        self.notificationCenter = notificationCenter
        self.remindersSync = remindersSync ?? .shared
    }

    // MARK: - Public API

    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            tasks = []
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedTasks = try await repo.fetchTasks(for: uid)
            tasks = fetchedTasks
            await updateTaskIntegrations(ownerUserId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTask(draft: TaskItemDraft) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let createdTask = try await repo.createTask(for: uid, draft: draft)
            tasks.append(createdTask)
            tasks = tasks.sortedForOrganizer()
            await updateTaskIntegrations(ownerUserId: uid, preferOnePlaceChanges: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(_ task: TaskItemRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updateTask(task)
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let fetchedTasks = try await repo.fetchTasks(for: uid)
            tasks = fetchedTasks
            await updateTaskIntegrations(ownerUserId: uid, preferOnePlaceChanges: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTask(_ task: TaskItemRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deleteTask(task)
            tasks.removeAll { $0.id == task.id }
            if let remindersID = task.remindersID {
                await remindersSync.deleteReminder(withID: remindersID)
            }
            updateLiveActivityAndWidgetCache()
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier(for: task)])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCompletedTasks() async {
        let completedTasks = tasks.filter(\.completed)
        guard !completedTasks.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            for task in completedTasks {
                try await repo.deleteTask(task)
                if let remindersID = task.remindersID {
                    await remindersSync.deleteReminder(withID: remindersID)
                }
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier(for: task)])
            }

            tasks.removeAll(where: \.completed)
            updateLiveActivityAndWidgetCache()
        } catch {
            errorMessage = error.localizedDescription
            if let uid = Auth.auth().currentUser?.uid {
                tasks = (try? await repo.fetchTasks(for: uid)) ?? tasks
                await updateTaskIntegrations(ownerUserId: uid)
            }
        }
    }

    func toggleCompletion(for task: TaskItemRecord) async {
        errorMessage = nil

        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let original = tasks[index]
        tasks[index].completed.toggle()

        do {
            try await repo.updateTask(tasks[index])
            if let uid = Auth.auth().currentUser?.uid {
                await updateTaskIntegrations(ownerUserId: uid, preferOnePlaceChanges: true)
            } else {
                updateLiveActivityAndWidgetCache()
            }
            await syncReminder(for: tasks[index])
        } catch {
            tasks[index] = original
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Notifications

    private func updateTaskIntegrations(ownerUserId: String, preferOnePlaceChanges: Bool = false) async {
        do {
            tasks = try await remindersSync.sync(
                ownerUserId: ownerUserId,
                tasks: tasks,
                repository: repo,
                preferOnePlaceChanges: preferOnePlaceChanges
            )
        } catch {
            print("OnePlace task integrations sync failed: \(error.localizedDescription)")
        }

        updateLiveActivityAndWidgetCache()
        await syncReminders(for: tasks)
    }

    private func updateLiveActivityAndWidgetCache() {
        OnePlaceTaskSyncCoordinator.updateTaskSurfaces(with: tasks)
    }

    private func syncReminders(for tasks: [TaskItemRecord]) async {
        for task in tasks {
            await syncReminder(for: task)
        }
    }

    private func syncReminder(for task: TaskItemRecord) async {
        let identifier = reminderIdentifier(for: task)

        guard task.reminderEnabled, !task.completed,
              let reminderDate = task.reminderDate, reminderDate > Date() else {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .denied:
            return
        case .notDetermined:
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else { return }
            } catch {
                return
            }
        default:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = "Task reminder"
        content.body = task.title
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            return
        }
    }

    private func reminderIdentifier(for task: TaskItemRecord) -> String {
        "task-reminder-\(task.ownerUserId)-\(task.id)"
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}
