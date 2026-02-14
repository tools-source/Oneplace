import SwiftUI
import UIKit

struct FinanceView: View {
    @StateObject private var vm = FinanceViewModel()
    @Environment(\.editMode) private var editMode

    @State private var showingAdd = false
    @State private var editingEntry: FinanceEntryRecord?
    @State private var searchText = ""

    @State private var showingFilters = false
    @State private var filters = FinanceFilters()
    @State private var customOrderIDs: [String] = []

    // MARK: - Filtering + Ordering

    private var filteredEntries: [FinanceEntryRecord] {
        var base = vm.entries

        // Search
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            base = base.filter {
                $0.category.localizedCaseInsensitiveContains(query) ||
                $0.entryDescription.localizedCaseInsensitiveContains(query) ||
                $0.type.rawValue.localizedCaseInsensitiveContains(query)
            }
        }

        // Filters
        base = base.filter { entry in
            if let type = filters.type, entry.type != type { return false }
            if let category = filters.category, entry.category != category { return false }
            if filters.hideCompleted && entry.isCompleted { return false }
            return true
        }

        return applyCustomOrder(to: base)
    }

    private func applyCustomOrder(to entries: [FinanceEntryRecord]) -> [FinanceEntryRecord] {
        guard !customOrderIDs.isEmpty else { return entries }

        let map = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let ordered = customOrderIDs.compactMap { map[$0] }
        let remaining = entries.filter { !customOrderIDs.contains($0.id) }
        return ordered + remaining
    }

    // MARK: - Totals (exclude completed)

    private var gainTotal: Double {
        vm.entries
            .filter { $0.type == .gain && !$0.isCompleted }
            .reduce(0) { $0 + $1.amount }
    }

    private var oweTotal: Double {
        vm.entries
            .filter { $0.type == .owe && !$0.isCompleted }
            .reduce(0) { $0 + $1.amount }
    }

    private var netTotal: Double {
        gainTotal - oweTotal
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Summary Cards
                Section {
                    summaryCards
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                }

                // Transactions
                Section {

                    if vm.isLoading && vm.entries.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .listRowBackground(Color.clear)

                    } else if filteredEntries.isEmpty {
                        Text("No transactions found.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)

                    } else {

                        if editMode?.wrappedValue.isEditing != true {
                            Text("Tip: Swipe a transaction for actions. Tap Edit to reorder by dragging.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        ForEach(filteredEntries) { entry in
                            transactionRow(for: entry)
                                .onTapGesture {
                                    editingEntry = entry
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onMove(perform: moveEntries)
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Finance")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {

                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: filters.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }

                    EditButton()

                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
            .sheet(isPresented: $showingFilters) {
                FinanceFilterSheet(filters: $filters,
                                   categories: Array(Set(vm.entries.map(\.category))).sorted())
            }
            .task {
                await vm.refresh()
                loadCustomOrder()
            }
        }
    }

    // MARK: - Transaction Row

    @ViewBuilder
    private func transactionRow(for entry: FinanceEntryRecord) -> some View {

        AppCard {
            HStack(spacing: 12) {

                FinanceTypeBadge(type: entry.type)

                VStack(alignment: .leading, spacing: 4) {

                    Text(entry.entryDescription.isEmpty ? entry.category : entry.entryDescription)
                        .font(.headline)
                        .strikethrough(entry.isCompleted)

                    Text("\(entry.category) • \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(StatCard.currencyString(for: entry.amount))
                    .font(.headline)
                    .foregroundStyle(entry.type == .gain ? .green : .red)
            }
            .opacity(entry.isCompleted ? 0.6 : 1)
        }
        // Swipe Actions (ONLY here — no duplicates)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await vm.toggleCompletion(for: entry) }
            } label: {
                Label(entry.isCompleted ? "Undo" : "Complete",
                      systemImage: entry.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
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

    // MARK: - Reorder

    private func moveEntries(from source: IndexSet, to destination: Int) {
        var items = filteredEntries
        items.move(fromOffsets: source, toOffset: destination)
        customOrderIDs = items.map(\.id)
        UserDefaults.standard.set(customOrderIDs, forKey: "finance.customOrder")
    }

    private func loadCustomOrder() {
        if let saved = UserDefaults.standard.array(forKey: "finance.customOrder") as? [String] {
            customOrderIDs = saved
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 10) {
            StatCard(title: "Net",
                     value: StatCard.currencyString(for: netTotal),
                     icon: "plus",
                     tint: .green)

            StatCard(title: "Gain",
                     value: StatCard.currencyString(for: gainTotal),
                     icon: "arrow.up.right",
                     tint: .green)

            StatCard(title: "Owe",
                     value: StatCard.currencyString(for: oweTotal),
                     icon: "arrow.down.right",
                     tint: .red)
        }
    }
}

// MARK: - Filters

private struct FinanceFilters {
    var type: FinanceType? = nil
    var category: String? = nil
    var hideCompleted = false

    var isActive: Bool {
        type != nil || category != nil || hideCompleted
    }
}

private struct FinanceFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: FinanceFilters
    let categories: [String]

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $filters.type) {
                        Text("All").tag(FinanceType?.none)
                        Text("Gain").tag(FinanceType?.some(.gain))
                        Text("Owe").tag(FinanceType?.some(.owe))
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $filters.category) {
                        Text("All").tag(String?.none)
                        ForEach(categories, id: \.self) {
                            Text($0).tag(String?.some($0))
                        }
                    }
                }

                Section("Status") {
                    Toggle("Hide completed", isOn: $filters.hideCompleted)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        filters = FinanceFilters()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
