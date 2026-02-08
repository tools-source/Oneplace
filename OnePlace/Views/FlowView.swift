import SwiftData
import SwiftUI

struct FlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlowItem.nextDueDate) private var items: [FlowItem]

    @State private var showingAdd = false
    @State private var editingItem: FlowItem?
    @State private var searchText = ""

    private var filteredItems: [FlowItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                upcomingSection
                paidSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Flow")
            .searchable(text: $searchText, prompt: "Search bills")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                FlowItemEditor(item: nil) { item in
                    modelContext.insert(item)
                    scheduleReminder(for: item)
                }
            }
            .sheet(item: $editingItem) { item in
                FlowItemEditor(item: item) { updatedItem in
                    scheduleReminder(for: updatedItem)
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                SummaryCard(title: "Upcoming", value: Double(upcomingItems.count), subtitle: "Bills")
                SummaryCard(title: "Due Soon", value: upcomingAmount, subtitle: "Total")
            }
        }
        .listRowBackground(Color(.systemBackground))
    }

    private var upcomingSection: some View {
        Section("Upcoming") {
            if upcomingItems.isEmpty {
                EmptyState(
                    title: "No upcoming bills",
                    message: "Add bills or income to stay ahead of your flow.",
                    systemImage: "calendar",
                    ctaTitle: "Add Bill"
                ) {
                    showingAdd = true
                }
                .listRowBackground(Color(.systemBackground))
            } else {
                ForEach(upcomingItems) { item in
                    FlowRow(item: item)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingItem = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                            Button {
                                item.status = .paid
                                NotificationManager.shared.cancelReminder(id: item.notificationId)
                            } label: {
                                Label("Mark Paid", systemImage: "checkmark.seal")
                            }
                            .tint(.green)
                        }
                }
            }
        }
    }

    private var paidSection: some View {
        Section("Paid") {
            if paidItems.isEmpty {
                Text("No paid bills yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(paidItems) { item in
                    FlowRow(item: item)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingItem = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                            Button {
                                item.status = .upcoming
                            } label: {
                                Label("Mark Upcoming", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
    }

    private var upcomingItems: [FlowItem] {
        filteredItems.filter { $0.status != .paid }
    }

    private var paidItems: [FlowItem] {
        filteredItems.filter { $0.status == .paid }
    }

    private var upcomingAmount: Double {
        upcomingItems.map(\.amount).reduce(0, +)
    }

    private func delete(_ item: FlowItem) {
        NotificationManager.shared.cancelReminder(id: item.notificationId)
        modelContext.delete(item)
    }

    private func scheduleReminder(for item: FlowItem) {
        NotificationManager.shared.cancelReminder(id: item.notificationId)
        guard item.reminderEnabled, let reminderDate = item.reminderDate else { return }

        let formattedAmount = item.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        let title = "Bill due soon: \(item.title)"
        let body = "Amount: \(formattedAmount)"
        let (repeats, components) = repeatComponents(for: item, baseDate: reminderDate)

        Task {
            await NotificationManager.shared.scheduleReminder(
                id: item.notificationId,
                title: title,
                body: body,
                date: reminderDate,
                repeats: repeats,
                calendarComponents: components
            )
        }
    }

    private func repeatComponents(for item: FlowItem, baseDate: Date) -> (Bool, Set<Calendar.Component>?) {
        switch item.reminderRepeat {
        case .none:
            return (false, nil)
        case .daily:
            let components: Set<Calendar.Component> = [.hour, .minute]
            return (true, components)
        case .weekly:
            let components: Set<Calendar.Component> = [.weekday, .hour, .minute]
            return (true, components)
        case .monthly:
            let components: Set<Calendar.Component> = [.day, .hour, .minute]
            return (true, components)
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: Double
    let subtitle: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value, format: .number)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FlowRow: View {
    let item: FlowItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                Text("\(item.frequency.rawValue.capitalized) · \(item.status.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline)
                    .foregroundStyle(item.type == .income ? .green : .orange)
                Text(item.nextDueDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FlowItemEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var amount: Double
    @State private var type: FlowType
    @State private var frequency: FlowFrequency
    @State private var nextDueDate: Date
    @State private var status: FlowStatus
    @State private var notes: String
    @State private var reminderEnabled: Bool
    @State private var reminderOffsetDays: Int
    @State private var reminderRepeat: ReminderRepeatRule
    @State private var reminderTime: Date

    private let item: FlowItem?
    private let onSave: (FlowItem) -> Void

    init(item: FlowItem?, onSave: @escaping (FlowItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _amount = State(initialValue: item?.amount ?? 0)
        _type = State(initialValue: item?.type ?? .bill)
        _frequency = State(initialValue: item?.frequency ?? .monthly)
        _nextDueDate = State(initialValue: item?.nextDueDate ?? Date())
        _status = State(initialValue: item?.status ?? .upcoming)
        _notes = State(initialValue: item?.notes ?? "")
        _reminderEnabled = State(initialValue: item?.reminderEnabled ?? false)
        _reminderOffsetDays = State(initialValue: item?.reminderOffsetDays ?? 0)
        _reminderRepeat = State(initialValue: item?.reminderRepeat ?? .none)
        _reminderTime = State(initialValue: FlowItemEditor.timeFromComponents(item?.reminderTime) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .number)
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

                Section("Reminder") {
                    Toggle("Reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Picker("Repeat", selection: $reminderRepeat) {
                            ForEach(ReminderRepeatRule.allCases, id: \.self) { rule in
                                Text(rule.rawValue.capitalized).tag(rule)
                            }
                        }
                        Picker("Remind me", selection: $reminderOffsetDays) {
                            Text("Same day").tag(0)
                            Text("1 day before").tag(1)
                            Text("2 days before").tag(2)
                            Text("3 days before").tag(3)
                            Text("1 week before").tag(7)
                        }
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(item == nil ? "New Flow Item" : "Edit Flow Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let reminderDate = computedReminderDate()
                        let reminderTimeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                        if let item {
                            item.title = title
                            item.amount = amount
                            item.type = type
                            item.frequency = frequency
                            item.nextDueDate = nextDueDate
                            item.status = status
                            item.notes = notes.isEmpty ? nil : notes
                            item.reminderEnabled = reminderEnabled
                            item.reminderDate = reminderDate
                            item.reminderTime = reminderEnabled ? reminderTimeComponents : nil
                            item.reminderRepeat = reminderRepeat
                            item.reminderOffsetDays = reminderOffsetDays
                            onSave(item)
                        } else {
                            let newItem = FlowItem(
                                title: title,
                                amount: amount,
                                type: type,
                                frequency: frequency,
                                nextDueDate: nextDueDate,
                                status: status,
                                notes: notes.isEmpty ? nil : notes,
                                reminderEnabled: reminderEnabled,
                                reminderDate: reminderDate,
                                reminderTime: reminderEnabled ? reminderTimeComponents : nil,
                                reminderRepeat: reminderRepeat,
                                reminderOffsetDays: reminderOffsetDays
                            )
                            onSave(newItem)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func computedReminderDate() -> Date? {
        guard reminderEnabled else { return nil }
        let calendar = Calendar.current
        let dueDate = calendar.date(byAdding: .day, value: -reminderOffsetDays, to: nextDueDate) ?? nextDueDate
        let time = calendar.dateComponents([.hour, .minute], from: reminderTime)
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }

    private static func timeFromComponents(_ components: DateComponents?) -> Date? {
        guard let components else { return nil }
        var merged = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        merged.hour = components.hour
        merged.minute = components.minute
        return Calendar.current.date(from: merged)
    }
}

#Preview {
    FlowView()
        .modelContainer(SampleData.makeContainer())
}
