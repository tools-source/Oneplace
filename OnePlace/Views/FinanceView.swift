import SwiftUI
import UIKit

private enum FinancePreferenceKey {
    static let customOrder = "finance.customOrder"
    static let filterType = "finance.filter.type"
    static let filterCategory = "finance.filter.category"
    static let hideCompleted = "finance.filter.hideCompleted"
}

struct FinanceView: View {
    @StateObject private var vm = FinanceViewModel()
    @Environment(\.editMode) private var editMode

    @State private var showingAdd = false
    @State private var editingEntry: FinanceEntryRecord?
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedEntryIDs = Set<String>()

    @State private var showingFilters = false
    @State private var filters: FinanceFilters
    @State private var customOrderIDs: [String]

    init() {
        _filters = State(initialValue: Self.loadSavedFilters())
        _customOrderIDs = State(
            initialValue: UserDefaults.standard.stringArray(forKey: FinancePreferenceKey.customOrder) ?? []
        )
    }

    // MARK: - Filtering + Ordering

    private var defaultOrderedEntries: [FinanceEntryRecord] {
        vm.entries.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }

            return lhs.id > rhs.id
        }
    }

    private var displayedEntries: [FinanceEntryRecord] {
        applyCustomOrder(to: defaultOrderedEntries)
    }

    private var filteredEntries: [FinanceEntryRecord] {
        var base = displayedEntries

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

        return base
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

    private var selectedEntries: [FinanceEntryRecord] {
        filteredEntries.filter { selectedEntryIDs.contains($0.id) }
    }

    private var selectedNetTotal: Double {
        selectedEntries.reduce(0) { partialResult, entry in
            partialResult + signedAmount(for: entry)
        }
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

                if isSelecting {
                    Section {
                        selectionSummaryCard
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 8, trailing: 8))
                            .listRowBackground(Color.clear)
                    }
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
                            .listRowSeparator(.hidden)

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
                                    if isSelecting {
                                        toggleSelection(for: entry)
                                    } else {
                                        editingEntry = entry
                                    }
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
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: DesignSystem.tabBarContentInset)
            }
            .navigationTitle("Finance")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search transactions"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isSelecting ? "Done" : "Select") {
                        toggleSelectionMode()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {

                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: filters.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }

                    EditButton()
                        .disabled(isSelecting)

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
            .alert("Finance Error", isPresented: financeErrorBinding) {
                Button("OK", role: .cancel) {
                    vm.clearError()
                }
            } message: {
                Text(vm.errorMessage ?? "Please try again.")
            }
            .onChange(of: filters) { _, newFilters in
                saveFilters(newFilters)
            }
            .onChange(of: vm.entries) { _, newEntries in
                sanitizeCustomOrder(using: newEntries)
                sanitizeSelection(using: newEntries)
            }
            .task {
                await vm.refresh()
                sanitizeCustomOrder(using: vm.entries)
                sanitizeSelection(using: vm.entries)
            }
        }
    }

    private var financeErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    vm.clearError()
                }
            }
        )
    }

    // MARK: - Transaction Row

    @ViewBuilder
    private func transactionRow(for entry: FinanceEntryRecord) -> some View {
        let isSelected = selectedEntryIDs.contains(entry.id)

        AppCard {
            HStack(spacing: 12) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? DesignSystem.accentColor : DesignSystem.secondaryTextColor)
                }

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
                    .foregroundStyle(entry.type == .gain ? DesignSystem.gainColor : DesignSystem.oweColor)
            }
            .opacity(entry.isCompleted ? 0.6 : 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? DesignSystem.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1.4
                )
        }
        // Swipe Actions (ONLY here — no duplicates)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await vm.toggleCompletion(for: entry) }
            } label: {
                Label(entry.isCompleted ? "Undo" : "Complete",
                      systemImage: entry.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(DesignSystem.gainColor)
        }
        .swipeActions(edge: .trailing) {
            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(DesignSystem.accentColor)

            Button(role: .destructive) {
                Task { await vm.deleteEntry(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Reorder

    private func moveEntries(from source: IndexSet, to destination: Int) {
        let visibleEntries = filteredEntries
        var reorderedVisibleEntries = visibleEntries
        reorderedVisibleEntries.move(fromOffsets: source, toOffset: destination)

        let visibleIDs = Set(visibleEntries.map(\.id))
        var reorderedIterator = reorderedVisibleEntries.makeIterator()

        customOrderIDs = displayedEntries.map { entry in
            guard visibleIDs.contains(entry.id), let reorderedEntry = reorderedIterator.next() else {
                return entry.id
            }

            return reorderedEntry.id
        }

        saveCustomOrder()
    }

    private func saveCustomOrder() {
        UserDefaults.standard.set(customOrderIDs, forKey: FinancePreferenceKey.customOrder)
    }

    private func sanitizeCustomOrder(using entries: [FinanceEntryRecord]) {
        let validIDs = Set(entries.map(\.id))
        let sanitized = customOrderIDs.filter(validIDs.contains)

        guard sanitized != customOrderIDs else { return }

        customOrderIDs = sanitized
        saveCustomOrder()
    }

    private func sanitizeSelection(using entries: [FinanceEntryRecord]) {
        let validIDs = Set(entries.map(\.id))
        selectedEntryIDs = Set(selectedEntryIDs.filter(validIDs.contains))
    }

    private func saveFilters(_ filters: FinanceFilters) {
        let defaults = UserDefaults.standard
        defaults.set(filters.type?.rawValue ?? "", forKey: FinancePreferenceKey.filterType)
        defaults.set(filters.category ?? "", forKey: FinancePreferenceKey.filterCategory)
        defaults.set(filters.hideCompleted, forKey: FinancePreferenceKey.hideCompleted)
    }

    private static func loadSavedFilters() -> FinanceFilters {
        let defaults = UserDefaults.standard
        let type = FinanceType(rawValue: defaults.string(forKey: FinancePreferenceKey.filterType) ?? "")
        let category = defaults.string(forKey: FinancePreferenceKey.filterCategory)
        let savedCategory = category?.isEmpty == true ? nil : category

        return FinanceFilters(
            type: type,
            category: savedCategory,
            hideCompleted: defaults.bool(forKey: FinancePreferenceKey.hideCompleted)
        )
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            StatCard(title: "Net",
                     value: StatCard.currencyString(for: netTotal),
                     icon: "plus",
                     tint: netTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor)

            StatCard(title: "Gain",
                     value: StatCard.currencyString(for: gainTotal),
                     icon: "arrow.up.right",
                     tint: DesignSystem.gainColor)

            StatCard(title: "Owe",
                     value: StatCard.currencyString(for: oweTotal),
                     icon: "arrow.down.right",
                     tint: DesignSystem.oweColor)
        }
    }

    private var selectionSummaryCard: some View {
        AppCard {
            HStack(spacing: 12) {
                ItemIconBadge(
                    symbol: selectedEntryIDs.isEmpty ? "checklist.unchecked" : "checkmark.circle.fill",
                    tint: selectedNetTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Total")
                        .font(.headline)

                    Text(selectedEntryIDs.isEmpty ? "Tap transactions to add them to the total." : "\(selectedEntryIDs.count) item\(selectedEntryIDs.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(StatCard.currencyString(for: selectedNetTotal))
                        .font(.headline)
                        .foregroundStyle(selectedNetTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor)

                    if !selectedEntryIDs.isEmpty {
                        Button("Clear") {
                            selectedEntryIDs.removeAll()
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    private func toggleSelectionMode() {
        isSelecting.toggle()
        if !isSelecting {
            selectedEntryIDs.removeAll()
        }
        editMode?.wrappedValue = .inactive
    }

    private func toggleSelection(for entry: FinanceEntryRecord) {
        if selectedEntryIDs.contains(entry.id) {
            selectedEntryIDs.remove(entry.id)
        } else {
            selectedEntryIDs.insert(entry.id)
        }
    }

    private func signedAmount(for entry: FinanceEntryRecord) -> Double {
        entry.type == .gain ? entry.amount : -entry.amount
    }
}

// MARK: - Filters

private struct FinanceFilters: Equatable {
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
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
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
