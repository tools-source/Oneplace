import SwiftUI

@main
struct OnePlaceApp: App {
    @StateObject private var dataController: AppDataController
    @StateObject private var cloudSyncManager: CloudSyncManager

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)
        _cloudSyncManager = StateObject(
            wrappedValue: CloudSyncManager(containerIdentifier: AppDataController.cloudKitContainerIdentifier)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dataController)
                .environmentObject(dataController.migrationManager)
                .environmentObject(cloudSyncManager)
        }
        .modelContainer(dataController.container)
    }
}
