import AuthenticationServices
import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("Welcome to OnePlace")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Sign in to keep your data private on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleAppleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(Capsule())

                Button {
                    Task {
                        if let controller = UIApplication.shared.topMostViewController() {
                            await authManager.signInWithGoogle(presenting: controller)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding()
    }
}

private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        guard let scene = connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
