import SwiftUI

public struct EmptyState: View {
    public let title: String
    public let message: String
    public let systemImage: String
    public let ctaTitle: String?
    public let onCTATap: (() -> Void)?

    public init(
        title: String,
        message: String,
        systemImage: String,
        ctaTitle: String? = nil,
        onCTATap: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.ctaTitle = ctaTitle
        self.onCTATap = onCTATap
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(DesignSystem.accentColor)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let ctaTitle, let onCTATap {
                Button(ctaTitle, action: onCTATap)
                    .buttonStyle(.borderedProminent)
                    .tint(DesignSystem.accentColor)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
        )
        .shadow(color: DesignSystem.shadowColor.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        EmptyState(
            title: "No Items",
            message: "You have no items in your list.",
            systemImage: "tray",
            ctaTitle: "Add Item"
        ) {
            print("Add Item tapped")
        }
        EmptyState(
            title: "No Results",
            message: "Try adjusting your search.",
            systemImage: "magnifyingglass"
        )
    }
    .padding()
}
