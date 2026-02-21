import SwiftUI

struct HelpView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Welcome to One Place") {
                    Text("Manage finances, bills, tasks, shared expenses, and communication cards across your devices.")
                }
                Section("Getting Started") {
                    Label("Add a transaction in Finance to track gains and owes.", systemImage: "banknote")
                    Label("Plan recurring bills and income in Flow.", systemImage: "calendar.badge.clock")
                    Label("Organize tasks with priorities and due dates.", systemImage: "checklist")
                    Label("Split expenses with friends or family.", systemImage: "person.2.fill")
                    Label("Create communication cards with audio and images.", systemImage: "quote.bubble")
                }
                Section("Privacy") {
                    Text("OnePlace uses Firebase Authentication and Cloud Firestore to sync your data securely. We do not sell, rent, or share personal data for advertising.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Help")
        }
    }
}

#Preview {
    HelpView()
}
