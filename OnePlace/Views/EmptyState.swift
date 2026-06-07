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
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DesignSystem.accentColor.opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: systemImage)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(DesignSystem.accentColor)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let ctaTitle, let onCTATap {
                Button(action: onCTATap) {
                    Label(ctaTitle, systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule(style: .continuous).fill(DesignSystem.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        EmptyState(
            title: "No transactions yet",
            message: "Type a transaction into the search bar, or tap + to add one.",
            systemImage: "sparkles.rectangle.stack",
            ctaTitle: "Add Transaction"
        ) {}
        EmptyState(
            title: "All caught up",
            message: "No upcoming tasks for today.",
            systemImage: "checkmark.circle"
        )
    }
    .padding()
}
