import Foundation
import SwiftData

@Model
final class SplitPerson {
    var id: UUID = UUID()
    var name: String = ""
    @Relationship(deleteRule: .nullify, inverse: \SplitExpense.participants) var expenses: [SplitExpense]?
    @Relationship(deleteRule: .nullify, inverse: \SplitExpense.paidBy) var expensesPaid: [SplitExpense]?

    init(
        id: UUID = UUID(),
        name: String = ""
    ) {
        self.id = id
        self.name = name
    }
}

@Model
final class SplitExpense {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0
    var date: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \SplitPerson.expenses) var participants: [SplitPerson]?
    @Relationship(deleteRule: .nullify, inverse: \SplitPerson.expensesPaid) var paidBy: SplitPerson?

    init(
        id: UUID = UUID(),
        title: String = "",
        amount: Double = 0,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
    }
}
