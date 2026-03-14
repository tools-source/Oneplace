import Foundation
import FirebaseAuth
import UserNotifications

@MainActor
final class FlowViewModel: ObservableObject {

    // UI State
    @Published private(set) var items: [FlowItemRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let repo: FlowRepository
    private let notificationCenter: UNUserNotificationCenter

    init(
        repo: FlowRepository? = nil,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.repo = repo ?? FlowRepository()
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public API

    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            items = []
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await repo.fetchItems(for: uid)
            await syncReminders(for: items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(draft: FlowItemDraft) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.createItem(for: uid, draft: draft)
            items = try await repo.fetchItems(for: uid)
            await syncReminders(for: items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateItem(_ item: FlowItemRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updateItem(item)
            guard let uid = Auth.auth().currentUser?.uid else { return }
            items = try await repo.fetchItems(for: uid)
            await syncReminders(for: items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: FlowItemRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deleteItem(item)
            items.removeAll { $0.id == item.id }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier(for: item)])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleStatus(for item: FlowItemRecord) async {
        errorMessage = nil

        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let original = items[index]
        items[index].status = items[index].status == .paid ? .upcoming : .paid

        do {
            try await repo.updateItem(items[index])
            await syncReminder(for: items[index])
        } catch {
            items[index] = original
            errorMessage = error.localizedDescription
        }
    }

    private func syncReminders(for items: [FlowItemRecord]) async {
        for item in items {
            await syncReminder(for: item)
        }
    }

    private func syncReminder(for item: FlowItemRecord) async {
        let identifier = reminderIdentifier(for: item)

        guard item.reminderEnabled, item.status != .paid else {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        guard let trigger = reminderTrigger(for: item) else {
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
        content.title = item.type == .income ? "Income reminder" : "Bill reminder"
        content.body = item.type == .income
            ? "\(item.title) is coming up."
            : "\(item.title) is due soon."
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
        } catch {
            return
        }
    }

    private func reminderTrigger(for item: FlowItemRecord) -> UNCalendarNotificationTrigger? {
        let reminderDate = resolvedReminderDate(for: item)
        let calendar = Calendar.current

        switch item.reminderRepeat {
        case .none:
            guard reminderDate > Date() else { return nil }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: reminderDate)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        case .weekly:
            let components = calendar.dateComponents([.weekday, .hour, .minute], from: reminderDate)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        case .monthly:
            let components = calendar.dateComponents([.day, .hour, .minute], from: reminderDate)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
    }

    private func resolvedReminderDate(for item: FlowItemRecord) -> Date {
        if let reminderDate = item.reminderDate {
            return reminderDate
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: item.nextDueDate)
        components.hour = item.reminderHour ?? 9
        components.minute = item.reminderMinute ?? 0
        return Calendar.current.date(from: components) ?? item.nextDueDate
    }

    private func reminderIdentifier(for item: FlowItemRecord) -> String {
        "flow-reminder-\(item.ownerUserId)-\(item.id)"
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}
