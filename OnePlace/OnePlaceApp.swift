import FirebaseCore
import SwiftUI

@main
struct OnePlaceApp: App {
    @StateObject private var dataController: AppDataController
    @StateObject private var authManager = AuthManager()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.authState {
                case .signedIn(let user):
                    RootTabView(ownerUserId: user.uid)
                case .loading:
                    ProgressView("Loading…")
                case .signedOut:
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .task {
                await authManager.restoreSessionFromProvider()
            }
        }
        .modelContainer(dataController.container)
    }
}
