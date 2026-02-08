import Foundation
import SwiftData

enum SampleData {
    @MainActor static func makeContainer(inMemory: Bool = true) -> ModelContainer {
        let schema = AppSchema.shared
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            print("Failed to create sample data ModelContainer. Returning fallback container.")
            return makeFallbackContainer()
        }
        let context = container.mainContext

        let rent = FinanceEntry(amount: 1200, type: .owe, category: "Bills & Utilities", entryDescription: "April Rent", urgency: .high)
        let paycheck = FinanceEntry(amount: 3200, type: .gain, category: "Salary", entryDescription: "Monthly Pay", urgency: .low)
        context.insert(rent)
        context.insert(paycheck)

        let task = TaskItem(title: "Renew insurance", notes: "Call agent", priority: .high, dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()))
        context.insert(task)

        let alex = SplitPerson(name: "Alex")
        let jordan = SplitPerson(name: "Jordan")
        let dinner = SplitExpense(title: "Dinner", amount: 64, participants: [alex, jordan], paidBy: alex)
        context.insert(alex)
        context.insert(jordan)
        context.insert(dinner)

        let card = CommsCard(title: "Check-in", phrase: "How are you feeling today?", language: "English", emoji: "💬")
        context.insert(card)

        let bill = FlowItem(title: "Internet", amount: 80, type: .bill, frequency: .monthly, nextDueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date())
        context.insert(bill)

        return container
    }

    static func makeFallbackContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: AppSchema.shared, configurations: [configuration]) {
            return container
        }

        print("Failed to create fallback ModelContainer with shared schema. Retrying in-memory creation.")
        return (try? ModelContainer(for: AppSchema.shared, configurations: [configuration]))
            ?? SampleData.makeContainer(inMemory: true)
    }
}
