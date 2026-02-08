import Foundation
import SwiftData

@Model
final class SplitPerson {
    var id: UUID = UUID()
    var ownerUserId: String = ""
    var name: String = ""
    var expenses: [SplitExpense] = []
    var expensesPaid: [SplitExpense] = []

    init(id: UUID = UUID(), ownerUserId: String, name: String = "", expenses: [SplitExpense] = [], expensesPaid: [SplitExpense] = []) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.name = name
        self.expenses = expenses
        self.expensesPaid = expensesPaid
    }
}

@Model
final class SplitExpense {
    var id: UUID = UUID()
    var ownerUserId: String = ""
    var title: String = ""
    var amount: Double = 0
    var date: Date = Date()
    var participants: [SplitPerson] = []
    var paidBy: SplitPerson?

    init(id: UUID = UUID(), ownerUserId: String, title: String = "", amount: Double = 0, date: Date = Date(), participants: [SplitPerson] = [], paidBy: SplitPerson? = nil) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.title = title
        self.amount = amount
        self.date = date
        self.participants = participants
        self.paidBy = paidBy
    }
}
