import SwiftUI

struct FinanceTypeBadge: View {
    
    private let symbol: String
    private let tint: Color
    private let label: String
    
    // For Gain / Owe
    init(type: FinanceType) {
        switch type {
        case .gain:
            self.symbol = "arrow.up.right"
            self.tint = DesignSystem.gainColor
            self.label = "Gain"
            
        case .owe:
            self.symbol = "arrow.down.right"
            self.tint = DesignSystem.oweColor
            self.label = "Owe"
        }
    }
    
    // For Net
    init(netTotal: Double) {
        if netTotal > 0 {
            self.symbol = "plus"
            self.tint = DesignSystem.gainColor
            self.label = "Net Positive"
        } else if netTotal < 0 {
            self.symbol = "minus"
            self.tint = DesignSystem.oweColor
            self.label = "Net Negative"
        } else {
            self.symbol = "equal"
            self.tint = .secondary
            self.label = "Net Zero"
        }
    }
    
    var body: some View {
        Image(systemName: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(tint.opacity(0.15))
            )
            .overlay(
                Circle()
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
            .accessibilityLabel(label)
    }
}
