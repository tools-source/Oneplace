import Foundation
import SwiftData

@MainActor
final class MigrationManager: ObservableObject {
    enum Decision: String {
        case undecided
        case migrated
        case keepLocal
    }

    @Published var shouldShowPrompt = false
    @Published var isMigrating = false
    @Published var migrationError: String?

    private let localContainer: ModelContainer
    private let cloudContainer: ModelContainer
    private let onSwitchToCloud: (ModelContainer) -> Void

    private static let decisionKey = "cloudMigrationDecision"

    init(
        localContainer: ModelContainer,
        cloudContainer: ModelContainer,
        onSwitchToCloud: @escaping (ModelContainer) -> Void = { _ in }
    ) {
        self.localContainer = localContainer
        self.cloudContainer = cloudContainer
        self.onSwitchToCloud = onSwitchToCloud
    }

    static func loadDecision() -> Decision {
        guard let rawValue = UserDefaults.standard.string(forKey: decisionKey) else {
            return .undecided
        }
        return Decision(rawValue: rawValue) ?? .undecided
    }

    func keepLocalOnly() {
        saveDecision(.keepLocal)
        shouldShowPrompt = false
    }

    func migrateToCloud() async {
        isMigrating = true
        defer { isMigrating = false }

        let localContext = ModelContext(localContainer)
        let cloudContext = ModelContext(cloudContainer)

        do {
            try migrateFinance(from: localContext, to: cloudContext)
            try migrateTasks(from: localContext, to: cloudContext)
            try migrateFlows(from: localContext, to: cloudContext)
            try migrateComms(from: localContext, to: cloudContext)
            try migrateSplitModels(from: localContext, to: cloudContext)
            try cloudContext.save()

            saveDecision(.migrated)
            shouldShowPrompt = false
            onSwitchToCloud(cloudContainer)
            cleanupLocalStore()
        } catch {
            migrationError = "Failed to move local data to iCloud."
        }
    }

    func clearError() {
        migrationError = nil
    }

    private func saveDecision(_ decision: Decision) {
        UserDefaults.standard.set(decision.rawValue, forKey: Self.decisionKey)
    }

    private func migrateFinance(from localContext: ModelContext, to cloudContext: ModelContext) throws {
        let localItems = try localContext.fetch(FetchDescriptor<FinanceEntry>())
        let existingIds = Set(try cloudContext.fetch(FetchDescriptor<FinanceEntry>()).map { $0.id })

        for entry in localItems where !existingIds.contains(entry.id) {
            let copy = FinanceEntry(
                id: entry.id,
                amount: entry.amount,
                type: entry.type,
                category: entry.category,
                entryDescription: entry.entryDescription,
                date: entry.date,
                urgency: entry.urgency
            )
            cloudContext.insert(copy)
        }
    }

    private func migrateTasks(from localContext: ModelContext, to cloudContext: ModelContext) throws {
        let localItems = try localContext.fetch(FetchDescriptor<TaskItem>())
        let existingIds = Set(try cloudContext.fetch(FetchDescriptor<TaskItem>()).map { $0.id })

        for item in localItems where !existingIds.contains(item.id) {
            let copy = TaskItem(
                id: item.id,
                title: item.title,
                notes: item.notes,
                priority: item.priority,
                dueDate: item.dueDate,
                completed: item.completed,
                reminderEnabled: item.reminderEnabled,
                reminderDate: item.reminderDate,
                notificationId: item.notificationId
            )
            cloudContext.insert(copy)
        }
    }

    private func migrateFlows(from localContext: ModelContext, to cloudContext: ModelContext) throws {
        let localItems = try localContext.fetch(FetchDescriptor<FlowItem>())
        let existingIds = Set(try cloudContext.fetch(FetchDescriptor<FlowItem>()).map { $0.id })

        for item in localItems where !existingIds.contains(item.id) {
            let copy = FlowItem(
                id: item.id,
                title: item.title,
                amount: item.amount,
                type: item.type,
                frequency: item.frequency,
                nextDueDate: item.nextDueDate,
                status: item.status,
                notes: item.notes,
                reminderEnabled: item.reminderEnabled,
                reminderDate: item.reminderDate,
                reminderTime: item.reminderTime,
                reminderRepeat: item.reminderRepeat,
                reminderOffsetDays: item.reminderOffsetDays,
                notificationId: item.notificationId
            )
            cloudContext.insert(copy)
        }
    }

    private func migrateComms(from localContext: ModelContext, to cloudContext: ModelContext) throws {
        let localItems = try localContext.fetch(FetchDescriptor<CommsCard>())
        let existingIds = Set(try cloudContext.fetch(FetchDescriptor<CommsCard>()).map { $0.id })

        for card in localItems where !existingIds.contains(card.id) {
            let copy = CommsCard(
                id: card.id,
                title: card.title,
                phrase: card.phrase,
                language: card.language,
                emoji: card.emoji,
                imageData: card.imageData,
                audioData: card.audioData
            )
            cloudContext.insert(copy)
        }
    }

    private func migrateSplitModels(from localContext: ModelContext, to cloudContext: ModelContext) throws {
        let localPeople = try localContext.fetch(FetchDescriptor<SplitPerson>())
        let cloudPeople = try cloudContext.fetch(FetchDescriptor<SplitPerson>())
        var personMap = Dictionary(uniqueKeysWithValues: cloudPeople.map { ($0.id, $0) })

        for person in localPeople where personMap[person.id] == nil {
            let copy = SplitPerson(id: person.id, name: person.name)
            cloudContext.insert(copy)
            personMap[person.id] = copy
        }

        let localExpenses = try localContext.fetch(FetchDescriptor<SplitExpense>())
        let existingExpenseIds = Set(try cloudContext.fetch(FetchDescriptor<SplitExpense>()).map { $0.id })

        for expense in localExpenses where !existingExpenseIds.contains(expense.id) {
            let participants = (expense.participants ?? []).compactMap { personMap[$0.id] }
            let paidBy = expense.paidBy.flatMap { personMap[$0.id] }
            let copy = SplitExpense(
                id: expense.id,
                title: expense.title,
                amount: expense.amount,
                date: expense.date,
                participants: participants,
                paidBy: paidBy
            )
            cloudContext.insert(copy)
        }
    }

    private func cleanupLocalStore() {
        guard let storeURL = localContainer.configurations.first?.url else { return }
        let fileManager = FileManager.default
        let relatedFiles = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
        for url in relatedFiles where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}

extension MigrationManager {
    static var preview: MigrationManager {
        let schema = AppSchema.shared
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = (try? ModelContainer(for: schema, configurations: [configuration]))
            ?? SampleData.makeFallbackContainer()
        return MigrationManager(localContainer: container, cloudContainer: container)
    }
}
