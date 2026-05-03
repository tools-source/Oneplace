import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    private var isLoading: Bool {
        if case .loading = authManager.authState { return true }
        return false
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundGradient
                .ignoresSafeArea()

            // Ambient background blobs
            GeometryReader { geo in
                Circle()
                    .fill(DesignSystem.accentColor.opacity(0.12))
                    .frame(width: geo.size.width * 0.72)
                    .blur(radius: 60)
                    .offset(x: -geo.size.width * 0.18, y: -geo.size.height * 0.08)

                Circle()
                    .fill(DesignSystem.secondaryAccent.opacity(0.09))
                    .frame(width: geo.size.width * 0.60)
                    .blur(radius: 50)
                    .offset(x: geo.size.width * 0.40, y: geo.size.height * 0.50)
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 48)

                    // Logo + brand
                    VStack(spacing: 16) {
                        OnePlaceLogo(size: 88)

                        VStack(spacing: 6) {
                            HStack(spacing: 0) {
                                Text("One")
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(DesignSystem.accentColor)
                                Text("Place")
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)
                            }

                            Text("Plans, money, and tasks — one home.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 36)

                    // Feature cards
                    VStack(spacing: 12) {
                        featureRow(
                            symbol: "banknote.fill",
                            tint: DesignSystem.gainColor,
                            title: "Finance tracker",
                            message: "Log income and expenses by voice or text."
                        )
                        featureRow(
                            symbol: "calendar.badge.clock",
                            tint: DesignSystem.warmAccent,
                            title: "Recurring bills & flow",
                            message: "Track subscriptions and upcoming payments."
                        )
                        featureRow(
                            symbol: "checklist",
                            tint: DesignSystem.secondaryAccent,
                            title: "Organizer & tasks",
                            message: "Prioritised tasks with due dates and reminders."
                        )
                        featureRow(
                            symbol: "person.2.fill",
                            tint: DesignSystem.accentColor,
                            title: "Expense splitting",
                            message: "Split costs and see who owes what at a glance."
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                    // Error
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DesignSystem.oweColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(DesignSystem.oweColor.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(DesignSystem.oweColor.opacity(0.22), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                    }

                    // Sign-in buttons
                    VStack(spacing: 12) {
                        Button {
                            authManager.signInWithApple()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Continue with Apple")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.black)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)

                        Button {
                            Task { await authManager.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(DesignSystem.cardGradient)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 20)

                    // Loading indicator
                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(DesignSystem.accentColor)
                            Text("Signing you in…")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(DesignSystem.cardGradient)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
                        )
                        .padding(.top, 14)
                    }

                    // Privacy footer
                    Text("By signing in you agree to our Terms of Service and Privacy Policy.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    private func featureRow(symbol: String, tint: Color, title: String, message: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
