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
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(
                    title: "Net",
                    value: netTotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                    subtitle: nil,
                    icon: "chart.line.uptrend.xyaxis",
                    tint: netTotal >= 0 ? .green : .red
                )
                StatCard(
                    title: "Gain",
                    value: gainTotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                    subtitle: nil,
                    icon: "arrow.up.right.circle.fill",
                    tint: .green
                )
                StatCard(
                    title: "Owe",
                    value: oweTotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                    subtitle: nil,
                    icon: "arrow.down.right.circle.fill",
                    tint: .orange
                )
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

private struct FinanceRow: View {
    let entry: FinanceEntry

    var body: some View {
        let description = entry.entryDescription
        let category = entry.category
        let title = description.isEmpty ? category : description
        let subtitle = description.isEmpty ? "" : category

        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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

    @AppStorage("lastCategory") private var lastCategoryRaw: String = ""

    @State private var amountText: String
    @State private var type: FinanceType
    @State private var selectedCategory: String
    @State private var description: String
    @State private var date: Date
    @State private var urgency: FinanceUrgency
    @State private var userSelectedCategory: Bool
    @State private var isAutoSelectingCategory = false
    @State private var typeWasManuallySet = false
    @State private var isAutoSettingType = false

    private let entry: FinanceEntry?
    private let onSave: ((FinanceEntry) -> Void)?

    private let expenseCategories = FinanceCategory.expenseRawValues
    private let incomeCategories = FinanceCategory.incomeRawValues
    private let categorySuggestions: [String: String] = [
        "uber": "Transport",
        "lyft": "Transport",
        "rent": "Bills & Utilities",
        "gas": "Transport",
        "fuel": "Transport",
        "amazon": "Shopping",
        "grocery": "Food & Dining",
        "restaurant": "Food & Dining",
        "netflix": "Entertainment",
        "doctor": "Healthcare",
        "tuition": "Education",
        "salary": "Salary",
        "paycheck": "Salary",
        "freelance": "Freelance",
        "investment": "Investments"
    ]
    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    init(entry: FinanceEntry?, onSave: ((FinanceEntry) -> Void)? = nil) {
        self.entry = entry
        self.onSave = onSave
        if let entry {
            let formattedAmount = Self.amountFormatter.string(from: NSNumber(value: entry.amount)) ?? ""
            _amountText = State(initialValue: formattedAmount)
        } else {
            _amountText = State(initialValue: "")
        }
        _type = State(initialValue: entry?.type ?? .gain)
        _selectedCategory = State(initialValue: entry?.category ?? "")
        _description = State(initialValue: entry?.entryDescription ?? "")
        _date = State(initialValue: entry?.date ?? Date())
        _urgency = State(initialValue: entry?.urgency ?? .medium)
        _userSelectedCategory = State(initialValue: entry != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Description", text: $description)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $selectedCategory) {
                        if let customCategory {
                            Section("Current") {
                                Text(customCategory).tag(customCategory)
                            }
                        }
                        Section("Income") {
                            ForEach(incomeCategories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        Section("Expense") {
                            ForEach(expenseCategories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                    }
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
            .onAppear {
                guard entry == nil else { return }
                applyInitialCategorySelection()
            }
            .onChange(of: type) { _, _ in
                if isAutoSettingType {
                    isAutoSettingType = false
                    return
                }
                typeWasManuallySet = true
                guard !userSelectedCategory else { return }
                applyInitialCategorySelection()
            }
            .onChange(of: description) { _, newValue in
                guard !userSelectedCategory else { return }
                applySuggestedCategory(for: newValue)
            }
            .onChange(of: selectedCategory) { _, newValue in
                if isAutoSelectingCategory {
                    isAutoSelectingCategory = false
                } else {
                    userSelectedCategory = true
                    typeWasManuallySet = false
                }
                applyAutoTypeSelection(for: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let amountValue = parsedAmount else { return }
                        if let entry {
                            entry.amount = amountValue
                            entry.type = type
                            entry.category = selectedCategory
                            entry.entryDescription = description
                            entry.date = date
                            entry.urgency = urgency
                        } else {
                            let newEntry = FinanceEntry(amount: amountValue, type: type, category: selectedCategory, entryDescription: description, date: date, urgency: urgency)
                            onSave?(newEntry)
                        }
                        lastCategoryRaw = selectedCategory
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var allCategories: [String] {
        incomeCategories + expenseCategories
    }

    private var customCategory: String? {
        guard !selectedCategory.isEmpty, !allCategories.contains(selectedCategory) else { return nil }
        return selectedCategory
    }

    private var parsedAmount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let number = Self.amountFormatter.number(from: trimmed) {
            return number.doubleValue
        }
        return Double(trimmed)
    }

    private var isSaveDisabled: Bool {
        guard let amountValue = parsedAmount, amountValue > 0 else { return true }
        return selectedCategory.isEmpty
    }

    private func applyInitialCategorySelection() {
        let defaultCategory = type == .gain ? FinanceCategory.otherIncome.rawValue : FinanceCategory.otherExpense.rawValue
        let targetCategory = allCategories.contains(lastCategoryRaw) ? lastCategoryRaw : defaultCategory
        isAutoSelectingCategory = true
        selectedCategory = targetCategory
    }

    private func applySuggestedCategory(for text: String) {
        let lowered = text.lowercased()
        guard let suggestion = categorySuggestions.first(where: { lowered.contains($0.key) })?.value else {
            return
        }
        guard allCategories.contains(suggestion) else { return }
        isAutoSelectingCategory = true
        selectedCategory = suggestion
    }

    private func applyAutoTypeSelection(for category: String) {
        guard !typeWasManuallySet else { return }
        if expenseCategories.contains(category) {
            setTypeIfNeeded(.owe)
        } else if incomeCategories.contains(category) {
            setTypeIfNeeded(.gain)
        }
    }

    private func setTypeIfNeeded(_ newType: FinanceType) {
        guard type != newType else { return }
        isAutoSettingType = true
        type = newType
    }
}

#Preview {
    FinanceView()
        .modelContainer(SampleData.makeContainer())
}
