import Foundation
import SwiftData

@Model
final class SplitPerson {
    var id: UUID = UUID()
    var name: String = ""
    var expenses: [SplitExpense] = []
    var expensesPaid: [SplitExpense] = []

    init(id: UUID = UUID(), name: String = "", expenses: [SplitExpense] = [], expensesPaid: [SplitExpense] = []) {
        self.id = id
        self.name = name
        self.expenses = expenses
        self.expensesPaid = expensesPaid
    }
}

@Model
final class SplitExpense {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0
    var date: Date = Date()
    var participants: [SplitPerson] = []
    var paidBy: SplitPerson?

    init(id: UUID = UUID(), title: String = "", amount: Double = 0, date: Date = Date(), participants: [SplitPerson] = [], paidBy: SplitPerson? = nil) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.participants = participants
        self.paidBy = paidBy
    }
}
