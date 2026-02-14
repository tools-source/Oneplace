import SwiftUI

struct FinanceView: View {
    @StateObject private var vm = FinanceViewModel()
    @State private var showingAdd = false
    @State private var editingEntry: FinanceEntryRecord?
    @State private var searchText = ""

    private var filteredEntries: [FinanceEntryRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.entries }

        return vm.entries.filter { entry in
            entry.category.localizedCaseInsensitiveContains(query)
            || entry.entryDescription.localizedCaseInsensitiveContains(query)
            || entry.type.rawValue.localizedCaseInsensitiveContains(query)
            || entry.urgency.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    private var gainTotal: Double {
        vm.entries
            .filter { $0.type == .gain }
            .reduce(0) { $0 + $1.amount }
    }

    private var oweTotal: Double {
        vm.entries
            .filter { $0.type == .owe }
            .reduce(0) { $0 + $1.amount }
    }

    private var netTotal: Double {
        gainTotal - oweTotal
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCards
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                }

                Section {
                    if vm.isLoading && vm.entries.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if filteredEntries.isEmpty {
                        EmptyState(
                            title: "No transactions yet",
                            message: "Tap Add Transaction to create your first entry.",
                            systemImage: "tray",
                            ctaTitle: "Add Transaction"
                        ) {
                            showingAdd = true
                        }
                        .padding(.vertical, 24)
                    } else {
                        ForEach(filteredEntries) { entry in
                            transactionRow(for: entry)
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Finance")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search transactions")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
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
            .sheet(item: $editingEntry) { entry in
                AddFinanceEntryView(entry: entry) { draft in
                    let updated = FinanceEntryRecord(
                        id: entry.id,
                        ownerUserId: entry.ownerUserId,
                        amount: draft.amount,
                        type: draft.type,
                        category: draft.category,
                        entryDescription: draft.entryDescription,
                        date: draft.date,
                        urgency: draft.urgency,
                        isCompleted: entry.isCompleted
                    )
                    Task { await vm.updateEntry(updated) }
                    editingEntry = nil
                }
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            StatCard(
                title: "Net",
                value: StatCard.currencyString(for: netTotal),
                icon: netTotal >= 0 ? "arrow.up.right" : "arrow.down.right",
                tint: netTotal >= 0 ? .blue : .red
            )
            StatCard(
                title: "Gain",
                value: StatCard.currencyString(for: gainTotal),
                icon: "arrow.up.circle.fill",
                tint: .green
            )
            StatCard(
                title: "Owe",
                value: StatCard.currencyString(for: oweTotal),
                icon: "arrow.down.circle.fill",
                tint: .red
            )
        }
    }

    @ViewBuilder
    private func transactionRow(for entry: FinanceEntryRecord) -> some View {
        let trimmedDescription = entry.entryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDescription = !trimmedDescription.isEmpty

        AppCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: entry.type == .gain ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(entry.type == .gain ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(hasDescription ? trimmedDescription : entry.category)
                            .font(.headline)
                            .strikethrough(entry.isCompleted)
                            .foregroundStyle(entry.isCompleted ? .secondary : .primary)
                            .lineLimit(1)

                        if entry.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    if hasDescription {
                        Text(entry.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No description")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(StatCard.currencyString(for: entry.amount))
                    .font(.headline)
                    .foregroundStyle(entry.type == .gain ? .green : .red)
                    .monospacedDigit()
            }
            .opacity(entry.isCompleted ? 0.78 : 1)
        }
        .contextMenu {
            Button {
                Task { await vm.toggleCompletion(for: entry) }
            } label: {
                Label(entry.isCompleted ? "Mark Undone" : "Mark Complete", systemImage: entry.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }

            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                Task { await vm.deleteEntry(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await vm.toggleCompletion(for: entry) }
            } label: {
                Label(entry.isCompleted ? "Undo" : "Complete", systemImage: entry.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)

            Button(role: .destructive) {
                Task { await vm.deleteEntry(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
