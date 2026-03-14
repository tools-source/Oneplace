import SwiftUI
import UserNotifications

struct FlowView: View {
    @StateObject private var vm = FlowViewModel()

    @State private var showingAdd = false
    @State private var editingItem: FlowItemRecord?
    @State private var searchText = ""

    private var filteredItems: [FlowItemRecord] {
        guard !searchText.isEmpty else { return vm.items }
        return vm.items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var upcomingItems: [FlowItemRecord] {
        filteredItems.filter { $0.status == .upcoming }
    }

    private var paidItems: [FlowItemRecord] {
        filteredItems.filter { $0.status == .paid }
    }

    private var upcomingAmount: Double {
        upcomingItems.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                upcomingSection
                paidSection
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: DesignSystem.tabBarContentInset)
            }
            .navigationTitle("Flow")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search bills"
            )
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                FlowItemEditorView(item: nil) { draft in
                    Task { await vm.addItem(draft: draft) }
                    showingAdd = false
                }
            }
            .sheet(item: $editingItem) { item in
                FlowItemEditorView(item: item) { draft in
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
                    Task { await vm.updateItem(updated) }
                    editingItem = nil
                }
            }
            .alert("Flow Error", isPresented: flowErrorBinding) {
                Button("OK", role: .cancel) {
                    vm.errorMessage = nil
                }
            } message: {
                Text(vm.errorMessage ?? "Please try again.")
            }
            .task {
                await vm.refresh()
            }
        }
    }

    private var flowErrorBinding: Binding<Bool> {
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
                    title: "Upcoming",
                    value: upcomingItems.count.formatted(),
                    icon: "calendar",
                    tint: DesignSystem.accentColor
                )
                StatCard(
                    title: "Due Soon",
                    value: StatCard.currencyString(for: upcomingAmount),
                    icon: "exclamationmark.circle",
                    tint: DesignSystem.warmAccent
                )
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .listRowBackground(Color.clear)
        }
    }

    private var upcomingSection: some View {
        Section("Upcoming") {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
            } else if upcomingItems.isEmpty {
                Text("No upcoming bills.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(upcomingItems) { item in
                    flowItemRow(for: item)
                        .onTapGesture {
                            editingItem = item
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var paidSection: some View {
        Section("Paid") {
            if paidItems.isEmpty {
                Text("No paid bills.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(paidItems) { item in
                    flowItemRow(for: item)
                        .onTapGesture {
                            editingItem = item
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
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
                editingItem = item
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
}

private struct FlowItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

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
    private let onSave: (FlowItemDraft) -> Void

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    init(item: FlowItemRecord?, onSave: @escaping (FlowItemDraft) -> Void) {
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
            .navigationTitle(item == nil ? "New Bill" : "Edit Bill")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let amountValue = parsedAmount, amountValue > 0 else { return }
                        let reminderComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)

                        let draft = FlowItemDraft(
                            title: title,
                            amount: amountValue,
                            type: type,
                            frequency: frequency,
                            nextDueDate: nextDueDate,
                            status: status,
                            notes: notes.isEmpty ? nil : notes,
                            reminderEnabled: reminderEnabled,
                            reminderDate: reminderEnabled ? reminderDate : nil,
                            reminderHour: reminderEnabled ? reminderComponents.hour : nil,
                            reminderMinute: reminderEnabled ? reminderComponents.minute : nil,
                            reminderRepeat: reminderEnabled ? reminderRepeat : .none,
                            reminderOffsetDays: 0
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
        let cleaned = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private var isSaveDisabled: Bool {
        guard let amountValue = parsedAmount, amountValue > 0 else { return true }
        return title.isEmpty
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
