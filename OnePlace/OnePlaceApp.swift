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
          do {
              container = try ModelContainer(for: schema)
          } catch {
              // Fallback to an in-memory container or handle the error gracefully
              let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
              container = try! ModelContainer(for: schema, configurations: configuration)
              // You could also log the error here
              print("Failed to create persistent ModelContainer. Falling back to in-memory. Error: \(error)")
          }

        // Ensure the anonymous ID is created early and persists across reinstalls via Keychain.
        let anonymousId = IdentityManager.shared.getOrCreateAnonymousId()
        print("AnonID:", anonymousId)
      }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
