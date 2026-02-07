import SwiftData
import SwiftUI

@main
struct OnePlaceApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([
            FinanceEntry.self,
            TaskItem.self,
            SplitPerson.self,
            SplitExpense.self,
            CommsCard.self,
            FlowItem.self
        ])
        container = try! ModelContainer(for: schema)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
