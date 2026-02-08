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
    var id: UUID = UUID()
    var amount: Double = 0
    var type: FinanceType = .gain
    var category: String = "Uncategorized"
    var entryDescription: String = ""
    var date: Date = Date()
    var urgency: FinanceUrgency = .medium

    init(
        id: UUID = UUID(),
        amount: Double = 0,
        type: FinanceType = .gain,
        category: String = "Uncategorized",
        entryDescription: String = "",
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
