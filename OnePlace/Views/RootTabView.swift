import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var migrationManager: MigrationManager

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
        .alert("Choose data to keep", isPresented: $migrationManager.shouldShowPrompt) {
            Button("Keep iCloud data", role: .none) {
                Task { await migrationManager.chooseKeepCloudData() }
            }
            Button("Keep local data", role: .none) {
                Task { await migrationManager.chooseKeepLocalData() }
            }
        } message: {
            Text("Both local and iCloud data exist. Choose which one to keep. The other copy will be overwritten.")
        }
        .alert("Migration Error", isPresented: Binding(
            get: { migrationManager.migrationError != nil },
            set: { _ in migrationManager.clearError() }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(migrationManager.migrationError ?? "")
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.makeContainer())
        .environmentObject(MigrationManager.preview)
}
