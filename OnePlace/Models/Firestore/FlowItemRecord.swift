import Foundation

struct FlowItemRecord: Identifiable, Equatable {
    let id: String
    let ownerUserId: String
    var title: String
    var amount: Double
    var type: FlowType
    var frequency: FlowFrequency
    var nextDueDate: Date
    var status: FlowStatus
    var notes: String?
    var reminderEnabled: Bool
    var reminderDate: Date?
    var reminderHour: Int?
    var reminderMinute: Int?
    var reminderRepeat: ReminderRepeatRule
    var reminderOffsetDays: Int
}
