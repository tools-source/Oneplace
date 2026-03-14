import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    private var isLoading: Bool {
        if case .loading = authManager.authState { return true }
        return false
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignSystem.accentColor.opacity(0.18),
                    DesignSystem.warmAccent.opacity(0.14),
                    DesignSystem.primaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 40)

                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(DesignSystem.accentColor)
                    Text("OnePlace")
                        .font(.largeTitle.bold())
                    Text("Sign in to sync your plans, tasks, and finances across devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.oweColor)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(DesignSystem.cardGradient, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DesignSystem.cardBorderColor)
                        )
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        authManager.signInWithApple()
                    } label: {
                        Label("Continue with Apple", systemImage: "apple.logo")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(isLoading)

                    Button {
                        Task {
                            await authManager.signInWithGoogle()
                        }
                    } label: {
                        Label("Continue with Google", systemImage: "globe")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .disabled(isLoading)
                }
                .padding(.horizontal, 24)

                if isLoading {
                    ProgressView("Signing in…")
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
