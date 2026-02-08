import Foundation
import SwiftData

@MainActor
final class MigrationManager: ObservableObject {
    enum Decision: String {
        case notSet
        case keepLocal
        case keepCloud
    }

    @Published var shouldShowPrompt = false
    @Published var isMigrating = false
    @Published var migrationError: String?

    private let localContainer: ModelContainer
    private var cloudContainer: ModelContainer?
    private let onSwitchToCloud: (ModelContainer) -> Void

    private static let decisionKey = "cloudMigrationDecision"

    init(
        localContainer: ModelContainer,
        cloudContainer: ModelContainer?,
        onSwitchToCloud: @escaping (ModelContainer) -> Void = { _ in }
    ) {
        self.localContainer = localContainer
        self.cloudContainer = cloudContainer
        self.onSwitchToCloud = onSwitchToCloud
    }

    static func loadDecision() -> Decision {
        guard let rawValue = UserDefaults.standard.string(forKey: decisionKey) else {
            return .notSet
        }
        return Decision(rawValue: rawValue) ?? .notSet
    }

    static func saveDecision(_ decision: Decision) {
        UserDefaults.standard.set(decision.rawValue, forKey: decisionKey)
    }

    static func handleCloudSyncEnabled(localHasData: Bool, cloudHasData: Bool) -> Decision {
        if localHasData && !cloudHasData {
            return .keepLocal
        }

        if cloudHasData && !localHasData {
            return .keepCloud
        }

        if localHasData && cloudHasData {
            let decision = loadDecision()
            return decision == .notSet ? .notSet : decision
        }

        return .notSet
    }

    func keepLocalOnly() {
        Self.saveDecision(.keepLocal)
        shouldShowPrompt = false
    }

    func chooseKeepLocalData() async {
        await migrateToCloud(overwriteDestination: true)
    }

    func chooseKeepCloudData() async {
        await migrateToLocal(overwriteDestination: true)
    }

    func updateCloudContainer(_ container: ModelContainer?) {
        cloudContainer = container
    }

    func handleCloudSyncEnabled() async {
        guard !isMigrating else { return }
        guard let cloudContainer else { return }

        let localHasData = Self.hasAnyData(in: localContainer)
        let cloudHasData = Self.hasAnyData(in: cloudContainer)
        let decision = Self.handleCloudSyncEnabled(localHasData: localHasData, cloudHasData: cloudHasData)

        if localHasData && !cloudHasData {
            await migrateToCloud(overwriteDestination: false)
            Self.saveDecision(.keepLocal)
        } else if cloudHasData && !localHasData {
            await migrateToLocal(overwriteDestination: false)
            Self.saveDecision(.keepCloud)
        } else if localHasData && cloudHasData {
            switch decision {
            case .keepLocal:
                await migrateToCloud(overwriteDestination: true)
            case .keepCloud:
                await migrateToLocal(overwriteDestination: true)
            case .notSet:
                shouldShowPrompt = true
            }
        } else {
            onSwitchToCloud(cloudContainer)
        }
    }

    func migrateToCloud(overwriteDestination: Bool) async {
        isMigrating = true
        defer { isMigrating = false }
        migrationError = nil

        guard let cloudContainer else {
            migrationError = "iCloud container is unavailable."
            return
        }

        let localContext = ModelContext(localContainer)
        let cloudContext = ModelContext(cloudContainer)

        do {
            try migrateFinance(from: localContext, to: cloudContext, overwriteDestination: overwriteDestination)
            try migrateTasks(from: localContext, to: cloudContext, overwriteDestination: overwriteDestination)
            try migrateFlows(from: localContext, to: cloudContext, overwriteDestination: overwriteDestination)
            try migrateComms(from: localContext, to: cloudContext, overwriteDestination: overwriteDestination)
            try migrateSplitModels(from: localContext, to: cloudContext, overwriteDestination: overwriteDestination)
            try cloudContext.save()

            Self.saveDecision(.keepLocal)
            shouldShowPrompt = false
            onSwitchToCloud(cloudContainer)
        } catch {
            migrationError = "Failed to move local data to iCloud. \(error.localizedDescription)"
        }
    }

    func migrateToLocal(overwriteDestination: Bool) async {
        isMigrating = true
        defer { isMigrating = false }
        migrationError = nil

        guard let cloudContainer else {
            migrationError = "iCloud container is unavailable."
            return
        }

        let localContext = ModelContext(localContainer)
        let cloudContext = ModelContext(cloudContainer)

        do {
            try migrateFinance(from: cloudContext, to: localContext, overwriteDestination: overwriteDestination)
            try migrateTasks(from: cloudContext, to: localContext, overwriteDestination: overwriteDestination)
            try migrateFlows(from: cloudContext, to: localContext, overwriteDestination: overwriteDestination)
            try migrateComms(from: cloudContext, to: localContext, overwriteDestination: overwriteDestination)
            try migrateSplitModels(from: cloudContext, to: localContext, overwriteDestination: overwriteDestination)
            try localContext.save()

            Self.saveDecision(.keepCloud)
            shouldShowPrompt = false
            onSwitchToCloud(cloudContainer)
        } catch {
            migrationError = "Failed to move iCloud data to local storage. \(error.localizedDescription)"
        }
    }

    func clearError() {
        migrationError = nil
    }

