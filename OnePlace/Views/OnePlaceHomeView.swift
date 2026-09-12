import SwiftUI

struct OnePlaceHomeView: View {
    var selectTab: (String) -> Void

    @EnvironmentObject private var aiAssistant: AIAssistantManager
    @StateObject private var financeVM = FinanceViewModel()
    @StateObject private var flowVM = FlowViewModel()
    @StateObject private var organizerVM = OrganizerViewModel()
    @StateObject private var splitVM = SplitViewModel()
    @StateObject private var commsVM = CommsViewModel()

    @State private var didLoad = false
    @State private var commandText = ""

    private var isLoading: Bool {
        financeVM.isLoading || flowVM.isLoading || organizerVM.isLoading || splitVM.isLoading || commsVM.isLoading
    }

    private var openFinanceEntries: [FinanceEntryRecord] {
        financeVM.entries.filter { !$0.isCompleted }
    }

    private var gainTotal: Double {
        openFinanceEntries.filter { $0.type == .gain }.reduce(0) { $0 + $1.amount }
    }

    private var oweTotal: Double {
        openFinanceEntries.filter { $0.type == .owe }.reduce(0) { $0 + $1.amount }
    }

    private var netFinanceTotal: Double {
        gainTotal - oweTotal
    }

    private var openTasks: [TaskItemRecord] {
        organizerVM.tasks.filter { !$0.completed }.sortedForOrganizer()
    }

    private var todayTasks: [TaskItemRecord] {
        let tomorrow = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: 1,
            to: Calendar.autoupdatingCurrent.startOfDay(for: .now)
        ) ?? .now

