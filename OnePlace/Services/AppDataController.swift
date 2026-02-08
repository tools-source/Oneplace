import Foundation
import SwiftData

@MainActor
final class AppDataController: ObservableObject {
    static let cloudKitContainerIdentifier = "iCloud.com.tools-source.oneplace"
    private static let cloudSyncEnabledKey = "cloudSyncEnabled"

    @Published private(set) var cloudContainer: ModelContainer?
    let localContainer: ModelContainer
    @Published var container: ModelContainer
    @Published private(set) var isCloudSyncEnabled: Bool
    lazy var migrationManager: MigrationManager = {
        MigrationManager(
            localContainer: localContainer,
            cloudContainer: cloudContainer,
            onSwitchToCloud: { [weak self] container in
                self?.container = container
            }
        )
    }()

    init() {
        let schema = AppSchema.schema

        cloudContainer = Self.makeCloudContainer(schema: schema)
        localContainer = Self.makeLocalContainer(schema: schema)

        let storedPreference = UserDefaults.standard.object(forKey: Self.cloudSyncEnabledKey) as? Bool
        let defaultPreference = storedPreference ?? (cloudContainer != nil)
        isCloudSyncEnabled = defaultPreference

        if isCloudSyncEnabled, let cloudContainer {
            container = cloudContainer
        } else {
            container = localContainer
        }

        migrationManager.updateCloudContainer(cloudContainer)
        if isCloudSyncEnabled {
            Task { await migrationManager.handleCloudSyncEnabled() }
        }
    }

    func setCloudSyncEnabled(_ isEnabled: Bool) {
        isCloudSyncEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.cloudSyncEnabledKey)

        if isEnabled {
            Task {
                await enableCloudSync()
            }
        } else {
            container = localContainer
        }
    }

    func retryCloudContainer() async {
        cloudContainer = Self.makeCloudContainer(schema: AppSchema.schema)
        migrationManager.updateCloudContainer(cloudContainer)
        if isCloudSyncEnabled {
            await enableCloudSync()
        }
    }

    private func enableCloudSync() async {
        if cloudContainer == nil {
            cloudContainer = Self.makeCloudContainer(schema: AppSchema.schema)
            migrationManager.updateCloudContainer(cloudContainer)
        }

        guard let cloudContainer else {
            container = localContainer
            return
        }

        container = cloudContainer
        await migrationManager.handleCloudSyncEnabled()
    }

    private static func makeCloudContainer(schema: Schema) -> ModelContainer? {
        let configuration = ModelConfiguration(
            "CloudStore",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logContainerError(error, configuration: configuration)
            return nil
        }
    }

    private static func makeLocalContainer(schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logContainerError(error, configuration: configuration)
            return makeInMemoryContainer(schema: schema)
        }
    }

    private static func makeContainer(schema: Schema) -> ModelContainer {
        if let cloudContainer = makeCloudContainer(schema: schema) {
            return cloudContainer
        }
        return makeLocalContainer(schema: schema)
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

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        if let inMemoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfiguration]) {
            return inMemoryContainer
        }

        print("Unable to create in-memory ModelContainer with schema. Falling back to sample data container.")
        return SampleData.makeFallbackContainer()
    }
}
