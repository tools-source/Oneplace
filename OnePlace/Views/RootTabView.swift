import SwiftUI
import UIKit

private enum RootTab: String, CaseIterable, Identifiable {
    case finance
    case flow
    case organizer
    case split
    case talk
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finance:   return "Finance"
        case .flow:      return "Flow"
        case .organizer: return "Tasks"
        case .split:     return "Split"
        case .talk:      return "Talk"
        case .settings:  return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .finance:   return "dollarsign.circle"
        case .flow:      return "calendar.badge.clock"
        case .organizer: return "checklist"
        case .split:     return "person.2"
        case .talk:      return "bubble.left.and.bubble.right"
        case .settings:  return "gearshape"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .finance:   return "dollarsign.circle.fill"
        case .flow:      return "calendar.badge.clock"
        case .organizer: return "checklist"
        case .split:     return "person.2.fill"
        case .talk:      return "bubble.left.and.bubble.right.fill"
        case .settings:  return "gearshape.fill"
        }
    }
}

struct RootTabView: View {
    let ownerUserId: String

    @AppStorage("root.selectedTab") private var selectedTabValue = RootTab.finance.rawValue

    init(ownerUserId: String) {
        self.ownerUserId = ownerUserId
        configureNavigationBarAppearance()
    }

    var body: some View {
        currentTabView
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomNavigationBar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(Color.clear)
            }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .finance:   FinanceView()
        case .flow:      FlowView()
        case .organizer: OrganizerView()
        case .split:     SplitView()
        case .talk:      CommsView()
        case .settings:  SettingsView()
        }
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(DesignSystem.tabBarBackground)
                .shadow(color: DesignSystem.shadowColor.opacity(0.28), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
        )
    }

    private func tabButton(for tab: RootTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            guard !isSelected else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            select(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                    .frame(height: 20)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(tab.title)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .foregroundStyle(
                isSelected
                    ? DesignSystem.accentColor
                    : DesignSystem.secondaryTextColor
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(DesignSystem.accentSoft)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(DesignSystem.accentColor.opacity(0.22), lineWidth: 1)
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedTab: RootTab {
        RootTab(rawValue: selectedTabValue) ?? .finance
    }

    private func select(_ tab: RootTab) {
        selectedTabValue = tab.rawValue
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

#Preview {
    RootTabView(ownerUserId: SampleData.previewUserId)
        .environmentObject(AuthManager())
}
