import Foundation
import SwiftData

@Model
final class SplitPerson {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
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
    @Relationship(deleteRule: .nullify) var participants: [SplitPerson]
    @Relationship(deleteRule: .nullify) var paidBy: SplitPerson?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date = Date(),
        participants: [SplitPerson] = [],
        paidBy: SplitPerson? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.participants = participants
        self.paidBy = paidBy
    }
}
