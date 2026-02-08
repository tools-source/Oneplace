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
        .alert("Move local data to iCloud?", isPresented: $migrationManager.shouldShowPrompt) {
            Button("Move to iCloud", role: .none) {
                Task { await migrationManager.migrateToCloud() }
            }
            Button("Keep Local Only", role: .cancel) {
                migrationManager.keepLocalOnly()
            }
        } message: {
            Text("Your existing data can be moved to iCloud so it syncs across devices and survives reinstalls.")
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
