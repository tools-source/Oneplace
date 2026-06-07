import Foundation

struct FlowItemDraft: Sendable {
    var title: String = ""
    var amount: Double = 0
    var type: FlowType = .bill
    var frequency: FlowFrequency = .monthly
    var nextDueDate: Date = Date()
    var status: FlowStatus = .upcoming
    var notes: String? = nil
    var reminderEnabled: Bool = false
    var reminderDate: Date? = nil
    var reminderHour: Int? = nil
    var reminderMinute: Int? = nil
    var reminderRepeat: ReminderRepeatRule = .none
    var reminderOffsetDays: Int = 0
}
