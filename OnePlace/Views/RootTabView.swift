import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            FinanceView()
                .tabItem {
                    Label("Finance", systemImage: "banknote")
                }

            FlowView()
                .tabItem {
                    Label("Flow", systemImage: "calendar.badge.clock")
                }

            OrganizerView()
                .tabItem {
                    Label("Organizer", systemImage: "checklist")
                }

            SplitView()
                .tabItem {
                    Label("Split", systemImage: "person.2.fill")
                }

            CommsView()
                .tabItem {
                    Label("Comms", systemImage: "bubble.left.and.bubble.right")
                }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.makeContainer())
}
