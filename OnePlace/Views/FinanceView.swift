import SwiftData
import SwiftUI

struct FinanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceEntry.date, order: .reverse) private var entries: [FinanceEntry]

    @State private var searchText = ""
    @State private var selectedType: FinanceType?
    @State private var selectedUrgency: FinanceUrgency?
    @State private var showingAdd = false
    @State private var editingEntry: FinanceEntry?

    private var filteredEntries: [FinanceEntry] {
        entries.filter { entry in
            let matchesSearch = searchText.isEmpty
                || entry.category.localizedCaseInsensitiveContains(searchText)
                || entry.entryDescription.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || entry.type == selectedType
            let matchesUrgency = selectedUrgency == nil || entry.urgency == selectedUrgency
            return matchesSearch && matchesType && matchesUrgency
        }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                transactionsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Finance")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                FinanceEntryEditor(entry: nil) { newEntry in
                    modelContext.insert(newEntry)
                }
            }
            .sheet(item: $editingEntry) { entry in
                FinanceEntryEditor(entry: entry)
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                SummaryCard(title: "Net", value: netTotal, color: netTotal >= 0 ? .green : .red)
                SummaryCard(title: "Gain", value: gainTotal, color: .green)
                SummaryCard(title: "Owe", value: oweTotal, color: .orange)
            }
        }
        .listRowBackground(Color(.systemBackground))
    }

    private var transactionsSection: some View {
        Section("Transactions") {
            if filteredEntries.isEmpty {
                EmptyState(
                    title: "No transactions yet",
                    message: "Add income or expenses to see your history here.",
                    systemImage: "tray",
                    ctaTitle: "Add Transaction"
                ) {
                    showingAdd = true
                }
                .listRowBackground(Color(.systemBackground))
            } else {
                ForEach(filteredEntries) { entry in
                    FinanceRow(entry: entry)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingEntry = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
    }

    private var netTotal: Double {
        let gain = entries.filter { $0.type == .gain }.map(\.amount).reduce(0, +)
        let owe = entries.filter { $0.type == .owe }.map(\.amount).reduce(0, +)
        return gain - owe
    }

    private var gainTotal: Double {
        entries.filter { $0.type == .gain }.map(\.amount).reduce(0, +)
    }

    private var oweTotal: Double {
        entries.filter { $0.type == .owe }.map(\.amount).reduce(0, +)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Type", selection: $selectedType) {
                Text("All Types").tag(FinanceType?.none)
                ForEach(FinanceType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(FinanceType?.some(type))
                }
            }
            Picker("Urgency", selection: $selectedUrgency) {
                Text("All Urgency").tag(FinanceUrgency?.none)
                ForEach(FinanceUrgency.allCases, id: \.self) { urgency in
                    Text(urgency.rawValue.capitalized).tag(FinanceUrgency?.some(urgency))
                }
            }
            if selectedType != nil || selectedUrgency != nil {
                Button("Clear Filters") {
                    selectedType = nil
                    selectedUrgency = nil
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.headline)
                    .foregroundStyle(color)
            }
        }
    }
}

private struct FinanceRow: View {
    let entry: FinanceEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.category)
                    .font(.subheadline)
                Text(entry.entryDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline)
                    .foregroundStyle(entry.type == .gain ? .green : .orange)
                Text(entry.urgency.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FinanceEntryEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double
    @State private var type: FinanceType
    @State private var category: String
    @State private var description: String
    @State private var date: Date
    @State private var urgency: FinanceUrgency

    private let entry: FinanceEntry?
    private let onSave: ((FinanceEntry) -> Void)?

    init(entry: FinanceEntry?, onSave: ((FinanceEntry) -> Void)? = nil) {
        self.entry = entry
        self.onSave = onSave
        _amount = State(initialValue: entry?.amount ?? 0)
        _type = State(initialValue: entry?.type ?? .gain)
        _category = State(initialValue: entry?.category ?? "")
        _description = State(initialValue: entry?.entryDescription ?? "")
        _date = State(initialValue: entry?.date ?? Date())
        _urgency = State(initialValue: entry?.urgency ?? .medium)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Category", text: $category)
                    TextField("Description", text: $description)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Type", selection: $type) {
                        ForEach(FinanceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    Picker("Urgency", selection: $urgency) {
                        ForEach(FinanceUrgency.allCases, id: \.self) { urgency in
                            Text(urgency.rawValue.capitalized).tag(urgency)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(entry == nil ? "New Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let entry {
                            entry.amount = amount
                            entry.type = type
                            entry.category = category
                            entry.entryDescription = description
                            entry.date = date
                            entry.urgency = urgency
                        } else {
                            let newEntry = FinanceEntry(amount: amount, type: type, category: category, entryDescription: description, date: date, urgency: urgency)
                            onSave?(newEntry)
                        }
                        dismiss()
                    }
                    .disabled(category.isEmpty || description.isEmpty)
                }
            }
        }
    }
}

#Preview {
    FinanceView()
        .modelContainer(SampleData.makeContainer())
}
