import Foundation
import SwiftData

enum SampleData {
    static let previewUserId = "preview-user"

    @MainActor static func makeContainer(inMemory: Bool = true) -> ModelContainer {
        let schema = AppSchema.schema
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            print("Failed to create sample data ModelContainer. Returning fallback container.")
            return makeFallbackContainer()
        }
        let context = container.mainContext

        let rent = FinanceEntry(ownerUserId: previewUserId, amount: 1200, type: FinanceType.owe, category: "Bills & Utilities", entryDescription: "April Rent", urgency: FinanceUrgency.high)
        let paycheck = FinanceEntry(ownerUserId: previewUserId, amount: 3200, type: FinanceType.gain, category: "Salary", entryDescription: "Monthly Pay", urgency: FinanceUrgency.low)
        context.insert(rent)
        context.insert(paycheck)

        let task = TaskItem(ownerUserId: previewUserId, title: "Renew insurance", notes: "Call agent", priority: TaskPriority.high, dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()))
        context.insert(task)

        let alex = SplitPerson(ownerUserId: previewUserId, name: "Alex")
        let jordan = SplitPerson(ownerUserId: previewUserId, name: "Jordan")
        let dinner = SplitExpense(ownerUserId: previewUserId, title: "Dinner", amount: 64)
        context.insert(alex)
        context.insert(jordan)
        context.insert(dinner)
        dinner.participants = [alex, jordan]
        dinner.paidBy = alex

        let card = CommsCard(ownerUserId: previewUserId, title: "Check-in", phrase: "How are you feeling today?", language: "English", emoji: "💬")
        context.insert(card)

        let bill = FlowItem(ownerUserId: previewUserId, title: "Internet", amount: 80, type: FlowType.bill, frequency: FlowFrequency.monthly, nextDueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date())
        context.insert(bill)

        return container
    }

    @MainActor static func makeFallbackContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: AppSchema.schema, configurations: [configuration]) {
            return container
        }

        print("Failed to create fallback ModelContainer with shared schema. Retrying in-memory creation.")
        return (try? ModelContainer(for: AppSchema.schema, configurations: [configuration]))
            ?? SampleData.makeContainer(inMemory: true)
    }
}
