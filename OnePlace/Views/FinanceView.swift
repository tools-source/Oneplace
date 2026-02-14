import SwiftUI

struct FinanceView: View {
    @StateObject private var vm = FinanceViewModel()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.entries.isEmpty {
                    ProgressView("Loading…")
                } else if vm.entries.isEmpty {
                    ContentUnavailableView("No entries yet", systemImage: "tray")
                } else {
                    List {
                        ForEach(vm.entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.category)
                                        .font(.headline)
                                    Spacer()
                                    Text(entry.amount, format: .currency(code: "USD"))
                                        .font(.headline)
                                }

                                if !entry.entryDescription.isEmpty {
                                    Text(entry.entryDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 6) {
                                    Text(entry.type.rawValue.capitalized)
                                    Text("•")
                                    Text(entry.urgency.rawValue.capitalized)
                                    Spacer()
                                    Text(entry.date, style: .date)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.deleteEntry(entry) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Finance")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .task { await vm.refresh() }
            .refreshable { await vm.refresh() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.clearError() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showingAdd) {
                AddFinanceEntryView { draft in
                    Task { await vm.addEntry(draft: draft) }
                    showingAdd = false
                }
            }
        }
    }
}
