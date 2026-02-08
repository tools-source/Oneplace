import Foundation
import SwiftData

@MainActor
final class AppDataController: ObservableObject {
    static let cloudKitContainerIdentifier = "iCloud.com.tools-source.oneplace"

    let cloudContainer: ModelContainer
    let localContainer: ModelContainer
    @Published var container: ModelContainer
    let migrationManager: MigrationManager

    init() {
        let schema = Schema([
            FinanceEntry.self,
            TaskItem.self,
            SplitPerson.self,
            SplitExpense.self,
            CommsCard.self,
            FlowItem.self
        ])

        let localConfiguration = ModelConfiguration(schema: schema)
        let cloudConfiguration = ModelConfiguration(
            "CloudStore",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )

        localContainer = Self.makeContainer(schema: schema, configuration: localConfiguration)
        cloudContainer = Self.makeContainer(schema: schema, configuration: cloudConfiguration, fallback: localContainer)

        container = cloudContainer
        migrationManager = MigrationManager(
            localContainer: localContainer,
            cloudContainer: cloudContainer,
            onSwitchToCloud: { [weak self] container in
                self?.container = container
            }
        )

        let decision = MigrationManager.loadDecision()
        let localHasData = Self.hasAnyData(in: localContainer)
        let cloudHasData = Self.hasAnyData(in: cloudContainer)

        switch decision {
        case .keepLocal:
            container = localContainer
        case .migrated:
            container = cloudContainer
        case .undecided:
            if localHasData && !cloudHasData {
                container = localContainer
                migrationManager.shouldShowPrompt = true
            } else {
                container = cloudContainer
            }
        }
    }

    private static func makeContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        fallback: ModelContainer? = nil
    ) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            if let fallback {
                return fallback
            }
            let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [inMemoryConfiguration])
        }
    }

    private static func hasAnyData(in container: ModelContainer) -> Bool {
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
