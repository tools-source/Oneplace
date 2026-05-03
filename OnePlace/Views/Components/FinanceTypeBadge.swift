import SwiftUI

struct FinanceTypeBadge: View {
    enum Kind {
        case gain
        case owe
        case net(isPositive: Bool)
    }

    let kind: Kind
    var size: CGFloat = DesignSystem.badgeSize

    init(type: FinanceType, size: CGFloat = DesignSystem.badgeSize) {
        self.kind = type == .gain ? .gain : .owe
        self.size = size
    }

    init(netTotal: Double, size: CGFloat = DesignSystem.badgeSize) {
        self.kind = .net(isPositive: netTotal >= 0)
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                )

            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }

    private var symbol: String {
        switch kind {
        case .gain:              return "arrow.up.right"
        case .owe:               return "arrow.down.left"
        case .net(true):         return "plus"
        case .net(false):        return "minus"
        }
    }

    private var tint: Color {
        switch kind {
        case .gain:              return DesignSystem.gainColor
        case .owe:               return DesignSystem.oweColor
        case .net(let positive): return positive ? DesignSystem.accentColor : DesignSystem.oweColor
        }
    }
}
