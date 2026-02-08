import SwiftUI

@main
struct OnePlaceApp: App {
    @StateObject private var dataController: AppDataController
    @StateObject private var authManager = AuthManager()

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn, let userId = authManager.currentUserId {
                    RootTabView(ownerUserId: userId)
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
        }
        .modelContainer(dataController.container)
    }
}
