import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum FinancePreferenceKey {
    static let customOrder = "finance.customOrder"
    static let filterType = "finance.filter.type"
    static let filterCategory = "finance.filter.category"
    static let hideCompleted = "finance.filter.hideCompleted"
}

struct FinanceView: View {
    @StateObject private var vm = FinanceViewModel()
    @EnvironmentObject private var aiAssistant: AIAssistantManager

    @Environment(\.editMode) private var editMode

    @State private var targetedPersonID: String?
    @State private var isMovingTransaction = false
    private static let transactionDragType = UTType(exportedAs: "com.one-place.app.finance-transaction")

    @State private var editingEntry: FinanceEntryRecord?
    @State private var isShowingEditor = false
    @State private var inlineTransactionText = ""
    @State private var inlinePersonName = ""
    @State private var inlineTransactionError: String?
    @State private var inlineTransactionType: FinanceType
    @State private var inlineTransactionCategory: String
    @State private var inlineTransactionDate: Date?
    @State private var quickDraft: FinanceEntryDraft
    @State private var quickAmountText = ""
    @State private var editorDraft: FinanceEntryDraft
    @State private var editorAmountText = ""
    @State private var assistantFeedback = "Ask by voice or type a sentence and OnePlace will fill the transaction for you."
    @State private var isInterpretingPrompt = false
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedEntryIDs = Set<String>()
    @State private var showingFilters = false
    @State private var filters: FinanceFilters
    @State private var customOrderIDs: [String]
    @State private var lastRefreshToken: UUID?
    @State private var showingClearCompletedConfirm = false
    @State private var showingDeleteSelectedConfirm = false

    init() {
        let initialDraft = FinanceDraftDefaults.blankDraft()
        _quickDraft = State(initialValue: initialDraft)
        _editorDraft = State(initialValue: initialDraft)
        _inlineTransactionType = State(initialValue: initialDraft.type)
        _inlineTransactionCategory = State(initialValue: initialDraft.category)
        _filters = State(initialValue: Self.loadSavedFilters())
        _customOrderIDs = State(
            initialValue: UserDefaults.standard.stringArray(forKey: FinancePreferenceKey.customOrder) ?? []
        )
    }

    private var displayedEntries: [FinanceEntryRecord] {
        FinanceEntryList.ordered(vm.entries, customOrderIDs: customOrderIDs)
    }

    private var personGroups: [FinancePersonGroup] {
        var groups = FinanceEntryList.groups(in: filteredEntries)
        if !groups.contains(where: { $0.name.isEmpty }) {
            groups.append(FinancePersonGroup(id: "", name: "", entries: []))
        }
        return groups
    }

    private var financeRows: [FinanceListRow] {
        personGroups.flatMap { group in
            [.person(group)] + group.entries.map(FinanceListRow.transaction)
        }
    }

    private var existingPersonNames: [String] {
        FinanceEntryList.groups(in: vm.entries).map(\.name)
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredEntries: [FinanceEntryRecord] {
        var base = displayedEntries

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            base = base.filter {
                $0.personName.localizedCaseInsensitiveContains(query) ||
                $0.category.localizedCaseInsensitiveContains(query) ||
                $0.entryDescription.localizedCaseInsensitiveContains(query) ||
                $0.type.rawValue.localizedCaseInsensitiveContains(query)
            }
        }

        base = base.filter { entry in
            if let type = filters.type, entry.type != type { return false }
            if let category = filters.category, entry.category != category { return false }
            if filters.hideCompleted && entry.isCompleted { return false }
            return true
        }

        return base
    }

    private var gainTotal: Double {
        vm.entries
            .filter { $0.type == .gain && !$0.isCompleted }
            .reduce(0) { $0 + $1.amount }
    }

    private var oweTotal: Double {
        vm.entries
            .filter { $0.type == .owe && !$0.isCompleted }
            .reduce(0) { $0 + $1.amount }
    }

    private var netTotal: Double {
        gainTotal - oweTotal
    }

    private var selectedEntries: [FinanceEntryRecord] {
        filteredEntries.filter { selectedEntryIDs.contains($0.id) }
    }

    private var selectedVisibleIDs: Set<String> {
        Set(selectedEntries.map(\.id))
    }

    private var allVisibleEntriesSelected: Bool {
        !filteredEntries.isEmpty && filteredEntries.allSatisfy { selectedEntryIDs.contains($0.id) }
    }

    private var completedEntries: [FinanceEntryRecord] {
        vm.entries.filter(\.isCompleted)
    }

    private var selectedNetTotal: Double {
        selectedEntries.reduce(0) { partialResult, entry in
            partialResult + signedAmount(for: entry)
        }
    }

    private var categories: [String] {
        Array(Set(vm.entries.map(\.category))).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    Section {
                        financePulseCard
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Section {
                        summaryCards
                            .listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 6, trailing: 8))
                            .listRowBackground(Color.clear)
                    }

