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
                    authManager.onAppleRequest(request)
                } onCompletion: { result in
                    print("[Auth] Apple Sign-In completion received in LoginView.")
                    authManager.handleAppleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(Capsule())
                .contentShape(Capsule())
                .allowsHitTesting(true)

                Button {
                    print("[Auth] Google Sign-In button tapped.")
                    Task {
                        guard let controller = UIApplication.shared.topMostViewController() else {
                            print("[Auth] Unable to find top-most UIViewController for Google Sign-In presentation.")
                            return
                        }
                        await authManager.signInWithGoogle(presenting: controller)
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
        .background(Color(.systemBackground))
        .onAppear {
            print("[Auth] LoginView appeared. Buttons are active in the view hierarchy.")
        }
    }
}

private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        guard let windowScene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
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
