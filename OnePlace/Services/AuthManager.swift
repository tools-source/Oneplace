import AuthenticationServices
import Foundation
import Security
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

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUserId: String?
    @Published private(set) var authProvider: AuthProvider?
    @Published private(set) var currentEmail: String?
    @Published private(set) var currentFullName: String?

    // Backward-compatible API for existing views.
    var isLoggedIn: Bool { isAuthenticated }

    private let userDefaults: UserDefaults
    private let providerKey = "auth.provider"
    private let emailKey = "auth.email"
    private let fullNameKey = "auth.fullName"
    private let userIdentifierKeychainKey = "com.oneplace.auth.userIdentifier"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restoreSession()
    }

    func onAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        print("[Auth] Apple Sign-In request started.")
        request.requestedScopes = [.fullName, .email]
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("[Auth] Apple Sign-In completed but credential was not ASAuthorizationAppleIDCredential.")
                return
            }

            let userIdentifier = credential.user
            let email = credential.email
            let fullName = formattedName(from: credential.fullName)

            print("[Auth] Apple Sign-In success. userIdentifier=\(userIdentifier)")
            print("[Auth] Apple Sign-In email=\(email ?? \"nil (only returned on first sign-in)\")")
            print("[Auth] Apple Sign-In fullName=\(fullName ?? \"nil (only returned on first sign-in)\")")

            setSession(
                userId: userIdentifier,
                provider: .apple,
                email: email,
                fullName: fullName
            )

        case .failure(let error):
            let nsError = error as NSError
            print("[Auth] Apple Sign-In failed. domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)")
            if nsError.domain == ASAuthorizationError.errorDomain,
               let authError = ASAuthorizationError.Code(rawValue: nsError.code) {
                print("[Auth] Apple Sign-In ASAuthorizationError=\(authError)")
            }
        }
    }

    func signInWithGoogle(presenting: UIViewController) async {
        #if canImport(GoogleSignIn)
        do {
            print("[Auth] Google Sign-In request started.")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            let user = result.user
            let userId = user.userID ?? user.profile?.email ?? UUID().uuidString
            let email = user.profile?.email
            let fullName = user.profile?.name

            print("[Auth] Google Sign-In success. userIdentifier=\(userId)")
            print("[Auth] Google Sign-In email=\(email ?? \"nil\")")
            print("[Auth] Google Sign-In fullName=\(fullName ?? \"nil\")")

            setSession(
                userId: userId,
                provider: .google,
                email: email,
                fullName: fullName
            )
        } catch {
            let nsError = error as NSError
            print("[Auth] Google Sign-In failed. domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)")
        }
        #else
        print("[Auth] Google Sign-In SDK is not available in this build. Add GoogleSignIn dependency and configure URL schemes.")
        #endif
    }

    func handleGoogleOpenURL(_ url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        let handled = GIDSignIn.sharedInstance.handle(url)
        print("[Auth] handleGoogleOpenURL called with \(url.absoluteString). handled=\(handled)")
        return handled
        #else
        print("[Auth] handleGoogleOpenURL called, but GoogleSignIn SDK is not available.")
        return false
        #endif
    }

    func restoreSessionFromProvider() async {
        if authProvider == .apple, let userIdentifier = currentUserId {
            await validateAppleCredentialState(for: userIdentifier)
        }

        #if canImport(GoogleSignIn)
        if authProvider == .google {
            do {
                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                let userId = user.userID ?? user.profile?.email ?? UUID().uuidString
                print("[Auth] Restored previous Google session for userIdentifier=\(userId)")
                setSession(
                    userId: userId,
                    provider: .google,
                    email: user.profile?.email,
                    fullName: user.profile?.name
                )
            } catch {
                print("[Auth] Unable to restore Google session: \(error.localizedDescription)")
            }
        }
        #endif
    }

    func signOut() {
        print("[Auth] Signing out current user.")
        currentUserId = nil
        authProvider = nil
        currentEmail = nil
        currentFullName = nil
        isAuthenticated = false

        userDefaults.removeObject(forKey: providerKey)
        userDefaults.removeObject(forKey: emailKey)
        userDefaults.removeObject(forKey: fullNameKey)
        KeychainStore.delete(account: userIdentifierKeychainKey)

        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    private func setSession(userId: String, provider: AuthProvider, email: String?, fullName: String?) {
        currentUserId = userId
        authProvider = provider
        currentEmail = email ?? userDefaults.string(forKey: emailKey)
        currentFullName = fullName ?? userDefaults.string(forKey: fullNameKey)
        isAuthenticated = true

        KeychainStore.save(value: userId, account: userIdentifierKeychainKey)
        userDefaults.set(provider.rawValue, forKey: providerKey)
        if let email { userDefaults.set(email, forKey: emailKey) }
        if let fullName { userDefaults.set(fullName, forKey: fullNameKey) }
    }

    private func restoreSession() {
        guard let providerRaw = userDefaults.string(forKey: providerKey),
              let provider = AuthProvider(rawValue: providerRaw),
              let storedUserId = KeychainStore.read(account: userIdentifierKeychainKey) else {
            print("[Auth] No persisted auth session found.")
            currentUserId = nil
            authProvider = nil
            currentEmail = nil
            currentFullName = nil
            isAuthenticated = false
            return
        }

        currentUserId = storedUserId
        authProvider = provider
        currentEmail = userDefaults.string(forKey: emailKey)
        currentFullName = userDefaults.string(forKey: fullNameKey)
        isAuthenticated = true

        print("[Auth] Restored local auth session. provider=\(provider.rawValue), userIdentifier=\(storedUserId)")
    }

    private func validateAppleCredentialState(for userIdentifier: String) async {
        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await provider.credentialState(forUserID: userIdentifier)
            switch state {
            case .authorized:
                print("[Auth] Apple credential state is authorized.")
            case .revoked:
                print("[Auth] Apple credential state is revoked. Signing out.")
                signOut()
            case .notFound:
                print("[Auth] Apple credential state is not found. Signing out.")
                signOut()
            case .transferred:
                print("[Auth] Apple credential state is transferred.")
            @unknown default:
                print("[Auth] Apple credential state is unknown. Keeping current session.")
            }
        } catch {
            print("[Auth] Failed to validate Apple credential state: \(error.localizedDescription)")
        }
    }

    private func formattedName(from personName: PersonNameComponents?) -> String? {
        guard let personName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: personName).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}

enum KeychainStore {
    static func save(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Auth] Keychain save failed for account=\(account). status=\(status)")
        }
    }

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            print("[Auth] Keychain delete failed for account=\(account). status=\(status)")
        }
    }
}