                    if isSelecting {
                        Section {
                            selectionSummaryCard
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 8, trailing: 8))
                                .listRowBackground(Color.clear)
                        }
                    }

                    Section {
                        sectionHeaderCard
                            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        if vm.isLoading && vm.entries.isEmpty {
                            ProgressView("Loading transactions…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else if filteredEntries.isEmpty {
                            if !isSelecting {
                                inlineTransactionAddRow
                                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }

                            EmptyState(
                                title: vm.entries.isEmpty ? "No transactions yet" : "No matching transactions",
                                message: vm.entries.isEmpty ? "Use the inline entry and choose a person to keep their entries together." : "Try another search or adjust your filters.",
                                systemImage: "sparkles.rectangle.stack",
                                ctaTitle: nil
                            )
                            .padding(.vertical, 12)
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            if !isSelecting {
                                inlineTransactionAddRow
                                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }

                            if editMode?.wrappedValue.isEditing != true {
                                Text("Hold and drag a transaction onto a person, or use Edit to move it. Swipe for quick actions.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }

                            ForEach(financeRows) { row in
                                switch row {
                                case .person(let group):
                                    personHeader(for: group)
                                        .contentShape(Rectangle())
                                        .background(targetedPersonID == group.id ? DesignSystem.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                        .onDrop(of: [Self.transactionDragType], isTargeted: dropHighlight(for: group.id)) { providers in
                                            acceptDrop(providers, personName: group.name, beforeEntryID: nil, atStart: true)
                                        }
                                        .moveDisabled(true)
                                        .listRowInsets(EdgeInsets(top: 14, leading: 12, bottom: 4, trailing: 12))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)

                                case .transaction(let entry):
                                    transactionRow(for: entry)
                                        .onTapGesture {
                                            if isSelecting {
                                                toggleSelection(for: entry)
                                            } else {
                                                presentEditor(for: entry)
                                            }
                                        }
                                        .onDrag { dragProvider(for: entry) }
                                        .onDrop(of: [Self.transactionDragType], isTargeted: nil) { providers in
                                            acceptDrop(providers, personName: entry.personName, beforeEntryID: entry.id)
                                        }
                                        .moveDisabled(isSelecting || vm.isSaving || isMovingTransaction)
                                        .disabled(vm.isSaving || isMovingTransaction)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 8))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                            .onMove(perform: moveFinanceRows)
                        }
                    }
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
                .navigationTitle("Finance")
                .searchable(text: $searchText, prompt: "Search people or transactions")
                .refreshable { await vm.refresh() }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(isSelecting ? "Done" : "Select") {
                            toggleSelectionMode()
                        }
                    }

                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            showingFilters = true
                        } label: {
                            Image(systemName: filters.isActive
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                        }

                        EditButton()
                            .disabled(isSelecting)
                    }
                }
                .sheet(isPresented: $showingFilters) {
                    FinanceFilterSheet(filters: $filters, categories: categories)
                }
                .alert("Finance Error", isPresented: financeErrorBinding) {
                    Button("OK", role: .cancel) {
                        vm.clearError()
                    }
                } message: {
                    Text(vm.errorMessage ?? "Please try again.")
                }
                .alert("Clear Completed Transactions?", isPresented: $showingClearCompletedConfirm) {
                    Button("Clear All", role: .destructive) {
                        Task { await vm.clearCompletedEntries() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently deletes every completed Finance transaction.")
                }
                .alert("Delete Selected Transactions?", isPresented: $showingDeleteSelectedConfirm) {
                    Button("Delete", role: .destructive) {
                        deleteSelectedEntries()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently deletes the selected Finance transactions.")
                }
                .onChange(of: filters) { _, newFilters in
                    saveFilters(newFilters)
                }
                .onChange(of: vm.entries) { _, newEntries in
                    sanitizeCustomOrder(using: newEntries)
                    sanitizeSelection(using: newEntries)
                }
                .task {
                    await vm.refresh()
                    sanitizeCustomOrder(using: vm.entries)
                    sanitizeSelection(using: vm.entries)
                }
                .onChange(of: aiAssistant.pendingActionsToken) { _, newToken in
                    guard lastRefreshToken != newToken else { return }
                    lastRefreshToken = newToken
                    Task {
                        await vm.refresh()
                        sanitizeCustomOrder(using: vm.entries)
                        sanitizeSelection(using: vm.entries)
                    }
                }

            }
            .sheet(isPresented: $isShowingEditor) {
                AddFinanceEntryView(
                    title: editingEntry == nil ? "New Transaction" : "Edit Transaction",
                    draft: $editorDraft,
                    amountText: $editorAmountText,
                    isSaving: vm.isSaving,
                    onDismiss: closeEditor,
                    onSave: saveEditorDraft
                )
                .presentationDetents([.large])
                .interactiveDismissDisabled(vm.isSaving)
                .alert("Couldn’t save", isPresented: financeErrorBinding) {
                    Button("OK", role: .cancel) { vm.clearError() }
                } message: { Text(vm.errorMessage ?? "Please try again.") }
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var financeErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    vm.clearError()
                }
            }
        )
    }

    private var sectionHeaderCard: some View {
        AppCard {
            HStack(spacing: 14) {
                ItemIconBadge(symbol: "creditcard.and.123", tint: DesignSystem.accentColor, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Transactions")
                        .font(.headline)

                    Text("\(filteredEntries.count) visible • \(vm.entries.count) total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if filters.isActive {
                        Text("Filtered")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(DesignSystem.warmAccent.opacity(0.18))
                            )
                            .foregroundStyle(DesignSystem.warmAccent)
                    }

                    if !completedEntries.isEmpty {
                        Button(role: .destructive) {
                            showingClearCompletedConfirm = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(vm.isSaving)
                        .accessibilityLabel("Clear all completed transactions")
                    }
                }
            }
        }
    }

    private var financePulseCard: some View {
        WorkspacePulseCard(
            title: "Finance Pulse",
            subtitle: financePulseSubtitle,
            icon: netTotal >= 0 ? "chart.line.uptrend.xyaxis" : "exclamationmark.triangle.fill",
            tint: netTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor,
            primaryValue: StatCard.currencyString(for: netTotal),
            primaryLabel: "open net",
            secondaryValue: "\(completedEntries.count)",
            secondaryLabel: "completed",
            actionTitle: filters.isActive ? "Show All" : "Filter"
        ) {
            if filters.isActive {
                filters = FinanceFilters(type: nil, category: nil, hideCompleted: false)
            } else {
                showingFilters = true
            }
        }
    }

    private var financePulseSubtitle: String {
        if vm.entries.isEmpty {
            return "Start by typing a transaction in plain language."
        }

        if filters.isActive {
            return "\(filteredEntries.count) matching entries are visible."
        }

        if netTotal < 0 {
            return "Owed items are ahead of incoming money right now."
        }

        return "Open income is covering pending outflow."
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { filters.type = nil }
            } label: {
                StatCard(
                    title: "Net",
                    value: StatCard.currencyString(for: netTotal),
                    subtitle: netTotal >= 0 ? "Positive runway" : "Needs attention",
                    icon: "plus",
                    tint: netTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { filters.type = filters.type == .gain ? nil : .gain }
            } label: {
                StatCard(
                    title: "Gain",
                    value: StatCard.currencyString(for: gainTotal),
                    subtitle: "Open income",
                    icon: "arrow.up.right",
                    tint: DesignSystem.gainColor,
                    isSelected: filters.type == .gain
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { filters.type = filters.type == .owe ? nil : .owe }
            } label: {
                StatCard(
                    title: "Owe",
                    value: StatCard.currencyString(for: oweTotal),
                    subtitle: "Pending outflow",
                    icon: "arrow.down.right",
                    tint: DesignSystem.oweColor,
                    isSelected: filters.type == .owe
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var selectionSummaryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ItemIconBadge(
                        symbol: selectedVisibleIDs.isEmpty ? "checklist.unchecked" : "checkmark.circle.fill",
                        tint: selectedNetTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor,
                        size: 42
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Total")
                            .font(.headline)

                        Text(selectionSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(StatCard.currencyString(for: selectedNetTotal))
                        .font(.headline)
                        .foregroundStyle(selectedNetTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor)
                }

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            toggleSelectAllVisible()
                        } label: {
                            Label(allVisibleEntriesSelected ? "Deselect All" : "Select All", systemImage: allVisibleEntriesSelected ? "xmark.circle" : "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            markSelectedEntriesCompleted(true)
                        } label: {
                            Label("Complete", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(selectedVisibleIDs.isEmpty || vm.isSaving)

                        Button {
                            markSelectedEntriesCompleted(false)
                        } label: {
                            Label("Reopen", systemImage: "arrow.uturn.backward.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(selectedVisibleIDs.isEmpty || vm.isSaving)

                        Button(role: .destructive) {
                            showingDeleteSelectedConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(selectedVisibleIDs.isEmpty || vm.isSaving)

                        if !selectedVisibleIDs.isEmpty {
                            Button {
                                selectedEntryIDs.removeAll()
                            } label: {
                                Label("Clear", systemImage: "xmark")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var inlineTransactionAddRow: some View {
        InlineAddItemRow(
            text: $inlineTransactionText,
            placeholder: "New transaction, like Coffee 6.50",
            systemImage: "plus.circle.fill",
            tint: DesignSystem.accentColor,
            isSaving: vm.isSaving,
            alwaysShowHelpers: true,
            validationMessage: inlineTransactionError,
            onSubmit: saveInlineTransaction,
            onCancel: cancelInlineTransactionAdd
        ) {
            VStack(alignment: .leading, spacing: 10) {
                FinancePersonField(personName: $inlinePersonName, existingNames: existingPersonNames)
                    .disabled(vm.isSaving)
                if !FinanceEntryList.normalizedPersonName(inlinePersonName).isEmpty {
                    Picker("Who owes whom?", selection: Binding(get: { inlineTransactionType }, set: setInlineTransactionType)) {
                        Text("They owe me").tag(FinanceType.gain)
                        Text("I owe them").tag(FinanceType.owe)
                    }
                    .pickerStyle(.segmented)
                    .disabled(vm.isSaving)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        InlineAddHelperMenu(title: "Gain or owe", systemImage: "arrow.up.arrow.down", tint: DesignSystem.accentColor) {
                            Button(inlinePersonName.isEmpty ? "Gain" : "They owe me") { setInlineTransactionType(.gain) }
                            Button(inlinePersonName.isEmpty ? "Owe" : "I owe them") { setInlineTransactionType(.owe) }
                        }
                        InlineAddHelperMenu(title: "Category", systemImage: "tray.full", tint: DesignSystem.secondaryAccent) {
                            ForEach(inlineTransactionType == .gain ? FinanceCategory.incomeRawValues : FinanceCategory.expenseRawValues, id: \.self) { category in
                                Button(category) { inlineTransactionCategory = category }
                            }
                        }
                        InlineAddHelperButton(title: "Today", systemImage: "calendar", tint: DesignSystem.accentColor, isSelected: inlineTransactionDate.map(Calendar.current.isDateInToday) == true) {
                            inlineTransactionDate = .now
                        }
                        InlineAddHelperButton(title: "Yesterday", systemImage: "clock.arrow.circlepath", tint: DesignSystem.warmAccent, isSelected: inlineTransactionDate.map(Calendar.current.isDateInYesterday) == true) {
                            inlineTransactionDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
                        }
                    }
                    .padding(.leading, 40)
                }
            }
        }
    }

    private func personHeader(for group: FinancePersonGroup) -> some View {
        HStack(spacing: 10) {
            ItemIconBadge(
                symbol: group.name.isEmpty ? "tray" : "person.fill",
                tint: DesignSystem.accentColor,
                size: 32
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name.isEmpty ? "Other transactions" : group.name)
                    .font(.headline)
                Text(group.entries.isEmpty ? "Drop here to remove a person" : "\(group.entries.count) transaction\(group.entries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(StatCard.currencyString(for: abs(group.openNet)))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(group.name.isEmpty ? (group.openNet >= 0 ? "Net gain" : "Net owed") : (abs(group.openNet) < 0.005 ? "Settled" : (group.openNet > 0 ? "Owes you" : "You owe")))
                    .font(.caption)
            }
            .foregroundStyle(group.openNet >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func transactionRow(for entry: FinanceEntryRecord) -> some View {
        let isSelected = selectedEntryIDs.contains(entry.id)

        AppCard {
            HStack(spacing: 12) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? DesignSystem.accentColor : DesignSystem.secondaryTextColor)
                }

                FinanceTypeBadge(type: entry.type)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.entryDescription.isEmpty ? entry.category : entry.entryDescription)
                        .font(.headline)
                        .strikethrough(entry.isCompleted)

                    Text("\(entry.category) • \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(StatCard.currencyString(for: entry.amount))
                    .font(.headline)
                    .foregroundStyle(entry.type == .gain ? DesignSystem.gainColor : DesignSystem.oweColor)
            }
            .opacity(entry.isCompleted ? 0.62 : 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? DesignSystem.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1.4
                )
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await vm.toggleCompletion(for: entry) }
            } label: {
                Label(entry.isCompleted ? "Undo" : "Complete",
                      systemImage: entry.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(DesignSystem.gainColor)
        }
        .swipeActions(edge: .trailing) {
            Button {
                presentEditor(for: entry)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(DesignSystem.accentColor)

            Button(role: .destructive) {
                Task { await vm.deleteEntry(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func handleAssistantPrompt() {
        dismissKeyboard()

        let trimmedPrompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty,
              OnePlacePromptClassifier.isCommand(trimmedPrompt, in: .finance) else {
            return
        }

        isInterpretingPrompt = true
        assistantFeedback = "Thinking through the transaction…"

        Task {
            let interpreter = FinanceAIInterpreter()
            let result = await interpreter.interpret(
                prompt: trimmedPrompt,
                fallbackCategory: quickDraft.category,
                now: .now,
                timeZone: .autoupdatingCurrent
            )

            await MainActor.run {
                isInterpretingPrompt = false

                switch result {
                case .success(let interpretation):
                    quickDraft = interpretation.draft
                    quickAmountText = FinanceDraftDefaults.amountText(for: interpretation.draft.amount)
                    assistantFeedback = interpretation.message

                    if interpretation.isReadyToSave {
                        saveQuickDraft(using: interpretation.draft)
                    } else {
                        inlineTransactionText = trimmedPrompt
                        inlineTransactionError = interpretation.message
                        searchText = ""
                    }

                case .failure(let error):
                    assistantFeedback = error.localizedDescription
                }
            }
        }
    }

    private func saveQuickDraft(using sourceDraft: FinanceEntryDraft? = nil) {
        let candidateDraft = sourceDraft ?? quickDraft
        let candidateAmountText = sourceDraft.map { FinanceDraftDefaults.amountText(for: $0.amount) } ?? quickAmountText

        guard let draft = FinanceDraftDefaults.resolvedDraft(from: candidateDraft, amountText: candidateAmountText) else {
            assistantFeedback = "Add an amount to save the transaction."
            return
        }

        Task {
            let didSave = await vm.addEntry(draft: draft)
            guard didSave else { return }

            FinanceDraftDefaults.rememberCategoryIfKnown(draft.category)
            await MainActor.run {
                assistantFeedback = "Added \(draft.entryDescription) for \(StatCard.currencyString(for: draft.amount))."
                searchText = ""
                quickDraft = FinanceDraftDefaults.blankDraft(preferredCategory: draft.category, preferredType: draft.type)
                quickAmountText = ""
            }
        }
    }

    private func cancelInlineTransactionAdd() {
        inlineTransactionText = ""
        inlineTransactionError = nil
        inlineTransactionDate = nil
    }

    private func saveInlineTransaction() {
        let prompt = inlineTransactionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        guard let interpretation = FinancePromptInterpreter.interpret(
            prompt,
            fallbackCategory: inlineTransactionCategory,
            now: .now
        ), interpretation.draft.amount > 0 else {
            inlineTransactionError = "Include an amount, like Coffee 6.50."
            return
        }

        var draft = interpretation.draft
        draft.personName = FinanceEntryList.normalizedPersonName(inlinePersonName)
        draft.type = inlineTransactionType
        draft.category = inlineTransactionCategory
        if let inlineTransactionDate {
            draft.date = inlineTransactionDate
        }

        Task {
            let didSave = await vm.addEntry(draft: draft)
            guard didSave else {
                inlineTransactionError = vm.errorMessage
                return
            }

            FinanceDraftDefaults.rememberCategoryIfKnown(draft.category)
            await MainActor.run {
                assistantFeedback = "Added \(draft.entryDescription) for \(StatCard.currencyString(for: draft.amount))."
                quickDraft = FinanceDraftDefaults.blankDraft(preferredCategory: draft.category, preferredType: draft.type)
                quickAmountText = ""
                searchText = ""
                filters.type = nil
                filters.category = nil
                inlineTransactionText = ""
                inlineTransactionError = nil
                inlineTransactionDate = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func setInlineTransactionType(_ type: FinanceType) {
        inlineTransactionType = type
        let currentType = FinanceDraftDefaults.type(for: inlineTransactionCategory, fallback: type)
        guard currentType != type else { return }
        inlineTransactionCategory = FinanceDraftDefaults.defaultCategory(for: type)
    }



    private func presentEditor(for entry: FinanceEntryRecord) {
        editingEntry = entry
        editorDraft = FinanceEntryDraft(record: entry)
        editorAmountText = FinanceDraftDefaults.amountText(for: entry.amount)
        isShowingEditor = true
    }

    private func saveEditorDraft(_ draft: FinanceEntryDraft) {
        if let entry = editingEntry {
            let updatedEntry = FinanceEntryRecord(
                id: entry.id,
                ownerUserId: entry.ownerUserId,
                amount: draft.amount,
                type: draft.type,
                category: draft.category,
                entryDescription: draft.entryDescription,
                date: draft.date,
                urgency: draft.urgency,
                isCompleted: entry.isCompleted,
                personName: FinanceEntryList.normalizedPersonName(draft.personName),
                createdAt: entry.createdAt
            )

            Task {
                let didSave = await vm.updateEntry(updatedEntry)
                guard didSave else { return }

                await MainActor.run {
                    assistantFeedback = "Updated \(draft.entryDescription)."
                    closeEditor()
                }
            }
            return
        }

        Task {
            let didSave = await vm.addEntry(draft: draft)
            guard didSave else { return }

            FinanceDraftDefaults.rememberCategoryIfKnown(draft.category)
            await MainActor.run {
                assistantFeedback = "Added \(draft.entryDescription) for \(StatCard.currencyString(for: draft.amount))."
                quickDraft = FinanceDraftDefaults.blankDraft(preferredCategory: draft.category, preferredType: draft.type)
                quickAmountText = ""
                searchText = ""
                filters.type = nil
                filters.category = nil
                closeEditor()
            }
        }
    }

    private func closeEditor() {
        dismissKeyboard()
        isShowingEditor = false
        editingEntry = nil
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func moveFinanceRows(from source: IndexSet, to destination: Int) {
        guard source.count == 1, let index = source.first,
              let target = FinanceEntryList.moveTarget(rows: financeRows, source: index, destination: destination),
              case .transaction(let entry) = financeRows[index] else { return }
        moveTransaction(entryID: entry.id, to: target)
    }

    private func dragProvider(for entry: FinanceEntryRecord) -> NSItemProvider {
        let provider = NSItemProvider()
        guard !isSelecting, !vm.isSaving, !isMovingTransaction else { return provider }
        let data = Data(entry.id.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: Self.transactionDragType.identifier, visibility: .ownProcess) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    private func dropHighlight(for personID: String) -> Binding<Bool> {
        Binding(get: { targetedPersonID == personID }, set: { targeted in
            if targeted { targetedPersonID = personID }
            else if targetedPersonID == personID { targetedPersonID = nil }
        })
    }

    private func acceptDrop(_ providers: [NSItemProvider], personName: String, beforeEntryID: String?, atStart: Bool = false) -> Bool {
        guard !isSelecting, !vm.isSaving, !isMovingTransaction,
              let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(Self.transactionDragType.identifier) }) else { return false }
        targetedPersonID = nil
        provider.loadDataRepresentation(forTypeIdentifier: Self.transactionDragType.identifier) { data, _ in
            guard let data, let entryID = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                let key = FinanceEntryList.normalizedPersonName(personName).lowercased()
                let firstEntryID = displayedEntries.first {
                    $0.id != entryID && FinanceEntryList.normalizedPersonName($0.personName).lowercased() == key
                }?.id
                moveTransaction(entryID: entryID, to: FinanceMoveTarget(personName: personName, beforeEntryID: atStart ? firstEntryID : beforeEntryID))
            }
        }
        return true
    }

    private func moveTransaction(entryID: String, to target: FinanceMoveTarget) {
        guard !isSelecting, !vm.isSaving, !isMovingTransaction,
              let original = vm.entries.first(where: { $0.id == entryID }),
              let plan = FinanceEntryList.move(entryID: entryID, to: target, entries: vm.entries, customOrderIDs: customOrderIDs) else { return }
        // An in-person reorder only changes order. A cross-person drop also
        // persists the new assignment, preserving amount, direction and dates.
        if original.personName == plan.entry.personName {
            customOrderIDs = plan.orderedIDs
            saveCustomOrder()
            return
        }
        isMovingTransaction = true
        Task {
            let saved = await vm.updateEntry(plan.entry)
            isMovingTransaction = false
            guard saved else { return }
            customOrderIDs = plan.orderedIDs
            saveCustomOrder()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func saveCustomOrder() {
        UserDefaults.standard.set(customOrderIDs, forKey: FinancePreferenceKey.customOrder)
    }

    private func sanitizeCustomOrder(using entries: [FinanceEntryRecord]) {
        let validIDs = Set(entries.map(\.id))
        let sanitized = customOrderIDs.filter(validIDs.contains)

        guard sanitized != customOrderIDs else { return }

        customOrderIDs = sanitized
        saveCustomOrder()
    }

    private func sanitizeSelection(using entries: [FinanceEntryRecord]) {
        let validIDs = Set(entries.map(\.id))
        selectedEntryIDs = Set(selectedEntryIDs.filter(validIDs.contains))
    }

    private func saveFilters(_ filters: FinanceFilters) {
        let defaults = UserDefaults.standard
        defaults.set(filters.type?.rawValue ?? "", forKey: FinancePreferenceKey.filterType)
        defaults.set(filters.category ?? "", forKey: FinancePreferenceKey.filterCategory)
        defaults.set(filters.hideCompleted, forKey: FinancePreferenceKey.hideCompleted)
    }

    private static func loadSavedFilters() -> FinanceFilters {
        let defaults = UserDefaults.standard
        let type = FinanceType(rawValue: defaults.string(forKey: FinancePreferenceKey.filterType) ?? "")
        let category = defaults.string(forKey: FinancePreferenceKey.filterCategory)
        let savedCategory = category?.isEmpty == true ? nil : category

        return FinanceFilters(
            type: type,
            category: savedCategory,
            hideCompleted: defaults.object(forKey: FinancePreferenceKey.hideCompleted) == nil
                ? true
                : defaults.bool(forKey: FinancePreferenceKey.hideCompleted)
        )
    }

    private func toggleSelectionMode() {
        isSelecting.toggle()
        if !isSelecting {
            selectedEntryIDs.removeAll()
        }
        editMode?.wrappedValue = .inactive
    }

    private func toggleSelection(for entry: FinanceEntryRecord) {
        if selectedEntryIDs.contains(entry.id) {
            selectedEntryIDs.remove(entry.id)
        } else {
            selectedEntryIDs.insert(entry.id)
        }
    }

    private var selectionSummaryText: String {
        let count = selectedVisibleIDs.count

        guard count > 0 else {
            return "Tap transactions or select all visible items."
        }

        return "\(count) item\(count == 1 ? "" : "s") selected"
    }

    private func toggleSelectAllVisible() {
        let visibleIDs = Set(filteredEntries.map(\.id))

        if allVisibleEntriesSelected {
            selectedEntryIDs.subtract(visibleIDs)
        } else {
            selectedEntryIDs.formUnion(visibleIDs)
        }
    }

    private func markSelectedEntriesCompleted(_ isCompleted: Bool) {
        let ids = selectedVisibleIDs
        guard !ids.isEmpty else { return }

        Task {
            await vm.setCompletion(for: ids, isCompleted: isCompleted)
            await MainActor.run {
                selectedEntryIDs.subtract(ids)
            }
        }
    }

    private func deleteSelectedEntries() {
        let ids = selectedVisibleIDs
        guard !ids.isEmpty else { return }

        Task {
            await vm.deleteEntries(withIDs: ids)
            await MainActor.run {
                selectedEntryIDs.subtract(ids)
            }
        }
    }

    private func signedAmount(for entry: FinanceEntryRecord) -> Double {
        entry.type == .gain ? entry.amount : -entry.amount
    }
}

private struct FinanceFilters: Equatable {
    var type: FinanceType? = nil
    var category: String? = nil
    var hideCompleted = true

    var isActive: Bool {
        type != nil || category != nil || hideCompleted
    }
}

private struct FinanceFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: FinanceFilters
    let categories: [String]

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $filters.type) {
                        Text("All").tag(FinanceType?.none)
                        Text("Gain").tag(FinanceType?.some(.gain))
                        Text("Owe").tag(FinanceType?.some(.owe))
                    }
                    .pickerStyle(.segmented)
                }

                Section("Category") {
                    Picker("Category", selection: $filters.category) {
                        Text("All").tag(String?.none)
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(String?.some(category))
                        }
                    }
                }

                Section("Status") {
                    Toggle("Hide completed", isOn: $filters.hideCompleted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FinanceAIInterpreter {
    func interpret(
        prompt: String,
        fallbackCategory: String,
        now: Date,
        timeZone: TimeZone
    ) async -> Result<FinancePromptInterpretation, Error> {
        guard let configuration = OpenAIConfiguration.load() else {
            print("[OpenRouter] No API key configured — falling back to local parser")
            return fallbackInterpretation(
                prompt: prompt,
                fallbackCategory: fallbackCategory,
                now: now,
                prefix: "Set `OPENAI_API_KEY` in OnePlace.xcconfig to enable AI via OpenRouter."
            )
        }

        do {
            let payload = try await requestInterpretation(
                prompt: prompt,
                configuration: configuration,
                now: now,
                timeZone: timeZone
            )

            let payloadType = FinanceType(rawValue: payload.type) ?? .owe
            var draft = FinanceEntryDraft(
                amount: payload.hasAmount ? payload.amount : 0,
                type: payloadType,
                category: Self.category(for: payload.category, fallbackCategory: fallbackCategory, type: payloadType),
                entryDescription: payload.title.trimmingCharacters(in: .whitespacesAndNewlines),
                date: payload.resolvedDate,
                urgency: FinanceUrgency(rawValue: payload.urgency) ?? .medium
            )

            if let localHint = FinancePromptInterpreter.interpret(prompt, fallbackCategory: fallbackCategory, now: now) {
                draft = Self.reinforcedDraft(aiDraft: draft, localDraft: localHint.draft, prompt: prompt)
            }

            let amountString = payload.hasAmount ? Self.currencyString(for: payload.amount) : "missing amount"
            let message = "AI classified this as \(draft.type == .gain ? "income" : "expense") in \(draft.category) with \(amountString)."

            return .success(
                FinancePromptInterpretation(
                    draft: draft,
                    message: message,
                    isReadyToSave: payload.hasAmount
                )
            )
        } catch {
            print("[OpenRouter] Request failed: \(error.localizedDescription) — falling back to local parser")
            return fallbackInterpretation(
                prompt: prompt,
                fallbackCategory: fallbackCategory,
                now: now,
                prefix: "AI request failed. Falling back to the local parser."
            )
        }
    }

    private func fallbackInterpretation(
        prompt: String,
        fallbackCategory: String,
        now: Date,
        prefix: String
    ) -> Result<FinancePromptInterpretation, Error> {
        guard let fallback = FinancePromptInterpreter.interpret(prompt, fallbackCategory: fallbackCategory, now: now) else {
            return .failure(FinanceAIError.unableToInterpret(prefix))
        }

        return .success(
            FinancePromptInterpretation(
                draft: fallback.draft,
                message: "\(prefix) \(fallback.message)",
                isReadyToSave: fallback.isReadyToSave
            )
        )
    }

    private func requestInterpretation(
        prompt: String,
        configuration: OpenAIConfiguration,
        now: Date,
        timeZone: TimeZone
    ) async throws -> FinanceAITransactionPayload {
        let endpointURL = "https://openrouter.ai/api/v1/chat/completions"
        print("[OpenRouter] Sending finance AI request — model: \(configuration.model), endpoint: \(endpointURL)")

        let requestBody = OpenRouterChatRequest(
            model: configuration.model,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You extract finance transactions for a personal finance app.
                    Decide whether the user's statement means money coming to the user or leaving the user.
                    Rules:
                    - type = gain when the user receives money, expects to receive money, or someone owes the user money.
                    - type = owe when the user pays money, owes someone else money, or expects money to leave the user.
                    - "my mom owes me 200" is gain.
                    - "I owe my mom 200" is owe.
                    - reimbursements owed to the user are gain even if tied to shopping, transport, or food.
                    - Keep title short, neat, and specific.
                    - Preserve what the money was for when the user says it, especially after words like "for".
                    - If a merchant or reason is present, include it in the title.
                    - Good titles: "Mother owes me for Macy's", "Macy's reimbursement", "Pay Mom for rent", "Uber reimbursement".
                    - Use one category from the supplied category list.
                    - If the amount is missing, set hasAmount to false and amount to 0.
                    - Resolve relative dates using the provided current local date and timezone.
                    """
                ),
                .init(
                    role: "user",
                    content: """
                    Current local datetime: \(Self.displayDateFormatter.string(from: now))
                    Timezone: \(timeZone.identifier)
                    Valid categories: \(OpenAIConfiguration.validCategories.joined(separator: ", "))
                    User transaction text: \(prompt)
                    """
                )
            ],
            responseFormat: .init(
                type: "json_schema",
                jsonSchema: .init(
                    name: "finance_transaction",
                    strict: true,
                    schema: .financeTransaction
                )
            )
        )

        var request = URLRequest(url: URL(string: endpointURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("OnePlace iOS App", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONEncoder().encode(requestBody)

        print("[OpenRouter] Request dispatched — waiting for response")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[OpenRouter] ERROR: Invalid response object")
            throw FinanceAIError.invalidResponse
        }

        print("[OpenRouter] Response received — HTTP \(httpResponse.statusCode)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(OpenAIAPIErrorResponse.self, from: data)
            let message = apiError?.error.message ?? "OpenRouter returned status \(httpResponse.statusCode)."
            print("[OpenRouter] ERROR: \(message)")
            throw FinanceAIError.apiError(message)
        }

        let chatResponse = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        guard let jsonText = chatResponse.firstContent else {
            print("[OpenRouter] ERROR: Response contained no content")
            throw FinanceAIError.invalidPayload("The AI response did not include structured text.")
        }

        let payloadData = Data(jsonText.utf8)
        let payload = try JSONDecoder().decode(FinanceAITransactionPayload.self, from: payloadData)
        print("[OpenRouter] Parsed transaction — title: \"\(payload.title)\", type: \(payload.type), amount: \(payload.amount), category: \(payload.category)")
        return payload
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()

    private static func currencyString(for amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount))
            ?? amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    private static func category(for category: String, fallbackCategory: String, type: FinanceType) -> String {
        let normalized = FinanceDraftDefaults.normalizedCategory(category)
            ?? FinanceDraftDefaults.normalizedCategory(fallbackCategory)

        if let normalized, FinanceDraftDefaults.type(for: normalized, fallback: type) == type {
            return normalized
        }

        switch type {
        case .gain:
            return "Other Income"
        case .owe:
            return "Other Expense"
        }
    }

    private static func reinforcedDraft(
        aiDraft: FinanceEntryDraft,
        localDraft: FinanceEntryDraft,
        prompt: String
    ) -> FinanceEntryDraft {
        let loweredPrompt = prompt.lowercased()
        let shouldTrustLocalFlow =
            loweredPrompt.contains("owes me") ||
            loweredPrompt.contains("owe me") ||
            loweredPrompt.contains("pay me back") ||
            loweredPrompt.contains("reimburse me") ||
            loweredPrompt.contains("i owe") ||
            loweredPrompt.contains("pay my") ||
            loweredPrompt.contains("pay mom") ||
            loweredPrompt.contains("pay mother")

        var draft = aiDraft
        if shouldTrustLocalFlow, draft.type != localDraft.type {
            draft.type = localDraft.type
            draft.category = category(for: localDraft.category, fallbackCategory: draft.category, type: localDraft.type)
        }

        let aiTitle = draft.entryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let localTitle = localDraft.entryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let aiMissedReason = loweredPrompt.contains(" for ") && !aiTitle.lowercased().contains(" for ")
        if shouldTrustLocalFlow, !localTitle.isEmpty, (aiTitle.isEmpty || aiMissedReason) {
            draft.entryDescription = localTitle
        }

        return draft
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}

private struct OpenAIConfiguration {
    let apiKey: String
    let model: String

    static let validCategories = FinanceCategory.incomeRawValues + FinanceCategory.expenseRawValues

    static func load() -> OpenAIConfiguration? {
        let key = (
            ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ??
            Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else { return nil }

        let configuredModel = (
            Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL_ID") as? String ??
            "openai/gpt-4o-mini"
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let model = configuredModel.isEmpty ? "openai/gpt-4o-mini" : configuredModel
        print("[OpenRouter] Configuration loaded — model: \(model)")
        return OpenAIConfiguration(
            apiKey: key,
            model: model
        )
    }
}

private struct OpenRouterChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat

    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
        let jsonSchema: JSONSchemaWrapper

        struct JSONSchemaWrapper: Encodable {
            let name: String
            let strict: Bool
            let schema: JSONSchema

            enum CodingKeys: String, CodingKey {
                case name, strict, schema
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

private struct JSONSchema: Encodable {
    let type: String
    let properties: [String: JSONSchemaValue]
    let required: [String]
    let additionalProperties: Bool

    static let financeTransaction = JSONSchema(
        type: "object",
        properties: [
            "title": .string,
            "amount": .number,
            "hasAmount": .boolean,
            "type": .enumeration(["gain", "owe"]),
            "category": .enumeration(OpenAIConfiguration.validCategories),
            "urgency": .enumeration(["low", "medium", "high"]),
            "dateISO8601": .string
        ],
        required: ["title", "amount", "hasAmount", "type", "category", "urgency", "dateISO8601"],
        additionalProperties: false
    )
}

private struct JSONSchemaValue: Encodable {
    let type: String?
    let enumValues: [String]?

    init(type: String? = nil, enumValues: [String]? = nil) {
        self.type = type
        self.enumValues = enumValues
    }

    static let string = JSONSchemaValue(type: "string")
    static let number = JSONSchemaValue(type: "number")
    static let boolean = JSONSchemaValue(type: "boolean")

    static func enumeration(_ values: [String]) -> JSONSchemaValue {
        JSONSchemaValue(type: "string", enumValues: values)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case enumValues = "enum"
    }
}

private struct OpenRouterChatResponse: Decodable {
    let choices: [Choice]

    var firstContent: String? {
        choices.first?.message.content
    }

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

private struct OpenAIAPIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

private struct FinanceAITransactionPayload: Decodable {
    let title: String
    let amount: Double
    let hasAmount: Bool
    let type: String
    let category: String
    let urgency: String
    let dateISO8601: String

    var resolvedDate: Date {
        let formatters = [Self.iso8601WithFractionalSeconds, Self.iso8601]
        for formatter in formatters {
            if let date = formatter.date(from: dateISO8601) {
                return date
            }
        }
        return .now
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private enum FinanceAIError: LocalizedError {
    case invalidResponse
    case invalidPayload(String)
    case apiError(String)
    case unableToInterpret(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The AI service returned an invalid response."
        case .invalidPayload(let message), .apiError(let message), .unableToInterpret(let message):
            return message
        }
    }
}
