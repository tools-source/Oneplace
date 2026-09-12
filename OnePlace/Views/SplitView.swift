import SwiftUI
import UIKit

struct SplitView: View {
    @StateObject private var vm = SplitViewModel()
    @EnvironmentObject private var aiAssistant: AIAssistantManager
    @Environment(\.editMode) private var editMode

    @State private var showingPersonEditor = false
    @State private var editingPerson: SplitPersonRecord?
    @State private var editingExpense: ItemEditorDestination<SplitExpenseRecord>?
    @State private var inlinePersonText = ""
    @State private var inlinePersonError: String?
    @State private var inlineExpenseText = ""
    @State private var inlineExpenseError: String?
    @State private var inlineExpensePaidById: String?
    @State private var inlineExpenseDate: Date?
    @State private var inlineExpenseSplitAll = true
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

    private var unsettledTotal: Double {
        vm.people.reduce(0) { partialResult, person in
            partialResult + abs(vm.getBalance(for: person))
        } / 2
    }

    private var settledPeopleCount: Int {
        vm.people.filter { abs(vm.getBalance(for: $0)) < 0.01 }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    splitPulseCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                summarySection
                peopleSection
                expensesSection
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: DesignSystem.tabBarContentInset)
            }
            .navigationTitle("Split")
            .searchable(text: $searchText, prompt: "Search people and expenses")
            .refreshable { await vm.refresh() }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                        .disabled(!canReorderPeople)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All", role: .destructive) {
                        showingClearConfirm = true
                    }
                    .disabled(vm.people.isEmpty && vm.expenses.isEmpty)
                }
            }
            .sheet(isPresented: $showingPersonEditor, onDismiss: resetPersonEditor) {
                SplitPersonEditorView(person: editingPerson) { name in
                    if var person = editingPerson {
                        person.name = name
                        await vm.updatePerson(person)
                    } else {
                        await vm.addPerson(name: name)
                    }
                    let error = vm.errorMessage
                    vm.errorMessage = nil
                    return error
                }
            }
            .sheet(item: $editingExpense) { destination in
                AddSplitExpenseView(vm: vm, expenseToEdit: destination.item) { draft in
                    if let expense = destination.item {
                        var updated = expense
                        updated.title = draft.title
                        updated.amount = draft.amount
                        updated.date = draft.date
                        updated.participantIds = draft.participantIds
                        updated.paidById = draft.paidById
                        await vm.updateExpense(updated)
                    } else {
                        await vm.addExpense(draft: draft)
                    }
                    let error = vm.errorMessage
                    if error == nil, destination.item == nil {
                        searchText = ""
                    }
                    vm.errorMessage = nil
                    return error
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
            get: { vm.errorMessage != nil && editingExpense == nil && !showingPersonEditor },
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

    private var splitPulseCard: some View {
        WorkspacePulseCard(
            title: "Settlement Pulse",
            subtitle: splitPulseSubtitle,
            icon: unsettledTotal > 0 ? "person.2.wave.2.fill" : "checkmark.seal.fill",
            tint: unsettledTotal > 0 ? DesignSystem.secondaryAccent : DesignSystem.gainColor,
            primaryValue: StatCard.currencyString(for: unsettledTotal),
            primaryLabel: "unsettled",
            secondaryValue: "\(settledPeopleCount)/\(vm.people.count)",
            secondaryLabel: "settled people",
            actionTitle: vm.people.isEmpty ? "Add" : "Expense"
        ) {
            if vm.people.isEmpty {
                inlinePersonText = ""
            } else {
                inlineExpenseText = ""
            }
        }
    }

    private var splitPulseSubtitle: String {
        if vm.people.isEmpty {
            return "Add people first, then OnePlace can track who paid and who owes."
        }

        if vm.expenses.isEmpty {
            return "\(vm.people.count) people are ready for your first shared expense."
        }

        if unsettledTotal < 0.01 {
            return "Everyone is balanced across \(vm.expenses.count) shared expense\(vm.expenses.count == 1 ? "" : "s")."
        }

        return "\(vm.expenses.count) expense\(vm.expenses.count == 1 ? "" : "s") have money left to settle."
    }

    private var peopleSection: some View {
        Section {
            if vm.isLoading && vm.people.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
            } else if vm.people.isEmpty {
                inlinePersonAddRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                EmptyState(
                    title: "Add people to start",
                    message: "Create people first, then record shared expenses and balances.",
                    systemImage: "person.badge.plus",
                    ctaTitle: nil
                )
                .padding(.vertical, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if filteredPeople.isEmpty {
                inlinePersonAddRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

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
                inlinePersonAddRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

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
                if !vm.people.isEmpty {
                    inlineExpenseAddRow
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                EmptyState(
                    title: vm.people.isEmpty ? "Add people first" : "No expenses yet",
                    message: vm.people.isEmpty ? "Once people are added, you can split expenses between them." : "Record a shared cost and OnePlace will calculate balances.",
                    systemImage: vm.people.isEmpty ? "person.2" : "creditcard",
                    ctaTitle: nil
                )
                .padding(.vertical, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                inlineExpenseAddRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(filteredExpenses) { expense in
                    expenseRow(for: expense)
                        .onTapGesture {
                            editingExpense = .edit(expense)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var inlinePersonAddRow: some View {
        InlineAddItemRow(
            text: $inlinePersonText,
            placeholder: "New person name",
            systemImage: "plus.circle.fill",
            tint: DesignSystem.accentColor,
            isSaving: vm.isLoading,
            validationMessage: inlinePersonError,
            onSubmit: saveInlinePerson,
            onCancel: cancelInlinePersonAdd
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Text("Add several people by separating their names with commas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 40)
            }
        }
    }

    private var inlineExpenseAddRow: some View {
        InlineAddItemRow(
            text: $inlineExpenseText,
            placeholder: "New expense, like Dinner 48 paid by Alex",
            systemImage: "plus.circle.fill",
            tint: DesignSystem.accentColor,
            isSaving: vm.isLoading,
            validationMessage: inlineExpenseError,
            onSubmit: saveInlineExpense,
            onCancel: cancelInlineExpenseAdd
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    InlineAddHelperMenu(title: "Who paid?", systemImage: "person.crop.circle", tint: DesignSystem.accentColor, isSelected: inlineExpensePaidById != nil) {
                        Button("Use name in entry") { inlineExpensePaidById = nil }
                        ForEach(vm.people) { person in
                            Button(person.name) { inlineExpensePaidById = person.id }
                        }
                    }
                    InlineAddHelperButton(title: "Split with everyone", systemImage: "person.2.fill", tint: DesignSystem.secondaryAccent, isSelected: inlineExpenseSplitAll) {
                        inlineExpenseSplitAll.toggle()
                    }
                    InlineAddHelperButton(title: "Today", systemImage: "calendar", tint: DesignSystem.accentColor, isSelected: inlineExpenseDate.map(Calendar.current.isDateInToday) == true) {
                        inlineExpenseDate = .now
                    }
                    InlineAddHelperButton(title: "Yesterday", systemImage: "clock.arrow.circlepath", tint: DesignSystem.warmAccent, isSelected: inlineExpenseDate.map(Calendar.current.isDateInYesterday) == true) {
                        inlineExpenseDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
                    }
                }
                .padding(.leading, 40)
            }
        }
        .disabled(vm.people.isEmpty)
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
                editingExpense = .edit(expense)
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

    private func presentPersonEditor(for person: SplitPersonRecord) {
        editingPerson = person
        newPersonName = person.name
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

    private func cancelInlinePersonAdd() {
        inlinePersonText = ""
        inlinePersonError = nil
    }

    private func saveInlinePerson() {
        let names = inlinePersonNames(from: inlinePersonText)
        guard !names.isEmpty else {
            inlinePersonError = "Enter at least one name."
            return
        }

        Task {
            await vm.addPeople(names: names)
            guard vm.errorMessage == nil else {
                inlinePersonError = vm.errorMessage
                return
            }

            await MainActor.run {
                searchText = ""
                inlinePersonText = ""
                inlinePersonError = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func cancelInlineExpenseAdd() {
        inlineExpenseText = ""
        inlineExpenseError = nil
        inlineExpenseDate = nil
    }

    private func saveInlineExpense() {
        let prompt = inlineExpenseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        guard var draft = SplitPromptInterpreter.expenseDraft(from: prompt, people: vm.people), draft.amount > 0 else {
            inlineExpenseError = "Include an amount, like Dinner 48 paid by Alex."
            return
        }
        draft.paidById = inlineExpensePaidById ?? draft.paidById ?? vm.people.first?.id
        if inlineExpenseSplitAll {
            draft.participantIds = vm.people.map(\.id)
        }
        if let inlineExpenseDate {
            draft.date = inlineExpenseDate
        }

        Task {
            await vm.addExpense(draft: draft)
            guard vm.errorMessage == nil else {
                inlineExpenseError = vm.errorMessage
                return
            }

            await MainActor.run {
                searchText = ""
                inlineExpenseText = ""
                inlineExpenseError = nil
                inlineExpenseDate = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func inlinePersonNames(from text: String) -> [String] {
        if let names = SplitPromptInterpreter.personNames(from: text) {
            return names
        }

        return text
            .replacingOccurrences(of: #"(?i)\s*(?:,|\band\b|&|\+)\s*"#, with: ",", options: .regularExpression)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .filter { !$0.isEmpty }
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
    @State private var isSaving = false
    @State private var saveError: String?
    @ObservedObject var vm: SplitViewModel

    @State private var title = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var selectedPaidBy: String? = nil
    @State private var selectedParticipants: Set<String> = []

    private let expenseToEdit: SplitExpenseRecord?
    private let onSave: (SplitExpenseDraft) async -> String?

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    init(vm: SplitViewModel, expenseToEdit: SplitExpenseRecord? = nil, onSave: @escaping (SplitExpenseDraft) async -> String?) {
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
                Section {
                    CreationGuideCard(
                        title: expenseToEdit == nil ? "Split A Shared Cost" : "Update Shared Cost",
                        subtitle: "Choose who paid and who participated. The payer is automatically included so balances stay consistent.",
                        icon: "person.2.fill",
                        tint: DesignSystem.secondaryAccent,
                        status: parsedAmount.map { StatCard.currencyString(for: $0) } ?? "Needs amount"
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    TextField("Expense title", text: $title)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Paid By") {
                    Picker("Who paid?", selection: $selectedPaidBy) {
                        Text("Choose payer").tag(String?.none)
                        ForEach(vm.people) { person in
                            Text(person.name).tag(String?.some(person.id))
                        }
                    }
                    .disabled(vm.people.isEmpty)
                }

                Section {
                    if vm.people.isEmpty {
                        Text("Add people first")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Button("Select All") {
                                selectedParticipants = Set(vm.people.map(\.id))
                            }
                            .buttonStyle(.borderless)

                            Spacer()

                            Button("Clear") {
                                selectedParticipants.removeAll()
                                selectedPaidBy = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(DesignSystem.oweColor)
                        }

                        ForEach(vm.people) { person in
                            Toggle(person.name, isOn: participantBinding(for: person))
                        }
                    }
                } header: {
                    Text("Participants")
                } footer: {
                    Text(participantsFooterText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle(expenseToEdit == nil ? "New Expense" : "Edit Expense")
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isSaving)
            .disabled(isSaving)
            .overlay {
                if isSaving { ProgressView("Saving…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
            }
            .alert("Couldn’t save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again. Your entries are still here.")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(expenseToEdit == nil ? "Add" : "Save") {
                        guard let amount = parsedAmount, amount > 0 else { return }
                        guard let selectedPaidBy else { return }
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

                        let draft = SplitExpenseDraft(
                            title: trimmedTitle,
                            amount: amount,
                            date: date,
                            participantIds: Array(normalizedParticipants),
                            paidById: selectedPaidBy
                        )
                        isSaving = true
                        Task {
                            saveError = await onSave(draft)
                            isSaving = false
                            if saveError == nil {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving || isSaveDisabled)
                }
            }
            .onChange(of: selectedPaidBy) { _, newValue in
                guard let newValue else { return }
                selectedParticipants.insert(newValue)
            }
        }
    }

    private var parsedAmount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(
            trimmed
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
        )
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedPaidBy == nil ||
        normalizedParticipants.isEmpty ||
        (parsedAmount ?? 0) <= 0
    }

    private var normalizedParticipants: Set<String> {
        guard let selectedPaidBy else { return selectedParticipants }
        var participants = selectedParticipants
        participants.insert(selectedPaidBy)
        return participants
    }

    private var participantsFooterText: String {
        guard selectedPaidBy != nil else {
            return "Choose who paid before saving."
        }

        let count = normalizedParticipants.count
        return "Splitting across \(count) participant\(count == 1 ? "" : "s"). The payer is included automatically."
    }

    private func participantBinding(for person: SplitPersonRecord) -> Binding<Bool> {
        Binding(
            get: {
                selectedParticipants.contains(person.id)
            },
            set: { isSelected in
                updateParticipantSelection(for: person, isSelected: isSelected)
            }
        )
    }

    private func updateParticipantSelection(for person: SplitPersonRecord, isSelected: Bool) {
        if isSelected {
            selectedParticipants.insert(person.id)
            return
        }

        selectedParticipants.remove(person.id)
        if selectedPaidBy == person.id {
            selectedPaidBy = nil
        }
    }
}

private struct SplitPersonEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var nameFocused: Bool
    let person: SplitPersonRecord?
    let onSave: (String) async -> String?

    init(person: SplitPersonRecord?, onSave: @escaping (String) async -> String?) {
        self.person = person
        self.onSave = onSave
        _name = State(initialValue: person?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                } header: { Text("Person’s name") } footer: {
                    Text("Use a name everyone recognizes. You can choose this person when splitting an expense.")
                }
                if let saveError { Text(saveError).foregroundStyle(DesignSystem.oweColor) }
            }
            .navigationTitle(person == nil ? "Add Person" : "Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : (person == nil ? "Add" : "Save")) {
                        isSaving = true
                        Task {
                            saveError = await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                            isSaving = false
                            if saveError == nil { dismiss() }
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
    }
}
