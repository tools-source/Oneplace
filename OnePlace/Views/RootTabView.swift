import SwiftUI

struct RootTabView: View {
    let ownerUserId: String

    var body: some View {
        TabView {
            FinanceView() 
                .tabItem {
                    Label("Finance", systemImage: "banknote")
                }

            FlowView(ownerUserId: ownerUserId)
                .tabItem {
                    Label("Flow", systemImage: "calendar.badge.clock")
                }

            OrganizerView(ownerUserId: ownerUserId)
                .tabItem {
                    Label("Organizer", systemImage: "checklist")
                }

            SplitView(ownerUserId: ownerUserId)
                .tabItem {
                    Label("Split", systemImage: "person.2.fill")
                }

            CommsView(ownerUserId: ownerUserId)
                .tabItem {
                    Label("Talk Board", systemImage: "waveform")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    RootTabView(ownerUserId: SampleData.previewUserId)
        .modelContainer(SampleData.makeContainer())
        .environmentObject(AuthManager())
}