    private func migrateFinance(
        from sourceContext: ModelContext,
        to destinationContext: ModelContext,
        overwriteDestination: Bool
    ) throws {
        if overwriteDestination {
            try deleteAll(FetchDescriptor<FinanceEntry>(), in: destinationContext)
        }

        let sourceItems = try sourceContext.fetch(FetchDescriptor<FinanceEntry>())
        let existingIds = overwriteDestination
            ? []
            : Set(try destinationContext.fetch(FetchDescriptor<FinanceEntry>()).map { $0.id })

        for entry in sourceItems where !existingIds.contains(entry.id) {
            let copy = FinanceEntry(
                id: entry.id,
                amount: entry.amount,
                type: entry.type,
                category: entry.category,
                entryDescription: entry.entryDescription,
                date: entry.date,
                urgency: entry.urgency
            )
            destinationContext.insert(copy)
        }
    }

    private func migrateTasks(
        from sourceContext: ModelContext,
        to destinationContext: ModelContext,
        overwriteDestination: Bool
    ) throws {
        if overwriteDestination {
            try deleteAll(FetchDescriptor<TaskItem>(), in: destinationContext)
        }

        let sourceItems = try sourceContext.fetch(FetchDescriptor<TaskItem>())
        let existingIds = overwriteDestination
            ? []
            : Set(try destinationContext.fetch(FetchDescriptor<TaskItem>()).map { $0.id })

        for item in sourceItems where !existingIds.contains(item.id) {
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
            destinationContext.insert(copy)
        }
    }

    private func migrateFlows(
        from sourceContext: ModelContext,
        to destinationContext: ModelContext,
        overwriteDestination: Bool
    ) throws {
        if overwriteDestination {
            try deleteAll(FetchDescriptor<FlowItem>(), in: destinationContext)
        }

        let sourceItems = try sourceContext.fetch(FetchDescriptor<FlowItem>())
        let existingIds = overwriteDestination
            ? []
            : Set(try destinationContext.fetch(FetchDescriptor<FlowItem>()).map { $0.id })

        for item in sourceItems where !existingIds.contains(item.id) {
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
            destinationContext.insert(copy)
        }
    }

    private func migrateComms(
        from sourceContext: ModelContext,
        to destinationContext: ModelContext,
        overwriteDestination: Bool
    ) throws {
        if overwriteDestination {
            try deleteAll(FetchDescriptor<CommsCard>(), in: destinationContext)
        }

        let sourceItems = try sourceContext.fetch(FetchDescriptor<CommsCard>())
        let existingIds = overwriteDestination
            ? []
            : Set(try destinationContext.fetch(FetchDescriptor<CommsCard>()).map { $0.id })

        for card in sourceItems where !existingIds.contains(card.id) {
            let copy = CommsCard(
                id: card.id,
                title: card.title,
                phrase: card.phrase,
                language: card.language,
                emoji: card.emoji,
                imageData: card.imageData,
                audioData: card.audioData
            )
            destinationContext.insert(copy)
        }
    }

    private func migrateSplitModels(
        from sourceContext: ModelContext,
        to destinationContext: ModelContext,
        overwriteDestination: Bool
    ) throws {
        if overwriteDestination {
            try deleteAll(FetchDescriptor<SplitExpense>(), in: destinationContext)
            try deleteAll(FetchDescriptor<SplitPerson>(), in: destinationContext)
        }

        let sourcePeople = try sourceContext.fetch(FetchDescriptor<SplitPerson>())
        let destinationPeople = try destinationContext.fetch(FetchDescriptor<SplitPerson>())
        var personMap = Dictionary(uniqueKeysWithValues: destinationPeople.map { ($0.id, $0) })

        for person in sourcePeople where personMap[person.id] == nil {
            let copy = SplitPerson(id: person.id, name: person.name)
            destinationContext.insert(copy)
            personMap[person.id] = copy
        }

        let sourceExpenses = try sourceContext.fetch(FetchDescriptor<SplitExpense>())
        let existingExpenseIds = overwriteDestination
            ? []
            : Set(try destinationContext.fetch(FetchDescriptor<SplitExpense>()).map { $0.id })

        for expense in sourceExpenses where !existingExpenseIds.contains(expense.id) {
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
            destinationContext.insert(copy)
        }
    }

    private func deleteAll<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) throws {
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
    }
}

extension MigrationManager {
    static var preview: MigrationManager {
        let schema = AppSchema.schema
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = (try? ModelContainer(for: schema, configurations: [configuration]))
            ?? SampleData.makeFallbackContainer()
        return MigrationManager(localContainer: container, cloudContainer: container)
    }
}

private extension MigrationManager {
    static func hasAnyData(in container: ModelContainer) -> Bool {
        let context = ModelContext(container)
        do {
            return try context.fetchCount(FetchDescriptor<FinanceEntry>()) > 0
                || context.fetchCount(FetchDescriptor<TaskItem>()) > 0
                || context.fetchCount(FetchDescriptor<SplitPerson>()) > 0
                || context.fetchCount(FetchDescriptor<SplitExpense>()) > 0
                || context.fetchCount(FetchDescriptor<CommsCard>()) > 0
                || context.fetchCount(FetchDescriptor<FlowItem>()) > 0
        } catch {
            return false
        }
    }
}
