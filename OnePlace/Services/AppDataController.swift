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
            logContainerError(error, configuration: configuration)
            if let fallback {
                return fallback
            }
            let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
            } catch {
                logContainerError(error, configuration: inMemoryConfiguration)
                fatalError("Failed to create any ModelContainer. See logs above for details.")
            }
        }
    }

    private static func logContainerError(_ error: Error, configuration: ModelConfiguration) {
        print("Failed to create ModelContainer with configuration: \(configuration)")
        dump(error)
        let nsError = error as NSError
        print("NSError domain: \(nsError.domain) code: \(nsError.code)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            print("Underlying error:")
            dump(underlying)
        }
        if let detailedErrors = nsError.userInfo["NSDetailedErrors"] as? [NSError], !detailedErrors.isEmpty {
            print("Detailed errors:")
            detailedErrors.forEach { dump($0) }
        }
        if !nsError.userInfo.isEmpty {
            print("User info:")
            dump(nsError.userInfo)
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
