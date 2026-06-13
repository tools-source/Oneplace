import SwiftUI
import UIKit

struct SplitView: View {
    @StateObject private var vm = SplitViewModel()
    @EnvironmentObject private var aiAssistant: AIAssistantManager
    @Environment(\.editMode) private var editMode

    @State private var showingPersonEditor = false
    @State private var editingPerson: SplitPersonRecord?
    @State private var showingAddExpense = false
    @State private var editingExpense: SplitExpenseRecord?
    @State private var newPersonName = ""
    @State private var showingCopyAlert = false
    @State private var showingClearConfirm = false
    @State private var searchText = ""
    @State private var lastRefreshToken: UUID?

    private var totalExpensesAmount: Double {
        vm.expenses.reduce(0) { $0 + $1.amount }
    }

    private var filteredPeople: [SplitPersonRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.people }
        return vm.people.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filteredExpenses: [SplitExpenseRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.expenses }
        return vm.expenses.filter { expense in
            expense.title.localizedCaseInsensitiveContains(query) ||
            expenseSubtitle(for: expense).localizedCaseInsensitiveContains(query)
        }
    }

    private var canReorderPeople: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vm.isLoading &&
        vm.people.count > 1
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OnePlaceAISearchBar(
                        text: $searchText,
                        placeholder: "Search or ask OnePlace",
                        isProcessing: vm.isLoading,
                        onSubmit: handleSearchSubmit
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
                }

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
                    EditButton()
                        .disabled(!canReorderPeople)

                    Button {
                        presentPersonEditor()
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

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All", role: .destructive) {
                        showingClearConfirm = true
                    }
                    .disabled(vm.people.isEmpty && vm.expenses.isEmpty)
                }
            }
            .alert(editingPerson == nil ? "Add Person" : "Edit Person", isPresented: $showingPersonEditor) {
                TextField("Name", text: $newPersonName)
                Button(editingPerson == nil ? "Add" : "Save") {
                    savePersonEditor()
                }
                Button("Cancel", role: .cancel) {
                    resetPersonEditor()
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddSplitExpenseView(vm: vm) { draft in
                    Task {
                        await vm.addExpense(draft: draft)
                        showingAddExpense = false
                    }
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
            .alert("Clear All?", isPresented: $showingClearConfirm) {
                Button("Clear All", role: .destructive) {
                    Task { await vm.clearAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all people and expenses.")
            }
            .task {
                await vm.refresh()
            }
            .onChange(of: aiAssistant.pendingActionsToken) { _, newToken in
                guard lastRefreshToken != newToken else { return }
                lastRefreshToken = newToken
                Task { await vm.refresh() }
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
                EmptyState(
                    title: "Add people to start",
                    message: "Create people first, then record shared expenses and balances.",
                    systemImage: "person.badge.plus",
                    ctaTitle: "Add Person"
                ) {
                    presentPersonEditor()
                }
                .padding(.vertical, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if filteredPeople.isEmpty {
                EmptyState(
                    title: "No matching people",
                    message: "Try a different search term.",
                    systemImage: "magnifyingglass",
                    ctaTitle: nil
                )
                .padding(.vertical, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredPeople) { person in
                    personRow(for: person)
                        .onTapGesture {
                            presentPersonEditor(for: person)
                        }
                        .moveDisabled(!canReorderPeople)
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove(perform: movePeople)
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
            if filteredExpenses.isEmpty {
                EmptyState(
                    title: vm.people.isEmpty ? "Add people first" : "No expenses yet",
                    message: vm.people.isEmpty ? "Once people are added, you can split expenses between them." : "Record a shared cost and OnePlace will calculate balances.",
                    systemImage: vm.people.isEmpty ? "person.2" : "creditcard",
                    ctaTitle: vm.people.isEmpty ? "Add Person" : "Add Expense"
                ) {
                    if vm.people.isEmpty {
                        presentPersonEditor()
                    } else {
                        showingAddExpense = true
                    }
                }
                .padding(.vertical, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredExpenses) { expense in
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                presentPersonEditor(for: person)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(DesignSystem.accentColor)

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

    private func presentPersonEditor(for person: SplitPersonRecord? = nil) {
        editingPerson = person
        newPersonName = person?.name ?? ""
        showingPersonEditor = true
    }

    private func savePersonEditor() {
        let trimmed = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var editingPerson {
            editingPerson.name = trimmed
            Task { await vm.updatePerson(editingPerson) }
        } else {
            Task { await vm.addPerson(name: trimmed) }
        }

        resetPersonEditor()
    }

    private func resetPersonEditor() {
        newPersonName = ""
        editingPerson = nil
    }

    private func movePeople(from source: IndexSet, to destination: Int) {
        guard canReorderPeople else { return }

        var reorderedPeople = vm.people
        reorderedPeople.move(fromOffsets: source, toOffset: destination)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            await vm.reorderPeople(reorderedPeople)
        }
    }

    private func handleSearchSubmit(wasVoice: Bool) {
        let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              OnePlacePromptClassifier.isCommand(prompt, in: .split) else {
            if wasVoice {
                aiAssistant.openVoiceMode(area: .split)
            }
            return
        }

        if let names = SplitPromptInterpreter.personNames(from: prompt), !names.isEmpty {
            Task {
                await vm.addPeople(names: names)
                await MainActor.run { searchText = "" }
            }
            return
        }

        aiAssistant.contextPeople = vm.people
        if wasVoice {
            aiAssistant.openVoiceMode(area: .split)
        } else {
            aiAssistant.openChatFresh(area: .split, voice: false)
        }
        aiAssistant.userSaid(prompt)
        searchText = ""

        Task {
            await AIChatResponder.handleUserInput(text: prompt, assistant: aiAssistant)
            await vm.refresh()
        }
    }

    private func personSubtitle(for person: SplitPersonRecord) -> String {
        let count = vm.expenses.filter { expense in
            expense.participantIds.contains(person.id) || expense.paidById == person.id
        }.count
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

enum SplitPromptInterpreter {
    static func personName(from prompt: String) -> String? {
        personNames(from: prompt)?.first
    }

    static func personNames(from prompt: String) -> [String]? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        guard extractAmount(from: prompt) == nil,
              lowered.hasPrefix("add person ") ||
              lowered.hasPrefix("add people ") ||
              lowered.hasPrefix("add persons ") ||
              lowered.hasPrefix("add ") ||
              lowered.hasPrefix("create person ") ||
              lowered.hasPrefix("create people ") ||
              lowered.hasPrefix("create persons ") ||
              lowered.hasPrefix("create ") else {
            return nil
        }

        let expectedCount = expectedPeopleCount(in: lowered)
        let value = trimmed
            .replacingOccurrences(of: #"(?i)^(add|create)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+(?:person|people|persons)\s*,?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^(?:person|people|persons)\s*,?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(to|in)\s+split\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\bpeople\b|\bpersons\b|\bperson\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s*(?:,|\band\b|&|\+)\s*"#, with: ",", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var names = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .map(cleanPersonName)
            .filter { !$0.isEmpty }

        if let expectedCount, names.count < expectedCount {
            names = names
                .flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
                .map(cleanPersonName)
                .filter { !$0.isEmpty }
        }

        names = Array(NSOrderedSet(array: names).compactMap { $0 as? String })
        return names.isEmpty ? nil : names
    }

    private static func expectedPeopleCount(in loweredPrompt: String) -> Int? {
        let numberWords = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
        ]

        if let match = loweredPrompt.range(
            of: #"(?<=\badd\s)(one|two|three|four|five|six|seven|eight|nine|ten|\d+)(?=\s+(?:person|people|persons)\b)"#,
            options: .regularExpression
        ) ?? loweredPrompt.range(
            of: #"(?<=\bcreate\s)(one|two|three|four|five|six|seven|eight|nine|ten|\d+)(?=\s+(?:person|people|persons)\b)"#,
            options: .regularExpression
        ) {
            let token = String(loweredPrompt[match])
            return numberWords[token] ?? Int(token)
        }

        return nil
    }

    private static func cleanPersonName(_ name: String) -> String {
        name
            .replacingOccurrences(of: #"(?i)\b(add|person|people|persons|to split|in split)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^A-Za-z'\-\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    static func expenseDraft(from prompt: String, people: [SplitPersonRecord]) -> SplitExpenseDraft? {
        guard let amount = extractAmount(from: prompt), amount > 0, !people.isEmpty else {
            return nil
        }

        let title = title(from: prompt, amount: amount)
        let lowered = prompt.lowercased()
        let paidBy = people.first { person in
            lowered.contains("paid by \(person.name.lowercased())") ||
            lowered.contains("\(person.name.lowercased()) paid")
        } ?? people.first

        let mentionedParticipantIds = people
            .filter { person in
                let name = person.name.lowercased()
                return lowered.contains(name) && person.id != paidBy?.id
            }
            .map(\.id)

        let participantIds = mentionedParticipantIds.isEmpty
            ? people.map(\.id)
            : mentionedParticipantIds

        return SplitExpenseDraft(
            title: title,
            amount: amount,
            date: detectedDate(in: prompt) ?? Date(),
            participantIds: participantIds,
            paidById: paidBy?.id
        )
    }

    private static func extractAmount(from prompt: String) -> Double? {
        let pattern = #"(?:^|[\s])\$?(\d+(?:\.\d{1,2})?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        guard let match = regex.firstMatch(in: prompt, range: range),
              let amountRange = Range(match.range(at: 1), in: prompt) else {
            return nil
        }

        return Double(prompt[amountRange])
    }

    private static func detectedDate(in prompt: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        return detector?.matches(in: prompt, range: range).first?.date
    }

    private static func title(from prompt: String, amount: Double) -> String {
        var value = prompt
        let amountText = amount.rounded() == amount ? String(Int(amount)) : String(amount)
        value = value.replacingOccurrences(of: "$\(amountText)", with: "", options: .caseInsensitive)
        value = value.replacingOccurrences(of: amountText, with: "", options: .caseInsensitive)
        value = value.replacingOccurrences(of: #"(?i)\b(add|split|expense|paid by|paid|with|for|between|today|yesterday|tomorrow)\b"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"[^A-Za-z0-9'&\s]"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return "Shared Expense" }
        return value.split(whereSeparator: \.isWhitespace)
            .prefix(4)
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
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
        } else {
            _selectedParticipants = State(initialValue: Set(vm.people.map(\.id)))
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