        return openTasks.filter { task in
            guard let dueDate = task.dueDate else { return true }
            return dueDate < tomorrow
        }
    }

    private var urgentTaskCount: Int {
        todayTasks.filter { $0.priority == .high }.count
    }

    private var upcomingFlowItems: [FlowItemRecord] {
        flowVM.items
            .filter { $0.status == .upcoming }
            .sorted {
                if $0.nextDueDate != $1.nextDueDate {
                    return $0.nextDueDate < $1.nextDueDate
                }

                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private var monthlyFlowLoad: Double {
        upcomingFlowItems.reduce(0) { partialResult, item in
            partialResult + normalizedMonthlyAmount(for: item)
        }
    }

    private var unsettledSplitTotal: Double {
        splitVM.people.reduce(0) { partialResult, person in
            let balance = splitVM.getBalance(for: person)
            return balance > 0 ? partialResult + balance : partialResult
        }
    }

    private var focusScore: Int {
        min(99, todayTasks.count * 12 + upcomingFlowItems.prefix(3).count * 8 + openFinanceEntries.count * 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroPanel
                    commandCenter
                    metricsGrid
                    insightStrip
                    quickActions
                    prioritySection
                    upcomingTimeline
                    workspaceSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, DesignSystem.tabBarContentInset + 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle("OnePlace")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshAll()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Refresh dashboard")
                }
            }
            .task {
                guard !didLoad else { return }
                didLoad = true
                await refreshDashboard()
            }
            .refreshable {
                await refreshDashboard()
            }
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DesignSystem.logoGradient)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)
                .shadow(color: DesignSystem.accentColor.opacity(0.25), radius: 12, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.accentColor)

                    Text(heroTitle)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                HomeStatusPill(
                    title: "\(todayTasks.count) today",
                    icon: "checklist",
                    tint: DesignSystem.accentColor
                )

                HomeStatusPill(
                    title: "\(upcomingFlowItems.count) upcoming",
                    icon: "calendar.badge.clock",
                    tint: DesignSystem.warmAccent
                )

                HomeStatusPill(
                    title: focusScore > 55 ? "High focus" : "Steady",
                    icon: focusScore > 55 ? "bolt.fill" : "gauge.with.dots.needle.50percent",
                    tint: focusScore > 55 ? DesignSystem.oweColor : DesignSystem.gainColor
                )
            }

            Button {
                openAssistant(area: .organizer)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                    Text("Plan my next move")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.accentColor, DesignSystem.secondaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.pressable)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignSystem.highlightedCardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
        )
        .shadow(color: DesignSystem.shadowColor.opacity(0.13), radius: 18, x: 0, y: 10)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            HomeMetricCard(
                title: "Net Open",
                value: currency(netFinanceTotal),
                subtitle: financeSubtitle,
                icon: "dollarsign.circle.fill",
                tint: netFinanceTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor
            ) {
                selectTab("finance")
            }

            HomeMetricCard(
                title: "Flow Load",
                value: currency(monthlyFlowLoad),
                subtitle: "normalized monthly",
                icon: "calendar.badge.clock",
                tint: DesignSystem.warmAccent
            ) {
                selectTab("flow")
            }

            HomeMetricCard(
                title: "Tasks",
                value: todayTasks.count.formatted(),
                subtitle: urgentTaskCount > 0 ? "\(urgentTaskCount) high priority" : "\(openTasks.count) open total",
                icon: "checkmark.circle.fill",
                tint: DesignSystem.accentColor
            ) {
                selectTab("organizer")
            }

            HomeMetricCard(
                title: "Split",
                value: currency(unsettledSplitTotal),
                subtitle: "\(splitVM.people.count) people tracked",
                icon: "person.2.fill",
                tint: DesignSystem.secondaryAccent
            ) {
                selectTab("split")
            }
        }
    }

    private var commandCenter: some View {
        HomeCommandBar(text: $commandText) {
            submitHomeCommand()
        }
    }

    private var insightStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "Daily Readout", actionTitle: nil, action: nil)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(insights) { insight in
                        HomeInsightCard(insight: insight)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "Create With AI", actionTitle: nil, action: nil)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    HomeActionButton(title: "Transaction", icon: "dollarsign", tint: DesignSystem.gainColor) {
                        openAssistant(area: .finance)
                    }

                    HomeActionButton(title: "Bill", icon: "calendar.badge.plus", tint: DesignSystem.warmAccent) {
                        openAssistant(area: .flow)
                    }

                    HomeActionButton(title: "Task", icon: "checklist", tint: DesignSystem.accentColor) {
                        openAssistant(area: .organizer)
                    }

                    HomeActionButton(title: "Split", icon: "person.2.badge.plus", tint: DesignSystem.secondaryAccent) {
                        openAssistant(area: .split)
                    }

                    HomeActionButton(title: "Talk Card", icon: "bubble.left.and.bubble.right.fill", tint: DesignSystem.oweColor) {
                        openAssistant(area: .talk)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "Needs Attention", actionTitle: "Tasks") {
                selectTab("organizer")
            }

            if todayTasks.isEmpty && upcomingFlowItems.isEmpty && openFinanceEntries.isEmpty {
                AppCard {
                    HStack(spacing: 12) {
                        ItemIconBadge(symbol: "checkmark.seal.fill", tint: DesignSystem.gainColor, size: 42)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You are clear for now")
                                .font(.headline)
                            Text("No urgent tasks, Flow items, or open finance entries need immediate attention.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(attentionItems.prefix(4)) { item in
                        HomeAttentionRow(item: item) {
                            selectTab(item.tabRawValue)
                        }
                    }
                }
            }
        }
    }

    private var upcomingTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "Next Up", actionTitle: "Flow") {
                selectTab("flow")
            }

            if timelineItems.isEmpty {
                AppCard {
                    HStack(spacing: 12) {
                        ItemIconBadge(symbol: "calendar.badge.checkmark", tint: DesignSystem.gainColor, size: 42)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No dated items ahead")
                                .font(.headline)
                            Text("Scheduled bills, income, and dated tasks will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(timelineItems.prefix(5)) { item in
                        HomeTimelineRow(item: item) {
                            selectTab(item.tabRawValue)
                        }
                    }
                }
            }
        }
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "Workspaces", actionTitle: nil, action: nil)

            VStack(spacing: 10) {
                HomeWorkspaceRow(
                    title: "Finance",
                    subtitle: "\(openFinanceEntries.count) open entries",
                    icon: "dollarsign.circle.fill",
                    tint: DesignSystem.gainColor
                ) {
                    selectTab("finance")
                }

                HomeWorkspaceRow(
                    title: "Flow",
                    subtitle: "\(upcomingFlowItems.count) upcoming bills and income",
                    icon: "calendar.badge.clock",
                    tint: DesignSystem.warmAccent
                ) {
                    selectTab("flow")
                }

                HomeWorkspaceRow(
                    title: "Tasks",
                    subtitle: "\(openTasks.count) open tasks",
                    icon: "checklist",
                    tint: DesignSystem.accentColor
                ) {
                    selectTab("organizer")
                }

                HomeWorkspaceRow(
                    title: "Talk",
                    subtitle: "\(commsVM.cards.count) communication cards",
                    icon: "bubble.left.and.bubble.right.fill",
                    tint: DesignSystem.oweColor
                ) {
                    selectTab("talk")
                }

                HomeWorkspaceRow(
                    title: "Settings",
                    subtitle: "Account, privacy, and app preferences",
                    icon: "gearshape.fill",
                    tint: DesignSystem.secondaryTextColor
                ) {
                    selectTab("settings")
                }
            }
        }
    }

    private var attentionItems: [HomeAttentionItem] {
        var items: [HomeAttentionItem] = []

        if let firstTask = todayTasks.first {
            items.append(
                HomeAttentionItem(
                    title: firstTask.title,
                    subtitle: firstTask.priority == .high ? "High priority task" : "Task due today",
                    icon: firstTask.priority == .high ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    tint: firstTask.priority == .high ? DesignSystem.oweColor : DesignSystem.accentColor,
                    tabRawValue: "organizer"
                )
            )
        }

        if let nextFlow = upcomingFlowItems.first {
            items.append(
                HomeAttentionItem(
                    title: nextFlow.title,
                    subtitle: "\(currency(nextFlow.amount)) due \(nextFlow.nextDueDate.formatted(date: .abbreviated, time: .omitted))",
                    icon: nextFlow.type == .income ? "arrow.down.circle.fill" : "calendar.badge.exclamationmark",
                    tint: nextFlow.type == .income ? DesignSystem.gainColor : DesignSystem.warmAccent,
                    tabRawValue: "flow"
                )
            )
        }

        if let financeEntry = openFinanceEntries.sorted(by: { $0.date > $1.date }).first {
            items.append(
                HomeAttentionItem(
                    title: financeEntry.entryDescription.isEmpty ? financeEntry.category : financeEntry.entryDescription,
                    subtitle: "\(financeEntry.type == .gain ? "Incoming" : "Owed") \(currency(financeEntry.amount))",
                    icon: financeEntry.type == .gain ? "plus.circle.fill" : "minus.circle.fill",
                    tint: financeEntry.type == .gain ? DesignSystem.gainColor : DesignSystem.oweColor,
                    tabRawValue: "finance"
                )
            )
        }

        if unsettledSplitTotal > 0 {
            items.append(
                HomeAttentionItem(
                    title: "Settle shared expenses",
                    subtitle: "\(currency(unsettledSplitTotal)) still open",
                    icon: "person.2.fill",
                    tint: DesignSystem.secondaryAccent,
                    tabRawValue: "split"
                )
            )
        }

        return items
    }

    private var timelineItems: [HomeTimelineItem] {
        var items: [HomeTimelineItem] = upcomingFlowItems.map { item in
            HomeTimelineItem(
                title: item.title,
                detail: "\(item.type == .income ? "Income" : "Bill") \(currency(item.amount))",
                date: item.nextDueDate,
                icon: item.type == .income ? "arrow.down.circle.fill" : "creditcard.fill",
                tint: item.type == .income ? DesignSystem.gainColor : DesignSystem.warmAccent,
                tabRawValue: "flow"
            )
        }

        items.append(contentsOf: openTasks.compactMap { task in
            guard let dueDate = task.dueDate else { return nil }
            return HomeTimelineItem(
                title: task.title,
                detail: task.priority == .high ? "High priority task" : "Task",
                date: dueDate,
                icon: task.priority == .high ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                tint: task.priority == .high ? DesignSystem.oweColor : DesignSystem.accentColor,
                tabRawValue: "organizer"
            )
        })

        return items.sorted {
            if $0.date != $1.date {
                return $0.date < $1.date
            }

            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var insights: [HomeInsight] {
        [
            HomeInsight(
                title: "Focus",
                value: focusScore > 55 ? "High" : "Steady",
                subtitle: focusScore > 55 ? "\(todayTasks.count) today, \(urgentTaskCount) urgent" : "\(todayTasks.count) things today",
                icon: focusScore > 55 ? "bolt.fill" : "gauge.with.dots.needle.50percent",
                tint: focusScore > 55 ? DesignSystem.oweColor : DesignSystem.gainColor
            ),
            HomeInsight(
                title: "Next Due",
                value: nextDueValue,
                subtitle: nextDueSubtitle,
                icon: "calendar",
                tint: DesignSystem.warmAccent
            ),
            HomeInsight(
                title: "Open Money",
                value: netFinanceTotal >= 0 ? "Positive" : "Negative",
                subtitle: currency(abs(netFinanceTotal)),
                icon: netFinanceTotal >= 0 ? "arrow.up.forward.circle.fill" : "arrow.down.forward.circle.fill",
                tint: netFinanceTotal >= 0 ? DesignSystem.gainColor : DesignSystem.oweColor
            )
        ]
    }

    private var greeting: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var heroTitle: String {
        if urgentTaskCount > 0 {
            return "You have \(urgentTaskCount) high-priority \(urgentTaskCount == 1 ? "task" : "tasks") to steady today."
        }

        if let nextFlow = upcomingFlowItems.first {
            return "\(nextFlow.title) is your next scheduled money move."
        }

        if todayTasks.isEmpty {
            return "Everything important is gathered and ready."
        }

        return "\(todayTasks.count) \(todayTasks.count == 1 ? "thing needs" : "things need") your attention today."
    }

    private var financeSubtitle: String {
        let gain = currency(gainTotal)
        let owe = currency(oweTotal)
        return "\(gain) in, \(owe) out"
    }

    private var nextDueValue: String {
        guard let next = timelineItems.first else { return "Clear" }
        if Calendar.autoupdatingCurrent.isDateInToday(next.date) {
            return "Today"
        }
        if Calendar.autoupdatingCurrent.isDateInTomorrow(next.date) {
            return "Tomorrow"
        }
        return next.date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var nextDueSubtitle: String {
        timelineItems.first?.title ?? "Nothing scheduled"
    }

    private func openAssistant(area: AIArea) {
        aiAssistant.openChatFresh(area: area, voice: false)
        aiAssistant.assistantSay(assistantWelcome(for: area), speak: false)
    }

    private func submitHomeCommand() {
        let text = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        commandText = ""
        let area = routedArea(for: text)
        aiAssistant.openChatFresh(area: area, voice: false)
        aiAssistant.userSaid(text)

        Task {
            await AIChatResponder.handleUserInput(text: text, assistant: aiAssistant)
        }
    }

    private func routedArea(for text: String) -> AIArea {
        let lowered = text.lowercased()

        if lowered.contains("talk card") ||
            lowered.contains("card that says") ||
            lowered.contains("make a yes") ||
            lowered.contains("make a no") {
            return .talk
        }

        if lowered.contains("split") ||
            lowered.contains("paid by") ||
            lowered.contains("shared") ||
            lowered.contains("owe us") ||
            lowered.contains("add person") {
            return .split
        }

        if lowered.contains("bill") ||
            lowered.contains("subscription") ||
            lowered.contains("monthly") ||
            lowered.contains("weekly") ||
            lowered.contains("salary") ||
            lowered.contains("paycheck") ||
            lowered.contains("mark paid") {
            return .flow
        }

        if lowered.contains("$") ||
            lowered.range(of: #"\b\d+(?:\.\d{1,2})?\b"#, options: .regularExpression) != nil ||
            lowered.contains("spent") ||
            lowered.contains("income") ||
            lowered.contains("owes me") ||
            lowered.contains("i owe") {
            return .finance
        }

        return .organizer
    }

    private func assistantWelcome(for area: AIArea) -> String {
        switch area {
        case .finance: return "Tell me the transaction in plain language and I will fill in the details."
        case .flow: return "Tell me the bill, income, amount, and timing. I will set up the Flow item."
        case .organizer: return "Tell me what you need to do. Dates and reminders can be included naturally."
        case .split: return "Tell me who paid, how much, and who was involved."
        case .talk: return "Tell me what the Talk card should say."
        case .settings: return "What would you like to adjust?"
        }
    }

    private func refreshAll() {
        Task { await refreshDashboard() }
    }

    private func refreshDashboard() async {
        await financeVM.refresh()
        await flowVM.refresh()
        await organizerVM.refresh()
        await splitVM.refresh()
        await commsVM.refresh()
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

    private func currency(_ amount: Double) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

private struct HomeAttentionItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let tabRawValue: String
}

private struct HomeTimelineItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date
    let icon: String
    let tint: Color
    let tabRawValue: String
}

private struct HomeInsight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
}

private struct HomeCommandBar: View {
    @Binding var text: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isInUse: Bool {
        isFocused || !trimmedText.isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DesignSystem.accentColor)

            TextField("Add anything to OnePlace", text: $text)
                .font(.system(size: 15, weight: .medium))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .lineLimit(1)
                .focused($isFocused)
                .onSubmit(onSubmit)

            if isInUse {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.accentColor, DesignSystem.secondaryAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(trimmedText.isEmpty)
                .opacity(trimmedText.isEmpty ? 0.55 : 1)
                .accessibilityLabel("Send command")
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(DesignSystem.interactiveSpring, value: isInUse)
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
        )
        .shadow(color: DesignSystem.shadowColor.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}

private struct HomeInsightCard: View {
    let insight: HomeInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(insight.tint)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(insight.tint.opacity(0.14))
                    )

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(insight.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(insight.tint)

                Text(insight.subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(13)
        .frame(width: 148, height: 130, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct HomeStatusPill: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct HomeMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ItemIconBadge(symbol: icon, tint: tint, size: 34)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .monospacedDigit()

                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .fill(DesignSystem.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(tint)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.14))
                    )

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(DesignSystem.cardBackground.opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct HomeAttentionRow: View {
    let item: HomeAttentionItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ItemIconBadge(symbol: item.icon, tint: item.tint, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .fill(DesignSystem.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeTimelineRow: View {
    let item: HomeTimelineItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(item.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(item.tint)
                        .textCase(.uppercase)
                    Text(item.date.formatted(.dateTime.day()))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                .frame(width: 48, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.tint.opacity(0.12))
                )

                ItemIconBadge(symbol: item.icon, tint: item.tint, size: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .fill(DesignSystem.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeWorkspaceRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ItemIconBadge(symbol: icon, tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .fill(DesignSystem.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnePlaceHomeView { _ in }
        .environmentObject(AIAssistantManager())
}
