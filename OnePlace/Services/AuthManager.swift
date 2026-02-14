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

    func signInWithGoogle() async {
        errorMessage = nil
        authState = .loading

        do {
            try ensureFirebaseConfigured()
            print("CLIENT ID =", FirebaseApp.app()?.options.clientID ?? "NIL")
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
                        self.authState = .signedOut
                        self.errorMessage = self.makeFriendlyError(error)
                    }

                case .failure(let error):
                    self.authState = .signedOut
                    self.errorMessage = self.makeFriendlyError(error)
                }
            }
        }

        appleSignInDelegate = delegate
        delegate.startSignInWithAppleFlow()
    }

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

        return nsError.localizedDescription
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
