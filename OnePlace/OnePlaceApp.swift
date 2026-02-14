import SwiftUI
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }
}

@main
struct OnePlaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var dataController: AppDataController
    @State private var authManager: AuthManager?

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let authManager {
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
                } else {
                    ProgressView("Loading…")
                        .task {
                            if FirebaseApp.app() == nil {
                                FirebaseApp.configure()
                            }
                            authManager = AuthManager()
                        }
                }
            }
        }
        .modelContainer(dataController.container)
    }
}
