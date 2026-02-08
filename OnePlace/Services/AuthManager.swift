import AuthenticationServices
import Foundation
import SwiftUI
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class AuthManager: ObservableObject {
    enum AuthProvider: String, Codable {
        case apple
        case google
    }

    @Published private(set) var currentUserId: String?
    @Published private(set) var authProvider: AuthProvider?

    var isLoggedIn: Bool {
        currentUserId != nil
    }

    private let userDefaults: UserDefaults
    private let userIdKey = "auth.currentUserId"
    private let providerKey = "auth.provider"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restoreSession()
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let userId = credential.user
            setSession(userId: userId, provider: .apple)
        case .failure:
            return
        }
    }

    func signInWithGoogle(presenting: UIViewController) async {
        #if canImport(GoogleSignIn)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            let user = result.user
            let userId = user.userID
                ?? user.profile?.email
                ?? user.profile?.name
                ?? UUID().uuidString
            setSession(userId: userId, provider: .google)
        } catch {
            return
        }
        #else
        print("Google Sign-In SDK is not available in this build.")
        #endif
    }

    func signOut() {
        currentUserId = nil
        authProvider = nil
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: providerKey)
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    private func setSession(userId: String, provider: AuthProvider) {
        currentUserId = userId
        authProvider = provider
        userDefaults.set(userId, forKey: userIdKey)
        userDefaults.set(provider.rawValue, forKey: providerKey)
    }

    private func restoreSession() {
        guard let storedUserId = userDefaults.string(forKey: userIdKey),
              let providerRaw = userDefaults.string(forKey: providerKey),
              let provider = AuthProvider(rawValue: providerRaw) else {
            currentUserId = nil
            authProvider = nil
            return
        }
        currentUserId = storedUserId
        authProvider = provider
    }
}
