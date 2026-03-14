import SwiftUI
import FirebaseCore
import GoogleMobileAds
import SwiftData

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        print("📦 plist path =", Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") ?? "NOT FOUND")

        FirebaseApp.configure()
        MobileAds.shared.start()
        return true
    }
}

@main
struct OnePlaceApp: App {
    // ✅ register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var dataController: AppDataController
    @StateObject private var authManager: AuthManager
    @StateObject private var purchaseManager: PurchaseManager

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)

        _authManager = StateObject(wrappedValue: AuthManager())
        _purchaseManager = StateObject(wrappedValue: PurchaseManager())
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
            .environmentObject(purchaseManager)
            .tint(DesignSystem.accentColor)
            .task {
                await authManager.restoreSessionFromProvider()
                await purchaseManager.prepare()
            }
        }
        .modelContainer(dataController.container)
    }
}
