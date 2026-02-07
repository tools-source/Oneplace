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

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        type: FlowType,
        frequency: FlowFrequency,
        nextDueDate: Date = Date(),
        status: FlowStatus = .upcoming,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.status = status
        self.notes = notes
    }
}
