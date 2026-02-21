import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn
import SwiftUI
import UIKit

@MainActor
final class AuthManager: ObservableObject {

    enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(AppUser)
    }

    @Published private(set) var authState: AuthState = .signedOut
    @Published var errorMessage: String?

    private lazy var auth: Auth = { Auth.auth() }()
    private lazy var firestore: Firestore = { Firestore.firestore() }()
    private var appleSignInDelegate: AppleSignInCoordinator?

    init() {}

    // ✅ Make sure Firebase is configured before we touch FirebaseApp.app()/Auth/Firestore
    private func ensureFirebaseConfigured() throws {
        guard FirebaseApp.app() != nil else {
            throw AuthFlowError.configuration(
                "Firebase is not configured (FirebaseApp.app() is nil). Check that FirebaseApp.configure() runs in AppDelegate and that GoogleService-Info.plist is in Copy Bundle Resources."
            )
        }
    }

    // MARK: - Session restore

    func restoreSessionFromProvider() async {
        do {
            try ensureFirebaseConfigured()
        } catch {
            authState = .signedOut
            errorMessage = error.localizedDescription
            return
        }

        guard let user = auth.currentUser else {
            authState = .signedOut
            return
        }

        do {
            let providerID = user.providerData.first?.providerID
            let provider: String
            switch providerID {
            case "apple.com": provider = "apple"
            case "google.com": provider = "google"
            default: provider = "unknown"
            }

            let appUser = try await ensureUserRecordExists(firebaseUser: user, provider: provider)
            authState = .signedIn(appUser)
        } catch {
            authState = .signedOut
            errorMessage = "Could not restore your session. \(error.localizedDescription)"
        }
    }

    // MARK: - Sign In

    func signInWithGoogle() async {
        errorMessage = nil
        authState = .loading

        do {
            try ensureFirebaseConfigured()

            guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
                throw AuthFlowError.configuration(
                    "Firebase clientID is missing. This usually means the GoogleService-Info.plist does not match your Bundle ID, or the wrong plist was added."
                )
            }

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            guard let presentingVC = UIApplication.shared.topMostViewController() else {
                throw AuthFlowError.presentation("Unable to present Google Sign-In. Try again.")
            }

            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)

            guard let idToken = signInResult.user.idToken?.tokenString else {
                throw AuthFlowError.authentication("Google Sign-In failed: missing ID token.")
            }

            let accessToken = signInResult.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            let authResult = try await auth.signIn(with: credential)
            let user = try await ensureUserRecordExists(firebaseUser: authResult.user, provider: "google")
            authState = .signedIn(user)
        } catch {
            // If user cancels sign-in, don’t show an "error" toast/alert.
            if isUserCanceledAuth(error) {
                authState = .signedOut
                errorMessage = nil
                return
            }

            authState = .signedOut
            errorMessage = makeFriendlyError(error)
        }
    }

    func signInWithApple() {
        errorMessage = nil
        authState = .loading

        let delegate = AppleSignInCoordinator { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                do {
                    try self.ensureFirebaseConfigured()
                } catch {
                    self.authState = .signedOut
                    self.errorMessage = error.localizedDescription
                    return
                }

                switch result {
                case .success(let credential):
                    do {
                        let authResult = try await self.auth.signIn(with: credential)
                        let user = try await self.ensureUserRecordExists(firebaseUser: authResult.user, provider: "apple")
                        self.authState = .signedIn(user)
                    } catch {
                        if self.isUserCanceledAuth(error) {
                            self.authState = .signedOut
                            self.errorMessage = nil
                            return
                        }
                        self.authState = .signedOut
                        self.errorMessage = self.makeFriendlyError(error)
                    }

                case .failure(let error):
                    if self.isUserCanceledAuth(error) {
                        self.authState = .signedOut
                        self.errorMessage = nil
                        return
                    }
                    self.authState = .signedOut
                    self.errorMessage = self.makeFriendlyError(error)
                }
            }
        }

        appleSignInDelegate = delegate
        delegate.startSignInWithAppleFlow()
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            authState = .signedOut
            errorMessage = nil
        } catch {
            errorMessage = "Could not sign out. \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        errorMessage = nil

        do {
            try ensureFirebaseConfigured()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        guard let user = auth.currentUser else {
            let error = AuthFlowError.authentication("You are not signed in.")
            errorMessage = error.localizedDescription
            throw error
        }

        do {
            // ✅ Re-auth (required by Firebase for sensitive operations)
            try await reauthenticateIfNeeded(for: user)

            // ✅ Firestore cleanup (client-side; deletes known subcollections)
            try await deleteUserFirestoreData(uid: user.uid)

            // ✅ Delete Auth user
            try await user.delete()

            // ✅ Local cleanup
            performLocalCleanup()
        } catch {
            // ✅ If user cancels Apple/Google confirmation, don’t show an error.
            if isUserCanceledAuth(error) {
                errorMessage = nil
                return
            }

            let friendly = makeFriendlyError(error)
            errorMessage = friendly
            throw AuthFlowError.authentication(friendly)
        }
    }

    /// Treat user-cancel as a non-error across Apple/Google versions.
    func isUserCanceledAuth(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Apple Sign-In cancel
        if nsError.domain == ASAuthorizationError.errorDomain,
           let code = ASAuthorizationError.Code(rawValue: nsError.code),
           code == .canceled {
            return true
        }

        // Google Sign-In cancel (constants differ by version; avoid referencing symbols that may not exist)
        let message = nsError.localizedDescription.lowercased()
        if message.contains("cancel") || message.contains("canceled") || message.contains("cancelled") {
            return true
        }

        // Generic user-cancel patterns (safe fallback)
        if nsError.code == 0 || nsError.code == -999 {
            return true
        }

        return false
    }

    // MARK: - User record

    func ensureUserRecordExists(firebaseUser: FirebaseAuth.User, provider: String) async throws -> AppUser {
        let userRef = firestore.collection("users").document(firebaseUser.uid)
        let snapshot = try await userRef.getDocument()

        if snapshot.exists {
            try await userRef.setData([
                "lastLoginAt": FieldValue.serverTimestamp(),
                "provider": provider
            ], merge: true)
        } else {
            try await userRef.setData([
                "uid": firebaseUser.uid,
                "email": firebaseUser.email as Any,
                "fullName": firebaseUser.displayName as Any,
                "provider": provider,
                "createdAt": FieldValue.serverTimestamp(),
                "lastLoginAt": FieldValue.serverTimestamp()
            ])
        }

        return AppUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            fullName: firebaseUser.displayName,
            provider: provider
        )
    }

    // MARK: - Friendly errors

    private func makeFriendlyError(_ error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == ASAuthorizationError.errorDomain,
           let code = ASAuthorizationError.Code(rawValue: nsError.code),
           code == .canceled {
            return "Sign in was canceled. Please try again when you are ready."
        }

        if nsError.code == URLError.notConnectedToInternet.rawValue {
            return "No internet connection. Reconnect and try again."
        }

        if nsError.domain == FirestoreErrorDomain,
           nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
            return "Permission denied while removing your data. Please contact support if this persists."
        }

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code),
           code == .requiresRecentLogin {
            return "Please confirm your sign-in to delete your account."
        }

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code),
           code == .networkError {
            return "Network error. Check your connection and try again."
        }

        return nsError.localizedDescription
    }

    // MARK: - Reauthentication

    private func reauthenticateIfNeeded(for user: FirebaseAuth.User) async throws {
        let providerIDs = Set(user.providerData.map(\.providerID))

        if providerIDs.contains("google.com") {
            let credential = try await googleReauthenticationCredential()
            try await user.reauthenticate(with: credential)
            return
        }

        if providerIDs.contains("apple.com") {
            let credential = try await appleReauthenticationCredential()
            try await user.reauthenticate(with: credential)
            return
        }

        throw AuthFlowError.authentication("Please sign in again and retry deleting your account.")
    }

    private func googleReauthenticationCredential() async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            throw AuthFlowError.configuration("Firebase clientID is missing. Please reinstall or contact support.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presentingVC = UIApplication.shared.topMostViewController() else {
            throw AuthFlowError.presentation("Unable to present Google Sign-In. Try again.")
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthFlowError.authentication("Google re-authentication failed. Please try again.")
        }

        return GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }

    private func appleReauthenticationCredential() async throws -> AuthCredential {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInCoordinator { [weak self] result in
                guard let self else {
                    continuation.resume(throwing: AuthFlowError.authentication("Apple re-authentication was interrupted."))
                    return
                }

                switch result {
                case .success(let credential):
                    continuation.resume(returning: credential)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }

                self.appleSignInDelegate = nil
            }

            self.appleSignInDelegate = delegate
            delegate.startSignInWithAppleFlow()
        }
    }

    // MARK: - Firestore account deletion (Client-side)

    private func deleteUserFirestoreData(uid: String) async throws {
        let userDocRef = firestore.collection("users").document(uid)

        // ✅ IMPORTANT: Update these names to match YOUR Firestore structure exactly.
        let subcollections: [String] = [
            "finance",
            "organizer",
            "flow",
            "split",
            "talkBoard"
        ]

        for name in subcollections {
            let colRef = userDocRef.collection(name)
            try await deleteCollectionDocuments(colRef, batchSize: 200)
        }

        let snap = try await userDocRef.getDocument()
        if snap.exists {
            try await userDocRef.delete()
        }
    }

    /// Deletes all documents in a collection in pages.
    /// NOTE: This deletes documents directly under the collection. If you have nested subcollections
    /// under those documents, iOS cannot auto-discover them; you must delete those known nested paths
    /// or use a Cloud Function for recursive deletion.
    private func deleteCollectionDocuments(_ collection: CollectionReference, batchSize: Int) async throws {
        var lastDoc: DocumentSnapshot? = nil

        while true {
            var query: Query = collection.limit(to: batchSize)
            if let lastDoc {
                query = query.start(afterDocument: lastDoc)
            }

            let snapshot = try await query.getDocuments()
            if snapshot.documents.isEmpty { break }

            let batch = firestore.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()

            lastDoc = snapshot.documents.last
            if snapshot.documents.count < batchSize { break }
        }
    }

    // MARK: - Cleanup

    private func performLocalCleanup() {
        do {
            try auth.signOut()
        } catch {
            print("Sign-out cleanup warning: \(error.localizedDescription)")
        }

        GIDSignIn.sharedInstance.signOut()
        authState = .signedOut
        errorMessage = nil
    }
}

private enum AuthFlowError: LocalizedError {
    case configuration(String)
    case presentation(String)
    case authentication(String)

    var errorDescription: String? {
        switch self {
        case .configuration(let message), .presentation(let message), .authentication(let message):
            return message
        }
    }
}

private final class AppleSignInCoordinator: NSObject {
    private let completion: (Result<OAuthCredential, Error>) -> Void
    private var currentNonce: String?

    init(completion: @escaping (Result<OAuthCredential, Error>) -> Void) {
        self.completion = completion
    }

    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. OSStatus \(errorCode)")
                }
                return random
            }

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            completion(.failure(AuthFlowError.authentication("Unable to read Apple identity token.")))
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        completion(.success(credential))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.topMostViewController()?.view.window ?? ASPresentationAnchor()
    }
}

private extension UIApplication {
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        if let nav = root as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }

        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }

        if let presented = root?.presentedViewController {
            return topMostViewController(base: presented)
        }

        return root
    }
}
