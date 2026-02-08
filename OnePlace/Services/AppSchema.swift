import SwiftData

enum AppSchema {
    static let shared = Schema([
        FinanceEntry.self,
        TaskItem.self,
        SplitPerson.self,
        SplitExpense.self,
        CommsCard.self,
        FlowItem.self
    ])
}
