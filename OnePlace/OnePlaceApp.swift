import SwiftUI

@main
struct OnePlaceApp: App {
    @StateObject private var dataController: AppDataController

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(dataController.container)
    }
}
