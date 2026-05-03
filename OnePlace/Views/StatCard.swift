import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let minHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color,
        minHeight: CGFloat = 100
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.minHeight = minHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                iconBadge
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(DesignSystem.cardPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
        )
        .shadow(
            color: tint.opacity(colorScheme == .dark ? 0.12 : 0.06),
            radius: 10, x: 0, y: 6
        )
    }

    @ViewBuilder
    private var iconBadge: some View {
        if icon == "finance.gain" {
            FinanceTypeBadge(type: .gain)
        } else if icon == "finance.owe" {
            FinanceTypeBadge(type: .owe)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }

    static func currencyString(for amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount))
            ?? amount.formatted(.currency(code: currencyCode))
    }

    private static let currencyCode = Locale.current.currency?.identifier ?? "USD"
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale.current
        return formatter
    }()
}

#Preview {
    HStack(spacing: 10) {
        StatCard(title: "Net", value: StatCard.currencyString(for: 1250), subtitle: "Positive runway", icon: "plus", tint: .teal)
        StatCard(title: "Gain", value: StatCard.currencyString(for: 3200), subtitle: "Open income", icon: "arrow.up.right", tint: .green)
        StatCard(title: "Owe", value: StatCard.currencyString(for: 1950), subtitle: "Pending", icon: "arrow.down.left", tint: .red)
    }
    .padding()
}
