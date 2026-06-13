import BackgroundTasks
import EventKit
import FirebaseAuth
import Foundation
import WidgetKit

@MainActor
enum OnePlaceTaskSyncCoordinator {
    static let backgroundRefreshIdentifier = "com.one-place.app.tasks.refresh"

    @discardableResult
    static func syncCurrentUserTasks(preferOnePlaceChanges: Bool = false) async throws -> [TaskItemRecord] {
        guard let uid = Auth.auth().currentUser?.uid else {
            return []
        }

        return try await syncTasks(ownerUserId: uid, preferOnePlaceChanges: preferOnePlaceChanges)
    }

    @discardableResult
    static func syncTasks(ownerUserId: String, preferOnePlaceChanges: Bool = false) async throws -> [TaskItemRecord] {
        let repository = TaskRepository()
        let tasks = try await repository.fetchTasks(for: ownerUserId)
        let syncedTasks = try await OnePlaceRemindersSync.shared.sync(
            ownerUserId: ownerUserId,
            tasks: tasks,
            repository: repository,
            preferOnePlaceChanges: preferOnePlaceChanges
        )
        updateTaskSurfaces(with: syncedTasks)
        return syncedTasks
    }

    static func updateTaskSurfaces(with tasks: [TaskItemRecord]) {
        OnePlaceTaskCache.save(tasks.map(\.liveActivityTask))
        WidgetCenter.shared.reloadAllTimelines()
        OnePlaceLiveActivityController.shared.updateForCurrentPreference(with: tasks)
    }

    static func clearTaskSurfaces() async {
        OnePlaceTaskCache.clear()
        WidgetCenter.shared.reloadAllTimelines()
        await OnePlaceLiveActivityController.shared.stopAll()
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("OnePlace task background refresh scheduling failed: \(error.localizedDescription)")
        }
    }
}

@MainActor
final class OnePlaceRemindersChangeObserver {
    static let shared = OnePlaceRemindersChangeObserver()

    private var observer: NSObjectProtocol?
    private var pendingSyncTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncAfterBriefDelay()
            }
        }
    }

    private func syncAfterBriefDelay() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            guard !Task.isCancelled,
                  OnePlaceRemindersSync.shared.hasAccess else {
                return
            }

            do {
                try await OnePlaceTaskSyncCoordinator.syncCurrentUserTasks()
            } catch {
                print("OnePlace Reminders change sync failed: \(error.localizedDescription)")
            }
        }
    }
}
