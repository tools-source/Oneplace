import SwiftUI
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        print("📦 plist path =", Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") ?? "NOT FOUND")

        FirebaseApp.configure()
        return true
    }
}

@main
struct OnePlaceApp: App {
    // ✅ register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var dataController: AppDataController
    @StateObject private var authManager: AuthManager

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)

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
