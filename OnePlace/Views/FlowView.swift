import SwiftUI
import UIKit
import UserNotifications

struct FlowView: View {
    @StateObject private var vm = FlowViewModel()
    @EnvironmentObject private var aiAssistant: AIAssistantManager

    @State private var editingItem: ItemEditorDestination<FlowItemRecord>?
    @State private var inlineItemText = ""
    @State private var inlineItemError: String?
    @State private var inlineItemType: FlowType = .bill
    @State private var inlineItemFrequency: FlowFrequency = .monthly
    @State private var inlineItemDueDate: Date? = nil
    @State private var searchText = ""
    @State private var statusFilter: FlowStatus? = nil
    @State private var lastRefreshToken: UUID?
    @State private var showingClearPaidConfirm = false

    private var filteredItems: [FlowItemRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.items }
        return vm.items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.type.rawValue.localizedCaseInsensitiveContains(query) ||
            $0.frequency.rawValue.localizedCaseInsensitiveContains(query) ||
            ($0.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var upcomingItems: [FlowItemRecord] {
        filteredItems.filter { $0.status == .upcoming }
    }

    private var paidItems: [FlowItemRecord] {
        filteredItems.filter { $0.status == .paid }
    }

    private var allPaidItems: [FlowItemRecord] {
        vm.items.filter { $0.status == .paid }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    flowPulseCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                summarySection
                upcomingSection
                paidSection
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
            .navigationTitle("Flow")
            .searchable(text: $searchText, prompt: "Search bills and income")
            .refreshable { await vm.refresh() }
            .sheet(item: $editingItem) { destination in
                FlowItemEditorView(item: destination.item) { draft in
                    if let item = destination.item {
                        let updated = FlowItemRecord(
                            id: item.id,
                            ownerUserId: item.ownerUserId,
                            title: draft.title,
                            amount: draft.amount,
                            type: draft.type,
                            frequency: draft.frequency,
                            nextDueDate: draft.nextDueDate,
                            status: draft.status,
                            notes: draft.notes,
                            reminderEnabled: draft.reminderEnabled,
                            reminderDate: draft.reminderDate,
                            reminderHour: draft.reminderHour,
                            reminderMinute: draft.reminderMinute,
                            reminderRepeat: draft.reminderRepeat,
                            reminderOffsetDays: draft.reminderOffsetDays
                        )
                        await vm.updateItem(updated)
                    } else {
                        await vm.addItem(draft: draft)
                    }
                    let error = vm.errorMessage
                    if error == nil, destination.item == nil {
                        searchText = ""
                        statusFilter = draft.status
                    }
                    vm.errorMessage = nil
                    return error
                }
            }
            .alert("Flow Error", isPresented: flowErrorBinding) {
                Button("OK", role: .cancel) {
                    vm.errorMessage = nil
                }
            } message: {
                Text(vm.errorMessage ?? "Please try again.")
            }
            .alert("Clear Paid Items?", isPresented: $showingClearPaidConfirm) {
                Button("Clear All", role: .destructive) {
                    Task { await vm.clearPaidItems() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every item marked paid from Flow.")
            }
            .task {
                await vm.refresh()
            }
            .onChange(of: aiAssistant.pendingActionsToken) { _, newToken in
                if lastRefreshToken != newToken {
                    lastRefreshToken = newToken
                    Task { await vm.refresh() }
                }
            }
        }
    }

    private var flowErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil && editingItem == nil },
            set: { isPresented in
                if !isPresented {
                    vm.errorMessage = nil
                }
            }
        )
    }

    private var monthlyFlowLoad: Double {
        upcomingItems.reduce(0) { partialResult, item in
            partialResult + normalizedMonthlyAmount(for: item)
        }
    }

    private var flowPulseCard: some View {
        WorkspacePulseCard(
            title: "Flow Pulse",
            subtitle: flowPulseSubtitle,
            icon: upcomingItems.isEmpty ? "calendar.badge.checkmark" : "calendar.badge.clock",
            tint: upcomingItems.isEmpty ? DesignSystem.gainColor : DesignSystem.warmAccent,
            primaryValue: StatCard.currencyString(for: monthlyFlowLoad),
            primaryLabel: "monthly load",
            secondaryValue: "\(upcomingItems.count)",
            secondaryLabel: "upcoming",
            actionTitle: statusFilter == nil ? "Upcoming" : "All"
        ) {
            withAnimation {
                statusFilter = statusFilter == nil ? .upcoming : nil
            }
        }
    }

    private var flowPulseSubtitle: String {
        guard let next = upcomingItems.first else {
            return paidItems.isEmpty ? "Add a bill or income to build your rhythm." : "\(paidItems.count) items are already marked paid."
        }

        let dueText = next.nextDueDate.formatted(date: .abbreviated, time: .omitted)
        return "\(next.title) is next, due \(dueText)."
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 10) {
                Button {
                    withAnimation { statusFilter = statusFilter == .upcoming ? nil : .upcoming }
                } label: {
                    StatCard(
                        title: "Upcoming",
                        value: upcomingItems.count.formatted(),
                        icon: "calendar",
                        tint: DesignSystem.accentColor,
                        isSelected: statusFilter == .upcoming
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation { statusFilter = statusFilter == .paid ? nil : .paid }
                } label: {
                    StatCard(
                        title: "Paid",
                        value: paidItems.count.formatted(),
                        icon: "checkmark.circle.fill",
                        tint: DesignSystem.gainColor,
                        isSelected: statusFilter == .paid
                    )
                }
                .buttonStyle(.plain)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .listRowBackground(Color.clear)
        }
    }

    private var upcomingSection: some View {
        Section("Upcoming") {
            if statusFilter == .paid {
                EmptyView()
            } else if vm.isLoading && vm.items.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
            } else if upcomingItems.isEmpty {
                inlineFlowAddRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                EmptyState(
                    title: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No upcoming bills" : "No matching upcoming bills",
                    message: "Add a bill or income item, or ask OnePlace to schedule it for you.",
                    systemImage: "calendar.badge.plus",
                    ctaTitle: nil
                )
                .padding(.vertical, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                inlineFlowAddRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(upcomingItems) { item in
                    flowItemRow(for: item)
                        .onTapGesture {
                            editingItem = .edit(item)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var inlineFlowAddRow: some View {
        InlineAddItemRow(
            text: $inlineItemText,
            placeholder: "New bill or income, like Rent 1200 due on the 1st",
            systemImage: "plus.circle.fill",
            tint: DesignSystem.accentColor,
            isSaving: vm.isLoading,
            validationMessage: inlineItemError,
            onSubmit: saveInlineItem,
            onCancel: cancelInlineItemAdd
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    InlineAddHelperMenu(title: "Bill or income", systemImage: "arrow.up.arrow.down", tint: DesignSystem.accentColor) {
                        Picker("Type", selection: $inlineItemType) {
                            ForEach(FlowType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                    }
                    InlineAddHelperMenu(title: "Frequency", systemImage: "repeat", tint: DesignSystem.secondaryAccent) {
                        Picker("Frequency", selection: $inlineItemFrequency) {
                            ForEach(FlowFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue.capitalized).tag(frequency)
                            }
                        }
                    }
                    InlineAddHelperButton(title: "Due today", systemImage: "calendar", tint: DesignSystem.warmAccent, isSelected: inlineItemDueDate.map(Calendar.current.isDateInToday) == true) {
                        inlineItemDueDate = .now
                    }
                    InlineAddHelperButton(title: "Due tomorrow", systemImage: "calendar.badge.clock", tint: DesignSystem.accentColor, isSelected: inlineItemDueDate.map(Calendar.current.isDateInTomorrow) == true) {
                        inlineItemDueDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)
                    }
                }
                .padding(.leading, 40)
            }
        }
    }

    private var paidSection: some View {
        Section("Paid") {
            if statusFilter == .upcoming {
                EmptyView()
            } else {
                if !allPaidItems.isEmpty {
                    paidSectionActions
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if paidItems.isEmpty {
                    EmptyState(
                        title: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nothing marked paid" : "No matching paid items",
                        message: "Swipe a row to mark it paid when it is handled.",
                        systemImage: "checkmark.circle",
                        ctaTitle: nil
                    )
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(paidItems) { item in
                        flowItemRow(for: item)
                            .onTapGesture {
                                editingItem = .edit(item)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
    }

    private var paidSectionActions: some View {
        HStack {
            Label("\(allPaidItems.count) paid", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                showingClearPaidConfirm = true
            } label: {
                Label("Clear All", systemImage: "trash")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(vm.isLoading)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func flowItemRow(for item: FlowItemRecord) -> some View {
        AppCard {
            HStack(spacing: 12) {
                ItemIconBadge(symbol: flowIcon(for: item), tint: flowAccent(for: item))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)

                    Text("\(item.frequency.rawValue.capitalized) · \(item.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if item.reminderEnabled {
                        Label(reminderSummary(for: item), systemImage: "bell.badge.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.accentColor)
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(StatCard.currencyString(for: item.amount))
                        .font(.headline)
                        .foregroundStyle(item.type == .income ? DesignSystem.gainColor : DesignSystem.warmAccent)

                    Text(item.status.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint(for: item.status))
                }
            }
            .opacity(item.status == .paid ? 0.72 : 1)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await vm.toggleStatus(for: item) }
            } label: {
                Label(item.status == .paid ? "Mark Upcoming" : "Mark Paid",
                      systemImage: item.status == .paid ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(DesignSystem.gainColor)
        }
        .swipeActions(edge: .trailing) {
            Button {
                editingItem = .edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(DesignSystem.accentColor)

            Button(role: .destructive) {
                Task { await vm.deleteItem(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func reminderSummary(for item: FlowItemRecord) -> String {
        let reminderDate = item.reminderDate ?? item.nextDueDate
        switch item.reminderRepeat {
        case .none:
            return "Reminder \(reminderDate.formatted(date: .abbreviated, time: .shortened))"
        case .daily:
            return "Repeats daily"
        case .weekly:
            return "Repeats weekly"
        case .monthly:
            return "Repeats monthly"
        }
    }

    private func flowIcon(for item: FlowItemRecord) -> String {
        switch item.type {
        case .income:
            return "arrow.up.right"
        case .bill:
            return item.status == .paid ? "checkmark.circle.fill" : "calendar"
        }
    }

    private func handleSearchSubmit(wasVoice: Bool) {
        let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              OnePlacePromptClassifier.isCommand(prompt, in: .flow) else {
            if wasVoice {
                aiAssistant.openVoiceMode(area: .flow)
            }
            return
        }

        if wasVoice {
            aiAssistant.openVoiceMode(area: .flow)
        } else {
            aiAssistant.openChatFresh(area: .flow, voice: false)
        }
        aiAssistant.userSaid(prompt)
        searchText = ""

        Task {
            await AIChatResponder.handleUserInput(text: prompt, assistant: aiAssistant)
            await vm.refresh()
        }
    }

    private func cancelInlineItemAdd() {
        inlineItemText = ""
        inlineItemError = nil
    }

    private func saveInlineItem() {
        let prompt = inlineItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        guard var draft = FlowPromptInterpreter.interpret(prompt), draft.amount > 0 else {
            inlineItemError = "Include an amount, like Rent 1200 due on the 1st."
            return
        }
        draft.type = inlineItemType
        draft.frequency = inlineItemFrequency
        if let inlineItemDueDate {
            draft.nextDueDate = inlineItemDueDate
        }

        Task {
            await vm.addItem(draft: draft)
            guard vm.errorMessage == nil else {
                inlineItemError = vm.errorMessage
                return
            }

            await MainActor.run {
                searchText = ""
                statusFilter = .upcoming
                inlineItemText = ""
                inlineItemError = nil
                inlineItemDueDate = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func flowAccent(for item: FlowItemRecord) -> Color {
        switch item.type {
        case .income:
            return DesignSystem.gainColor
        case .bill:
            return item.status == .paid ? DesignSystem.accentColor : DesignSystem.warmAccent
        }
    }

    private func statusTint(for status: FlowStatus) -> Color {
        switch status {
        case .upcoming:
            return DesignSystem.warmAccent
        case .paid:
            return DesignSystem.gainColor
        case .skipped:
            return DesignSystem.secondaryTextColor
        }
    }

    private func normalizedMonthlyAmount(for item: FlowItemRecord) -> Double {
        switch item.frequency {
        case .weekly: return item.amount * 52 / 12
        case .biweekly: return item.amount * 26 / 12
        case .monthly: return item.amount
        case .quarterly: return item.amount / 3
        case .yearly: return item.amount / 12
        }
    }
}

enum FlowPromptInterpreter {
    static func interpret(_ prompt: String, now: Date = .now) -> FlowItemDraft? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedPrompt = normalizeSpeech(trimmed)
        let lowered = normalizedPrompt.lowercased()
        let amount = extractAmount(from: normalizedPrompt) ?? 0
        let frequency = extractFrequency(from: lowered)
        let type = extractType(from: lowered)
        let dueDate = extractDate(from: normalizedPrompt, lowered: lowered, frequency: frequency, now: now)
        let reminderDate = reminderDate(from: normalizedPrompt, lowered: lowered, dueDate: dueDate, now: now)
        let repeatsReminder = reminderDate != nil && isRecurring(lowered)

        return FlowItemDraft(
            title: title(from: normalizedPrompt, amount: amount),
            amount: amount,
            type: type,
            frequency: frequency,
            nextDueDate: dueDate,
            status: .upcoming,
            notes: nil,
            reminderEnabled: reminderDate != nil || lowered.contains("remind"),
            reminderDate: reminderDate,
            reminderHour: reminderDate.map { Calendar.current.component(.hour, from: $0) },
            reminderMinute: reminderDate.map { Calendar.current.component(.minute, from: $0) },
            reminderRepeat: repeatsReminder || lowered.contains("repeat") ? reminderRepeat(for: frequency) : .none,
            reminderOffsetDays: 0
        )
    }

    private static func normalizeSpeech(_ prompt: String) -> String {
        prompt
            .replacingOccurrences(of: #"\bbowl\b"#, with: "bill", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\bbowls\b"#, with: "bills", options: [.regularExpression, .caseInsensitive])
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

    private static func extractFrequency(from prompt: String) -> FlowFrequency {
        if prompt.contains("biweekly") || prompt.contains("every two weeks") {
            return .biweekly
        }

        if prompt.contains("weekly") || prompt.contains("every week") {
            return .weekly
        }

        if prompt.contains("quarterly") {
            return .quarterly
        }

        if prompt.contains("yearly") || prompt.contains("annual") || prompt.contains("every year") {
            return .yearly
        }

        return .monthly
    }

    private static func extractType(from prompt: String) -> FlowType {
        let incomeWords = ["income", "salary", "paycheck", "paid", "deposit", "freelance", "client"]
        return incomeWords.contains(where: prompt.contains) ? .income : .bill
    }

    private static func extractDate(
        from prompt: String,
        lowered: String,
        frequency: FlowFrequency,
        now: Date
    ) -> Date {
        let calendar = Calendar.autoupdatingCurrent

        if lowered.contains("tomorrow"),
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            return tomorrow
        }

        if let day = dayOfMonth(in: lowered) {
            return dateFromDay(day, now: now, hour: 9, minute: 0)
        }

        if let detectedDate = detectedDate(in: prompt) {
            return detectedDate
        }

        let defaultOffset: Int
        switch frequency {
        case .weekly:
            defaultOffset = 7
        case .biweekly:
            defaultOffset = 14
        case .monthly:
            defaultOffset = 30
        case .quarterly:
            defaultOffset = 90
        case .yearly:
            defaultOffset = 365
        }

        return calendar.date(byAdding: .day, value: defaultOffset, to: now) ?? now
    }

    private static func detectedDate(in prompt: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        return detector?.matches(in: prompt, range: range).first?.date
    }

    private static func dayOfMonth(in prompt: String) -> Int? {
        let pattern = #"\b(?:on|due|for|every|the|reminder\s+for|remind\s+me\s+on)\s+(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?\b|\b(\d{1,2})(?:st|nd|rd|th)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        guard let match = regex.firstMatch(in: prompt, range: range) else {
            return nil
        }

        let firstRange = match.range(at: 1)
        let secondRange = match.range(at: 2)
        let selectedRange = firstRange.location != NSNotFound ? firstRange : secondRange
        guard let dayRange = Range(selectedRange, in: prompt) else { return nil }
        return Int(prompt[dayRange]).map { min(max($0, 1), 28) }
    }

    private static func reminderDate(from prompt: String, lowered: String, dueDate: Date, now: Date) -> Date? {
        guard lowered.contains("remind") || lowered.contains("reminder") else {
            return nil
        }

        if let day = dayOfMonth(in: lowered) {
            return dateFromDay(day, now: now, hour: 9, minute: 0)
        }

        return detectedDate(in: prompt) ?? dueDate
    }

    private static func dateFromDay(_ day: Int, now: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = min(max(day, 1), 28)
        components.hour = hour
        components.minute = minute
        let candidate = calendar.date(from: components) ?? now
        if calendar.startOfDay(for: candidate) < calendar.startOfDay(for: now),
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: candidate) {
            return nextMonth
        }

        return candidate
    }

    private static func isRecurring(_ prompt: String) -> Bool {
        [
            "monthly", "weekly", "biweekly", "quarterly", "yearly", "annual",
            "every month", "every week", "every year", "repeats", "repeat"
        ].contains(where: prompt.contains)
    }

    private static func reminderRepeat(for frequency: FlowFrequency) -> ReminderRepeatRule {
        switch frequency {
        case .weekly, .biweekly:
            return .weekly
        case .monthly, .quarterly, .yearly:
            return .monthly
        }
    }

    private static func title(from prompt: String, amount: Double) -> String {
        if let subject = subjectTitle(from: prompt) {
            return subject
        }

        var value = prompt

        if amount > 0 {
            let amountText = amount.rounded() == amount ? String(Int(amount)) : String(amount)
            value = value.replacingOccurrences(of: "$\(amountText)", with: "", options: .caseInsensitive)
            value = value.replacingOccurrences(of: amountText, with: "", options: .caseInsensitive)
        }

        let disposableTerms = [
            "add", "log", "record", "track", "bill", "income", "monthly", "weekly",
            "biweekly", "quarterly", "yearly", "annual", "reminder", "remind", "repeat",
            "due", "on", "the", "every", "for", "next", "tomorrow", "today", "with",
            "amount", "set", "my", "a", "an", "of", "month"
        ]

        let words = value
            .replacingOccurrences(of: #"[^A-Za-z0-9'&\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { word in
                let lowered = word.lowercased()
                return !disposableTerms.contains(lowered) && lowered.rangeOfCharacter(from: .decimalDigits) == nil
            }

        guard !words.isEmpty else { return "New Flow Item" }
        return words.prefix(4).map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
    }

    private static func subjectTitle(from prompt: String) -> String? {
        let patterns = [
            #"\bfor\s+(?:my\s+|the\s+|a\s+|an\s+)?(.+?)(?:\s+with\s+(?:the\s+)?amount|\s+amount|\s+and\s+set|\s+set\s+a\s+reminder|\s+reminder|\s+due|\s+on\s+the\s+\d|\s*$)"#,
            #"\b(?:bill|income)\s+(?:for\s+)?(?:my\s+|the\s+|a\s+|an\s+)?(.+?)(?:\s+with\s+(?:the\s+)?amount|\s+amount|\s+and\s+set|\s+set\s+a\s+reminder|\s+reminder|\s+due|\s*$)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
            guard let match = regex.firstMatch(in: prompt, range: range),
                  let captureRange = Range(match.range(at: 1), in: prompt) else {
                continue
            }

            let cleaned = String(prompt[captureRange])
                .replacingOccurrences(of: #"\$?\d+(?:\.\d{1,2})?\b"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"[^A-Za-z0-9'&\s]"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty {
                return cleaned
                    .split(whereSeparator: \.isWhitespace)
                    .prefix(4)
                    .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                    .joined(separator: " ")
            }
        }

        return nil
    }
}

private struct FlowItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var saveError: String?

    @State private var title: String
    @State private var amountText: String
    @State private var type: FlowType
    @State private var frequency: FlowFrequency
    @State private var nextDueDate: Date
    @State private var status: FlowStatus
    @State private var notes: String
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date
    @State private var reminderRepeat: ReminderRepeatRule

    private let item: FlowItemRecord?
    private let onSave: (FlowItemDraft) async -> String?

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    init(item: FlowItemRecord?, onSave: @escaping (FlowItemDraft) async -> String?) {
        self.item = item
        self.onSave = onSave

        _title = State(initialValue: item?.title ?? "")
        if let item {
            let formattedAmount = Self.amountFormatter.string(from: NSNumber(value: item.amount)) ?? ""
            _amountText = State(initialValue: formattedAmount)
        } else {
            _amountText = State(initialValue: "")
        }
        _type = State(initialValue: item?.type ?? .bill)
        _frequency = State(initialValue: item?.frequency ?? .monthly)
        _nextDueDate = State(initialValue: item?.nextDueDate ?? Date())
        _status = State(initialValue: item?.status ?? .upcoming)
        _notes = State(initialValue: item?.notes ?? "")
        _reminderEnabled = State(initialValue: item?.reminderEnabled ?? false)
        _reminderDate = State(initialValue: item?.reminderDate ?? item?.nextDueDate ?? Date())
        _reminderRepeat = State(initialValue: item?.reminderRepeat ?? .none)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CreationGuideCard(
                        title: type == .income ? "Recurring Income" : "Scheduled Bill",
                        subtitle: "Add the amount, cadence, due date, and optional reminder. OnePlace will roll recurring items forward when they are paid.",
                        icon: type == .income ? "arrow.down.circle.fill" : "calendar.badge.clock",
                        tint: type == .income ? DesignSystem.gainColor : DesignSystem.warmAccent,
                        status: parsedAmount.map { StatCard.currencyString(for: $0) } ?? "Needs amount"
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Type", selection: $type) {
                        ForEach(FlowType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                        }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(FlowFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue.capitalized)
                        }
                    }
                    DatePicker("Next Due", selection: $nextDueDate, displayedComponents: .date)
                    Picker("Status", selection: $status) {
                        ForEach(FlowStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Reminder") {
                    Toggle("Send notification reminder", isOn: $reminderEnabled)

                    if reminderEnabled {
                        DatePicker(
                            "Remind Me",
                            selection: $reminderDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Picker("Repeat", selection: $reminderRepeat) {
                            ForEach(ReminderRepeatRule.allCases, id: \.self) { rule in
                                Text(ruleLabel(for: rule)).tag(rule)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle(item == nil ? "New Flow Item" : "Edit Flow Item")
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
                    Button(item == nil ? "Add" : "Save") {
                        guard let amountValue = parsedAmount, amountValue > 0 else { return }
                        let reminderComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

                        let draft = FlowItemDraft(
                            title: trimmedTitle,
                            amount: amountValue,
                            type: type,
                            frequency: frequency,
                            nextDueDate: nextDueDate,
                            status: status,
                            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                            reminderEnabled: reminderEnabled,
                            reminderDate: reminderEnabled ? reminderDate : nil,
                            reminderHour: reminderEnabled ? reminderComponents.hour : nil,
                            reminderMinute: reminderEnabled ? reminderComponents.minute : nil,
                            reminderRepeat: reminderEnabled ? reminderRepeat : .none,
                            reminderOffsetDays: 0
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
            .onChange(of: nextDueDate) { _, newValue in
                guard !reminderEnabled else { return }
                reminderDate = newValue
            }
            .onChange(of: reminderEnabled) { _, enabled in
                guard enabled, reminderDate < Date() else { return }
                reminderDate = nextDueDate
            }
        }
    }

    private var parsedAmount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cleaned = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private var isSaveDisabled: Bool {
        guard let amountValue = parsedAmount, amountValue > 0 else { return true }
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func ruleLabel(for rule: ReminderRepeatRule) -> String {
        switch rule {
        case .none:
            return "One time"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
}
