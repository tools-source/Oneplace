import SwiftData
import SwiftUI

struct SplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SplitPerson.name) private var people: [SplitPerson]
    @Query(sort: \SplitExpense.date, order: .reverse) private var expenses: [SplitExpense]

    @State private var showingAddPerson = false
    @State private var showingAddExpense = false

    var body: some View {
        NavigationStack {
            List {
                peopleSection
                balancesSection
                expensesSection
            }
            .listStyle(.insetGrouped)
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
        Section("Balances") {
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
        }
    }

    private var expensesSection: some View {
        Section("Expenses") {
            if expenses.isEmpty {
                Text("No expenses yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(expenses) { expense in
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
                }
                .onDelete { indexSet in
                    indexSet.map { expenses[$0] }.forEach(modelContext.delete)
                }
            }
        }
    }

    private func balanceForPerson(_ person: SplitPerson) -> Double {
        let related = expenses.filter { $0.participants.contains(where: { $0.id == person.id }) }
        let totalPaid = expenses.filter { $0.paidBy?.id == person.id }.map(\.amount).reduce(0, +)
        let share = related.reduce(0) { partial, expense in
            let count = Double(max(expense.participants.count, 1))
            return partial + expense.amount / count
        }
        return totalPaid - share
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
    let onSave: (SplitExpense) -> Void

    @State private var title = ""
    @State private var amount: Double = 0
    @State private var date = Date()
    @State private var selectedParticipants: Set<UUID> = []
    @State private var paidBy: SplitPerson?

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .number)
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
            .navigationTitle("New Expense")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let participants = people.filter { selectedParticipants.contains($0.id) }
                        let expense = SplitExpense(title: title, amount: amount, date: date, participants: participants, paidBy: paidBy)
                        onSave(expense)
                        dismiss()
                    }
                    .disabled(title.isEmpty || people.isEmpty)
                }
            }
        }
    }
}

#Preview {
    SplitView()
        .modelContainer(SampleData.makeContainer())
}
