import Foundation
import SwiftData

@Model
final class SplitPerson {
    var id: UUID = UUID()
    var name: String = ""

    var expenses: [SplitExpense]?
    var expensesPaid: [SplitExpense]?
}

@Model
final class SplitExpense {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0
    var date: Date = Date()

    var participants: [SplitPerson]?
    var paidBy: SplitPerson?
}
