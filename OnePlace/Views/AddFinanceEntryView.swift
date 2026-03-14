import SwiftUI

struct AddFinanceEntryView: View {
    private static let lastCategoryKey = "finance.lastCategory"

    let entry: FinanceEntryRecord?
    let onSave: (FinanceEntryDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var category: String
    @State private var entryDescription: String
    @State private var date: Date
    @State private var type: FinanceType
    @State private var urgency: FinanceUrgency

    init(entry: FinanceEntryRecord? = nil, onSave: @escaping (FinanceEntryDraft) -> Void) {
        self.entry = entry
        self.onSave = onSave
        let initialCategory = Self.initialCategory(for: entry)
        _amountText = State(initialValue: entry.map { String(format: "%.2f", $0.amount) } ?? "")
        _category = State(initialValue: initialCategory)
        _entryDescription = State(initialValue: entry?.entryDescription ?? "")
        _date = State(initialValue: entry?.date ?? .now)
        _type = State(initialValue: entry?.type ?? Self.type(for: initialCategory))
        _urgency = State(initialValue: entry?.urgency ?? .medium)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    fieldRow(label: "Description") {
                        TextField("Description", text: $entryDescription)
                    }

                    fieldRow(label: "Amount") {
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)

                Section("Details") {
                    Picker("Category", selection: $category) {
                        ForEach(FinanceCategory.incomeRawValues, id: \.self) { item in
                            Text(item).tag(item)
                        }
                        ForEach(FinanceCategory.expenseRawValues, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }

                    HStack {
                        Text("Type")
                        Spacer()
                        Label(type == .gain ? "Gain" : "Owe", systemImage: type == .gain ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(type == .gain ? DesignSystem.gainColor : DesignSystem.oweColor)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Picker("Urgency", selection: $urgency) {
                        ForEach(FinanceUrgency.allCases, id: \.self) { u in
                            Text(u.rawValue.capitalized).tag(u)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle(entry == nil ? "New Transaction" : "Edit Transaction")
            .onAppear {
                if category.isEmpty {
                    category = Self.rememberedCategory()
                }
                updateTypeFromCategory()
            }
            .onChange(of: category) { _, newCategory in
                updateTypeFromCategory()
                rememberCategoryIfNeeded(newCategory)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(entry == nil ? "Add" : "Save") {
                        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: "")) else { return }

                        let draft = FinanceEntryDraft(
                            amount: amount,
                            type: type,
                            category: category,
                            entryDescription: entryDescription,
                            date: date,
                            urgency: urgency
                        )
                        rememberCategoryIfNeeded(category)
                        onSave(draft)
                    }
                    .disabled(Double(amountText.replacingOccurrences(of: ",", with: "")) == nil || category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .font(.body)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.cardBorderColor)
        )
    }

    private func updateTypeFromCategory() {
        type = Self.type(for: category)
    }

    private func rememberCategoryIfNeeded(_ category: String) {
        guard entry == nil, Self.isKnownCategory(category) else { return }
        UserDefaults.standard.set(category, forKey: Self.lastCategoryKey)
    }

    private static func initialCategory(for entry: FinanceEntryRecord?) -> String {
        let candidate = entry?.category ?? rememberedCategory()
        return isKnownCategory(candidate) ? candidate : (FinanceCategory.expenseRawValues.first ?? "")
    }

    private static func rememberedCategory() -> String {
        let saved = UserDefaults.standard.string(forKey: lastCategoryKey) ?? ""
        return isKnownCategory(saved) ? saved : (FinanceCategory.expenseRawValues.first ?? "")
    }

    private static func isKnownCategory(_ value: String) -> Bool {
        (FinanceCategory.incomeRawValues + FinanceCategory.expenseRawValues).contains(value)
    }

    private static func type(for category: String) -> FinanceType {
        FinanceCategory.incomeRawValues.contains(category) ? .gain : .owe
    }
}
