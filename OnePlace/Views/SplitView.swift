import SwiftData
import SwiftUI
import UIKit

struct SplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SplitPerson.name) private var people: [SplitPerson]
    @Query(sort: \SplitExpense.date, order: .reverse) private var expenses: [SplitExpense]

    @State private var showingAddPerson = false
    @State private var showingAddExpense = false
    @State private var showEditExpenseSheet = false
    @State private var showCopiedAlert = false
    @State private var selectedExpense: SplitExpense?

    var body: some View {
        NavigationStack {
            List {
                peopleSection
                balancesSection
                expensesSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Split")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Label("Add Expense", systemImage: "plus.circle")
                    }
                    Button {
                        showingAddPerson = true
                    } label: {
                        Label("Add Person", systemImage: "person.badge.plus")
                    }
                }
            }
            .alert("Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Balances copied to clipboard.")
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonSheet { person in
                    modelContext.insert(person)
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseSheet(people: people) { expense in
                    modelContext.insert(expense)
                }
            }
            .sheet(isPresented: $showEditExpenseSheet, onDismiss: { selectedExpense = nil }) {
                AddExpenseSheet(people: people, expenseToEdit: selectedExpense) { expense in
                    modelContext.insert(expense)
                }
            }
        }
    }

    private var peopleSection: some View {
        Section("People") {
            if people.isEmpty {
                Text("Add people to start splitting")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(people) { person in
                    Text(person.name)
                }
                .onDelete { indexSet in
                    indexSet.map { people[$0] }.forEach(modelContext.delete)
                }
            }
        }
    }

    private var balancesSection: some View {
        Section {
            if people.isEmpty {
                Text("Balances will appear here")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(people) { person in
                    let balance = balanceForPerson(person)
                    HStack {
                        Text(person.name)
                        Spacer()
                        Text(balance, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .foregroundStyle(balance >= 0 ? .green : .orange)
                    }
                }
            }
        } header: {
            HStack {
                Text("Balances")
                Spacer()
                Button {
                    copyBalances()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var expensesSection: some View {
        Section("Expenses") {
            if expenses.isEmpty {
                Text("No expenses yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(expenses) { expense in
                    ExpenseRow(
                        expense: expense
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editExpense(expense)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            deleteExpense(expense)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func balanceForPerson(_ person: SplitPerson) -> Double {
        let related = expenses.filter { $0.participants.contains(where: { $0.id == person.id }) }
        let totalPaid = expenses.filter { $0.paidBy?.id == person.id }.map(\.amount).reduce(0, +)
        let share = related.reduce(0) { partial, expense in
            let participantCount = expense.participants.count
            let count = Double(max(participantCount, 1))
            return partial + expense.amount / count
        }
        return totalPaid - share
    }

    private func copyBalances() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2

        let title = "Split balances (\(dateFormatter.string(from: Date())))"
        let lines = people.map { person -> String in
            let balance = balanceForPerson(person)
            let formatted = currencyFormatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
            return "\(person.name): \(formatted)"
        }
        let text = ([title] + lines).joined(separator: "\n")

        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showCopiedAlert = true
    }

    private func editExpense(_ expense: SplitExpense) {
        selectedExpense = expense
        showEditExpenseSheet = true
    }

    private func deleteExpense(_ expense: SplitExpense) {
        modelContext.delete(expense)
    }
}

private struct AddPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    let onSave: (SplitPerson) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
            .navigationTitle("New Person")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(SplitPerson(name: name))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

private struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let people: [SplitPerson]
    let expenseToEdit: SplitExpense?
    let onSave: (SplitExpense) -> Void

    @State private var title = ""
    @State private var amountText: String = ""
    @State private var date = Date()
    @State private var selectedParticipants: Set<UUID> = []
    @State private var paidBy: SplitPerson?
    @State private var hasLoaded = false

    init(
        people: [SplitPerson],
        expenseToEdit: SplitExpense? = nil,
        onSave: @escaping (SplitExpense) -> Void
    ) {
        self.people = people
        self.expenseToEdit = expenseToEdit
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Participants") {
                    if people.isEmpty {
                        Text("Add people first")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(people) { person in
                            Toggle(person.name, isOn: Binding(
                                get: { selectedParticipants.contains(person.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedParticipants.insert(person.id)
                                    } else {
                                        selectedParticipants.remove(person.id)
                                    }
                                }
                            ))
                        }
                    }
                }

                Section("Paid By") {
                    Picker("Paid By", selection: $paidBy) {
                        Text("Unassigned").tag(SplitPerson?.none)
                        ForEach(people) { person in
                            Text(person.name).tag(SplitPerson?.some(person))
                        }
                    }
                }
            }
            .navigationTitle(expenseToEdit == nil ? "New Expense" : "Edit Expense")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let amountValue = parsedAmount, amountValue > 0 else { return }
                        let participants = people.filter { selectedParticipants.contains($0.id) }
                        if let expenseToEdit {
                            expenseToEdit.title = title
                            expenseToEdit.amount = amountValue
                            expenseToEdit.date = date
                            expenseToEdit.participants = participants
                            expenseToEdit.paidBy = paidBy
                        } else {
                            let expense = SplitExpense(
                                title: title,
                                amount: amountValue,
                                date: date
                            )
                            expense.participants = participants
                            expense.paidBy = paidBy
                            onSave(expense)
                        }
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            guard let expenseToEdit else { return }
            title = expenseToEdit.title
            amountText = String(format: "%.2f", expenseToEdit.amount)
            date = expenseToEdit.date
            selectedParticipants = Set(expenseToEdit.participants.map(\.id))
            paidBy = expenseToEdit.paidBy
        }
    }

    private var parsedAmount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cleaned = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private var isSaveDisabled: Bool {
        guard let amountValue = parsedAmount, amountValue > 0 else { return true }
        return title.isEmpty || people.isEmpty
    }
}

private struct ExpenseRow: View {
    let expense: SplitExpense

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                HStack {
                    Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    Text("• \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                    if let paidBy = expense.paidBy {
                        Text("• Paid by \(paidBy.name)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    SplitView()
        .modelContainer(SampleData.makeContainer())
}
