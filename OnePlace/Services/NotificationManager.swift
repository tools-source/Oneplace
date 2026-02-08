import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleReminder(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool,
        calendarComponents: DateComponents? = nil
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components: DateComponents
        if let calendarComponents {
            components = calendarComponents
        } else {
            components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    func cancelReminder(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func listPendingReminders() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func notificationSettings() async -> UNNotificationSettings {
        await center.notificationSettings()
    }
}
