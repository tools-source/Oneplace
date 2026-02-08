import Foundation
import UserNotifications

@available(iOS 15.0, *)
final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Handle error if needed
        }
    }
    
    func scheduleReminder(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool,
        calendarComponents: Set<Calendar.Component>?
    ) async {
        await requestAuthorization()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger: UNNotificationTrigger
        
        if repeats, let components = calendarComponents {
            var dateComponents = DateComponents()
            for component in components {
                switch component {
                case .year:
                    dateComponents.year = Calendar.current.component(.year, from: date)
                case .month:
                    dateComponents.month = Calendar.current.component(.month, from: date)
                case .day:
                    dateComponents.day = Calendar.current.component(.day, from: date)
                case .hour:
                    dateComponents.hour = Calendar.current.component(.hour, from: date)
                case .minute:
                    dateComponents.minute = Calendar.current.component(.minute, from: date)
                case .second:
                    dateComponents.second = Calendar.current.component(.second, from: date)
                default:
                    break
                }
            }
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        } else {
            var dateComponents = DateComponents()
            let calendar = Calendar.current
            dateComponents.year = calendar.component(.year, from: date)
            dateComponents.month = calendar.component(.month, from: date)
            dateComponents.day = calendar.component(.day, from: date)
            dateComponents.hour = calendar.component(.hour, from: date)
            dateComponents.minute = calendar.component(.minute, from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        }
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { error in
                // Could handle error if needed
                continuation.resume()
            }
        }
    }
    
    func cancelReminder(id: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
}
