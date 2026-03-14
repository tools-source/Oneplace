import SwiftUI
import UIKit

struct SplitView: View {
    @StateObject private var vm = SplitViewModel()

    @State private var showingAddPerson = false
    @State private var showingAddExpense = false
    @State private var editingExpense: SplitExpenseRecord?
    @State private var newPersonName = ""
    @State private var showingCopyAlert = false

    private var totalExpensesAmount: Double {
        vm.expenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                peopleSection
                expensesSection
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: DesignSystem.tabBarContentInset)
            }
            .navigationTitle("Split")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAddPerson = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }

                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(vm.people.isEmpty)
                }
            }
            .alert("Add Person", isPresented: $showingAddPerson) {
                TextField("Name", text: $newPersonName)
                Button("Add") {
                    let trimmed = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    Task { await vm.addPerson(name: trimmed) }
                    newPersonName = ""
                }
                Button("Cancel", role: .cancel) {
                    newPersonName = ""
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddSplitExpenseView(vm: vm) { draft in
                    Task { await vm.addExpense(draft: draft) }
                    showingAddExpense = false
                }
            }
            .sheet(item: $editingExpense) { expense in
                AddSplitExpenseView(vm: vm, expenseToEdit: expense) { draft in
                    var updated = expense
                    updated.title = draft.title
                    updated.amount = draft.amount
                    updated.date = draft.date
                    updated.participantIds = draft.participantIds
                    updated.paidById = draft.paidById
                    Task { await vm.updateExpense(updated) }
                    editingExpense = nil
                }
            }
            .alert("Split Error", isPresented: splitErrorBinding) {
                Button("OK", role: .cancel) {
                    vm.errorMessage = nil
                }
            } message: {
                Text(vm.errorMessage ?? "Please try again.")
            }
            .alert("Copied", isPresented: $showingCopyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The split summary was copied as text.")
            }
            .task {
                await vm.refresh()
            }
        }
    }

    private var splitErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    vm.errorMessage = nil
                }
            }
        )
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 10) {
                StatCard(
                    title: "People",
                    value: vm.people.count.formatted(),
                    icon: "person.2.fill",
                    tint: DesignSystem.accentColor
                )
                StatCard(
                    title: "Expenses",
                    value: StatCard.currencyString(for: totalExpensesAmount),
                    icon: "creditcard.fill",
                    tint: DesignSystem.warmAccent
                )
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .listRowBackground(Color.clear)
        }
    }

    private var peopleSection: some View {
        Section {
            if vm.isLoading && vm.people.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
            } else if vm.people.isEmpty {
                Text("Add people to start splitting.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(vm.people) { person in
                    personRow(for: person)
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        } header: {
            HStack {
                Text("People")

                Spacer()

                Button {
                    UIPasteboard.general.string = copySummaryText()
                    showingCopyAlert = true
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.accentColor)
                .disabled(vm.people.isEmpty && vm.expenses.isEmpty)
            }
        }
    }

    private var expensesSection: some View {
        Section("Expenses") {
            if vm.expenses.isEmpty {
                Text(vm.people.isEmpty ? "Add people first to record an expense." : "No expenses yet.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(vm.expenses) { expense in
                    expenseRow(for: expense)
                        .onTapGesture {
                            editingExpense = expense
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private func personRow(for person: SplitPersonRecord) -> some View {
        let balance = vm.getBalance(for: person)

        AppCard {
            HStack(spacing: 12) {
                ItemIconBadge(symbol: "person.fill", tint: balance >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.headline)

                    Text(personSubtitle(for: person))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(StatCard.currencyString(for: balance))
                    .font(.headline)
                    .foregroundStyle(balance >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await vm.deletePerson(person) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func expenseRow(for expense: SplitExpenseRecord) -> some View {
        AppCard {
            HStack(spacing: 12) {
                ItemIconBadge(symbol: expense.paidById == nil ? "person.2.fill" : "creditcard.fill", tint: DesignSystem.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.title)
                        .font(.headline)

                    Text(expenseSubtitle(for: expense))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(StatCard.currencyString(for: expense.amount))
                    .font(.headline)
                    .foregroundStyle(DesignSystem.accentColor)
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                editingExpense = expense
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(DesignSystem.accentColor)

            Button(role: .destructive) {
                Task { await vm.deleteExpense(expense) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func personSubtitle(for person: SplitPersonRecord) -> String {
        let count = vm.expenses.filter { $0.participantIds.contains(person.id) }.count
        return count == 1 ? "1 shared expense" : "\(count) shared expenses"
    }

    private func expenseSubtitle(for expense: SplitExpenseRecord) -> String {
        var parts = [expense.date.formatted(date: .abbreviated, time: .omitted)]

        let participantCount = expense.participantIds.count
        parts.append(participantCount == 1 ? "1 person" : "\(participantCount) people")

        if let paidById = expense.paidById,
           let payer = vm.people.first(where: { $0.id == paidById }) {
            parts.append("Paid by \(payer.name)")
        }

        return parts.joined(separator: " • ")
    }

    private func copySummaryText() -> String {
        let balanceLines = vm.people.map { person in
            let balance = vm.getBalance(for: person)
            return "\(person.name): \(StatCard.currencyString(for: balance))"
        }

        let expenseLines = vm.expenses.map { expense in
            let paidByName = expense.paidById.flatMap { payerID in
                vm.people.first(where: { $0.id == payerID })?.name
            } ?? "No payer"

            return "\(expense.title) - \(StatCard.currencyString(for: expense.amount)) on \(expense.date.formatted(date: .abbreviated, time: .omitted)) paid by \(paidByName)"
        }

        var lines = ["Split Summary", ""]
        if !balanceLines.isEmpty {
            lines.append("People")
            lines.append(contentsOf: balanceLines)
        }
        if !expenseLines.isEmpty {
            if !balanceLines.isEmpty {
                lines.append("")
            }
            lines.append("Expenses")
            lines.append(contentsOf: expenseLines)
        }

        return lines.joined(separator: "\n")
    }
}

private struct AddSplitExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: SplitViewModel

    @State private var title = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var selectedPaidBy: String? = nil
    @State private var selectedParticipants: Set<String> = []

    private let expenseToEdit: SplitExpenseRecord?
    private let onSave: (SplitExpenseDraft) -> Void

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    init(vm: SplitViewModel, expenseToEdit: SplitExpenseRecord? = nil, onSave: @escaping (SplitExpenseDraft) -> Void) {
        self.vm = vm
        self.expenseToEdit = expenseToEdit
        self.onSave = onSave

        _title = State(initialValue: expenseToEdit?.title ?? "")

        if let expense = expenseToEdit {
            _amountText = State(initialValue: Self.amountFormatter.string(from: NSNumber(value: expense.amount)) ?? "")
            _date = State(initialValue: expense.date)
            _selectedPaidBy = State(initialValue: expense.paidById)
            _selectedParticipants = State(initialValue: Set(expense.participantIds))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Expense title", text: $title)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Paid By") {
                    Picker("Who paid?", selection: $selectedPaidBy) {
                        Text("Unassigned").tag(String?.none)
                        ForEach(vm.people) { person in
                            Text(person.name).tag(String?.some(person.id))
                        }
                    }
                }

                Section("Participants") {
                    if vm.people.isEmpty {
                        Text("Add people first")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.people) { person in
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
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle(expenseToEdit == nil ? "New Expense" : "Edit Expense")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let amount = parsedAmount, amount > 0 else { return }

                        let draft = SplitExpenseDraft(
                            title: title,
                            amount: amount,
                            date: date,
                            participantIds: Array(selectedParticipants),
                            paidById: selectedPaidBy
                        )
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var parsedAmount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: ""))
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedParticipants.isEmpty ||
        (parsedAmount ?? 0) <= 0
    }
}
