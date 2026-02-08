import Foundation
import SwiftData

@Model
final class SplitPerson {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .nullify, inverse: \SplitExpense.participants) var expenses: [SplitExpense] = []
    @Relationship(deleteRule: .nullify, inverse: \SplitExpense.paidBy) var expensesPaid: [SplitExpense] = []

    init(
        id: UUID = UUID(),
        name: String
    ) {
        self.id = id
        self.name = name
    }
}

@Model
final class SplitExpense {
    var id: UUID
    var title: String
    var amount: Double
    var date: Date
    @Relationship(deleteRule: .nullify, inverse: \SplitPerson.expenses) var participants: [SplitPerson] = []
    @Relationship(deleteRule: .nullify, inverse: \SplitPerson.expensesPaid) var paidBy: SplitPerson? = nil

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
    }
}
