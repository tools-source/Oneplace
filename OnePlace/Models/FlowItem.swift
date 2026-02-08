import Foundation
import SwiftData

enum FlowType: String, CaseIterable, Codable {
    case bill
    case income
}

enum FlowFrequency: String, CaseIterable, Codable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly
}

enum FlowStatus: String, CaseIterable, Codable {
    case upcoming
    case paid
    case skipped
}

enum ReminderRepeatRule: String, CaseIterable, Codable {
    case none
    case daily
    case weekly
    case monthly
}

@Model
final class FlowItem {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0
    var type: FlowType = FlowType.bill
    var frequency: FlowFrequency = FlowFrequency.monthly
    var nextDueDate: Date = Date()
    var status: FlowStatus = FlowStatus.upcoming
    var notes: String?
    var reminderEnabled: Bool = false
    var reminderDate: Date?
    var reminderHour: Int?
    var reminderMinute: Int?
    var reminderRepeat: ReminderRepeatRule = ReminderRepeatRule.none
    var reminderOffsetDays: Int = 0
    var notificationId: String = ""

    var reminderTime: DateComponents? {
        get {
            guard let reminderHour, let reminderMinute else { return nil }
            return DateComponents(hour: reminderHour, minute: reminderMinute)
        }
        set {
            reminderHour = newValue?.hour
            reminderMinute = newValue?.minute
        }
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        amount: Double = 0,
        type: FlowType = FlowType.bill,
        frequency: FlowFrequency = FlowFrequency.monthly,
        nextDueDate: Date = Date(),
        status: FlowStatus = FlowStatus.upcoming,
        notes: String? = nil,
        reminderEnabled: Bool = false,
        reminderDate: Date? = nil,
        reminderTime: DateComponents? = nil,
        reminderRepeat: ReminderRepeatRule = ReminderRepeatRule.none,
        reminderOffsetDays: Int = 0,
        notificationId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.status = status
        self.notes = notes
        self.reminderEnabled = reminderEnabled
        self.reminderDate = reminderDate
        self.reminderHour = reminderTime?.hour
        self.reminderMinute = reminderTime?.minute
        self.reminderRepeat = reminderRepeat
        self.reminderOffsetDays = reminderOffsetDays
        self.notificationId = notificationId ?? id.uuidString
    }
}
