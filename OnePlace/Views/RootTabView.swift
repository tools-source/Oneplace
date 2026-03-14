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
        case .finance: return "Finance"
        case .flow: return "Flow"
        case .organizer: return "Organizer"
        case .split: return "Split"
        case .talk: return "Talk"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .finance: return "banknote"
        case .flow: return "calendar.badge.clock"
        case .organizer: return "checklist"
        case .split: return "person.2.fill"
        case .talk: return "waveform"
        case .settings: return "gearshape"
        }
    }
}

struct RootTabView: View {
    let ownerUserId: String

    @SceneStorage("root.selectedTab") private var selectedTabValue = RootTab.finance.rawValue
    @EnvironmentObject private var purchaseManager: PurchaseManager

    init(ownerUserId: String) {
        self.ownerUserId = ownerUserId
        configureNavigationBarAppearance()
    }

    var body: some View {
        currentTabView
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 6) {
                    if !purchaseManager.isAdsRemoved {
                        BannerAdView()
                            .frame(height: 56)
                            .padding(.horizontal, 12)
                    }

                    bottomNavigationBar
                        .padding(.horizontal, 12)
                        .padding(.top, purchaseManager.isAdsRemoved ? 0 : 4)
                        .padding(.bottom, 6)
                }
                .background(Color.clear)
            }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .finance:
            FinanceView()
        case .flow:
            FlowView()
        case .organizer:
            OrganizerView()
        case .split:
            SplitView()
        case .talk:
            CommsView()
        case .settings:
            SettingsView()
        }
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 6) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    guard selectedTab != tab else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    select(tab)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 17, weight: selectedTab == tab ? .semibold : .medium))
                            .frame(height: 18)

                        Text(tab.title)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(selectedTab == tab ? DesignSystem.accentColor : DesignSystem.secondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedTab == tab ? DesignSystem.accentSoft : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                selectedTab == tab ? DesignSystem.cardBorderColor : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DesignSystem.tabBarBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
        )
        .shadow(color: DesignSystem.shadowColor.opacity(0.22), radius: 18, x: 0, y: 8)
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
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

#Preview {
    RootTabView(ownerUserId: SampleData.previewUserId)
        .environmentObject(AuthManager())
        .environmentObject(PurchaseManager())
}
