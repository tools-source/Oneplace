import SwiftUI
import FirebaseCore

// ✅ Configure Firebase as early as possible (before any views/managers init)
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
    @StateObject private var authManager: AuthManager

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)

        // AuthManager can safely touch Auth/Firestore now because AppDelegate configured Firebase first
        _authManager = StateObject(wrappedValue: AuthManager())
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
