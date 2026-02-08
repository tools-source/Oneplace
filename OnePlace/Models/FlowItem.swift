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
    var id: UUID
    var title: String
    var amount: Double
    var type: FlowType
    var frequency: FlowFrequency
    var nextDueDate: Date
    var status: FlowStatus
    var notes: String?
    var reminderEnabled: Bool
    var reminderDate: Date?
    var reminderTime: DateComponents?
    var reminderRepeat: ReminderRepeatRule
    var reminderOffsetDays: Int
    var notificationId: String

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        type: FlowType,
        frequency: FlowFrequency,
        nextDueDate: Date = Date(),
        status: FlowStatus = .upcoming,
        notes: String? = nil,
        reminderEnabled: Bool = false,
        reminderDate: Date? = nil,
        reminderTime: DateComponents? = nil,
        reminderRepeat: ReminderRepeatRule = .none,
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
        self.reminderTime = reminderTime
        self.reminderRepeat = reminderRepeat
        self.reminderOffsetDays = reminderOffsetDays
        self.notificationId = notificationId ?? id.uuidString
    }
}
