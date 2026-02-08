import SwiftData

enum AppSchema {
    static let schema = Schema([
        FinanceEntry.self,
        FlowItem.self,
        TaskItem.self,
        SplitPerson.self,
        SplitExpense.self,
        CommsCard.self
    ])
}
