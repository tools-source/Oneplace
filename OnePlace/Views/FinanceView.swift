import SwiftData
import SwiftUI

struct FinanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceEntry.date, order: .reverse) private var entries: [FinanceEntry]

    @State private var searchText = ""
    @State private var selectedType: FinanceType?
    @State private var selectedUrgency: FinanceUrgency?
    @State private var showingEditor = false
    @State private var editingEntry: FinanceEntry?

    private var filteredEntries: [FinanceEntry] {
        entries.filter { entry in
            let matchesSearch = searchText.isEmpty || entry.category.localizedCaseInsensitiveContains(searchText) || entry.entryDescription.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || entry.type == selectedType
            let matchesUrgency = selectedUrgency == nil || entry.urgency == selectedUrgency
            return matchesSearch && matchesType && matchesUrgency
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

    var body: some View {
        NavigationStack {
            List {
                summarySection
                newTransactionSection
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Finance")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
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
                SummaryCard(title: "Total Gain", value: gainTotal, color: .green)
                SummaryCard(title: "Total Owe", value: oweTotal, color: .orange)
            }
        }
        .listRowBackground(Color(.secondarySystemBackground))
    }

    private var newTransactionSection: some View {
        Section("New Transaction") {
            FinanceEntryEditor(entry: nil) { newEntry in
                modelContext.insert(newEntry)
            }
        }
    }

    private var historySection: some View {
        Section("History") {
            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                if let entries = groupedEntries[date] {
                    Section(header: Text(date, style: .date)) {
                        ForEach(entries) { entry in
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
        }
    }

    private var groupedEntries: [Date: [FinanceEntry]] {
        Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.headline)
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct FinanceRow: View {
    let entry: FinanceEntry

    var body: some View {
        HStack {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry == nil ? "Add Transaction" : "Edit Transaction")
                    .font(.headline)
                Spacer()
                if entry != nil {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
            }

            VStack(spacing: 10) {
                TextField("Category", text: $category)
                    .textFieldStyle(.roundedBorder)
                TextField("Description", text: $description)
                    .textFieldStyle(.roundedBorder)
                TextField("Amount", value: $amount, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
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
            .font(.subheadline)

            if entry == nil {
                Button {
                    let newEntry = FinanceEntry(amount: amount, type: type, category: category, entryDescription: description, date: date, urgency: urgency)
                    onSave?(newEntry)
                    reset()
                } label: {
                    Label("Add Transaction", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(category.isEmpty || description.isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func saveChanges() {
        guard let entry else { return }
        entry.amount = amount
        entry.type = type
        entry.category = category
        entry.entryDescription = description
        entry.date = date
        entry.urgency = urgency
    }

    private func reset() {
        amount = 0
        type = .gain
        category = ""
        description = ""
        date = Date()
        urgency = .medium
    }
}

#Preview {
    FinanceView()
        .modelContainer(SampleData.makeContainer())
}
