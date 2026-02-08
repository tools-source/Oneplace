import SwiftUI

struct AppCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    let ctaTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(ctaTitle, action: action)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            .foregroundStyle(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
