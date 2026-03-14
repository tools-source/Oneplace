import SwiftUI

public struct AppCard<Content: View>: View {
    private let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(DesignSystem.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .shadow(color: DesignSystem.shadowColor.opacity(colorScheme == .dark ? 0.22 : 0.12),
                radius: DesignSystem.cardShadowRadius,
                x: 0,
                y: 10)
        .shadow(color: DesignSystem.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.04),
                radius: 24,
                x: 0,
                y: 14)
    }

    private var strokeColor: Color {
        DesignSystem.cardBorderColor
    }
}

struct ItemIconBadge: View {
    private let symbol: String?
    private let text: String?
    private let tint: Color
    private let size: CGFloat

    init(symbol: String, tint: Color, size: CGFloat = DesignSystem.badgeSize) {
        self.symbol = symbol
        self.text = nil
        self.tint = tint
        self.size = size
    }

    init(text: String, tint: Color = DesignSystem.accentColor, size: CGFloat = DesignSystem.badgeSize) {
        self.symbol = nil
        self.text = text
        self.tint = tint
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: size, height: size)

            if let text, !text.isEmpty {
                Text(text)
                    .font(.system(size: size * 0.52))
                    .minimumScaleFactor(0.6)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    AppCard {
        Text("Example card content")
            .font(.headline)
            .foregroundColor(.primary)
    }
    .padding()
}
