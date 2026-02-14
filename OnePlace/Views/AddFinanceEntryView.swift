import SwiftUI

struct AddFinanceEntryView: View {
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
        _amountText = State(initialValue: entry.map { String(format: "%.2f", $0.amount) } ?? "")
        _category = State(initialValue: entry?.category ?? FinanceCategory.expenseRawValues.first ?? "")
        _entryDescription = State(initialValue: entry?.entryDescription ?? "")
        _date = State(initialValue: entry?.date ?? .now)
        _type = State(initialValue: entry?.type ?? .owe)
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
                            .foregroundStyle(type == .gain ? .green : .red)
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
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(entry == nil ? "New Transaction" : "Edit Transaction")
            .onAppear {
                if category.isEmpty {
                    category = FinanceCategory.expenseRawValues.first ?? ""
                }
                updateTypeFromCategory()
            }
            .onChange(of: category) { _, _ in
                updateTypeFromCategory()
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15))
        )
    }

    private func updateTypeFromCategory() {
        type = FinanceCategory.incomeRawValues.contains(category) ? .gain : .owe
    }
}
