import SwiftUI

struct AddFinanceEntryView: View {
    let onSave: (FinanceEntryDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var category: String = ""
    @State private var entryDescription: String = ""
    @State private var date: Date = .now
    @State private var type: FinanceType = .init(rawValue: "income") ?? .init(rawValue: FinanceType.allCases.first?.rawValue ?? "")!
    @State private var urgency: FinanceUrgency = .init(rawValue: FinanceUrgency.allCases.first?.rawValue ?? "")!

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Details") {
                    Picker("Type", selection: $type) {
                        ForEach(FinanceType.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }

                    TextField("Category", text: $category)
                    TextField("Description", text: $entryDescription)

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Picker("Urgency", selection: $urgency) {
                        ForEach(FinanceUrgency.allCases, id: \.self) { u in
                            Text(u.rawValue.capitalized).tag(u)
                        }
                    }
                }
            }
            .navigationTitle("Add Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
}
