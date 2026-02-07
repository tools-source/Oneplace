import Foundation
import SwiftData

enum FinanceType: String, CaseIterable, Codable {
    case gain
    case owe
}

enum FinanceUrgency: String, CaseIterable, Codable {
    case low
    case medium
    case high
}

@Model
final class FinanceEntry {
    var id: UUID
    var amount: Double
    var type: FinanceType
    var category: String
    var entryDescription: String
    var date: Date
    var urgency: FinanceUrgency

    init(
        id: UUID = UUID(),
        amount: Double,
        type: FinanceType,
        category: String,
        entryDescription: String,
        date: Date = Date(),
        urgency: FinanceUrgency = .medium
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.entryDescription = entryDescription
        self.date = date
        self.urgency = urgency
    }
}
