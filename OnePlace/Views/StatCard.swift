import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let minHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color,
        minHeight: CGFloat = 96,
        horizontalPadding: CGFloat = DesignSystem.cardPadding,
        verticalPadding: CGFloat = DesignSystem.cardPadding
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.minHeight = minHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                iconBadge

                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryTextColor)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.secondaryTextColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.04), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var iconBadge: some View {
        if icon == "finance.gain" {
            FinanceTypeBadge(type: .gain)
        } else if icon == "finance.owe" {
            FinanceTypeBadge(type: .owe)
        } else {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 24, height: 24)
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

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
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
    VStack(spacing: 12) {
        StatCard(title: "Upcoming", value: "3", subtitle: "Bills", icon: "calendar", tint: .blue)
        StatCard(title: "Due Soon", value: StatCard.currencyString(for: 250), subtitle: "Total", icon: "exclamationmark.circle", tint: .orange)
    }
    .padding()
}
