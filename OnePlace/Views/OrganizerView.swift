import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct OrganizerView: View {
    enum OrganizerSegment: String, CaseIterable, Identifiable {
        case today = "Today"
        case upcoming = "Upcoming"
        case done = "Done"

        var id: String { rawValue }
    }

    let ownerUserId: String

    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]

    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    @State private var searchText = ""
    @State private var selectedSegment: OrganizerSegment = .today

    init(ownerUserId: String) {
        self.ownerUserId = ownerUserId
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.ownerUserId == ownerUserId },
            sort: [SortDescriptor(\.dueDate)]
        )
    }

    private var filteredTasks: [TaskItem] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedTasks: [TaskItem] {
        switch selectedSegment {
        case .today:
            return todayTasks
        case .upcoming:
            return upcomingTasks
        case .done:
            return completedTasks
        }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection

                Section {
                    Picker("Filter", selection: $selectedSegment) {
                        ForEach(OrganizerSegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedSegment) { _, _ in
                        triggerLightHaptic()
                    }
                    .padding(.top, 8)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))

                Section {
                    if selectedTasks.isEmpty {
                        compactEmptyState
                            .padding(.vertical, 12)
                    } else {
                        ForEach(selectedTasks) { task in
                            TaskRow(task: task)
                                .frame(minHeight: DesignSystem.rowHeight)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        triggerLightHaptic()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            delete(task)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        editingTask = task
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button {
                                        triggerLightHaptic()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            task.completed.toggle()
                                            if task.completed {
                                                cancelReminder(id: task.notificationId)
                                            }
                                        }
                                    } label: {
                                        Label(task.completed ? "Reopen" : "Complete", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                } header: {
                    Text(selectedSegment.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                        .foregroundStyle(DesignSystem.secondaryTextColor)
                        .padding(.top, 14)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Organizer")
            .searchable(text: $searchText, prompt: "Search tasks")
            .animation(.easeInOut(duration: 0.2), value: selectedSegment)
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                TaskEditor(ownerUserId: ownerUserId, task: nil) { item in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        modelContext.insert(item)
                    }
                    scheduleReminder(for: item)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditor(ownerUserId: ownerUserId, task: task) { updatedTask in
                    scheduleReminder(for: updatedTask)
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    organizerStatCard(title: "Today", value: todayTasks.count, icon: "checkmark.circle", tint: .blue, segment: .today)
                    organizerStatCard(title: "Upcoming", value: upcomingTasks.count, icon: "clock", tint: .purple, segment: .upcoming)
                    organizerStatCard(title: "Done", value: completedTasks.count, icon: "checkmark.seal", tint: .green, segment: .done)
                }
                .padding(.horizontal, 2)
            }
            .padding(.vertical, 2)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 18, trailing: 12))
    }

    private func organizerStatCard(title: String, value: Int, icon: String, tint: Color, segment: OrganizerSegment) -> some View {
        Button {
            selectedSegment = segment
            triggerLightHaptic()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.16))
                            .frame(width: 20, height: 20)
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryTextColor)

                    Spacer(minLength: 0)
                }

                Text(value.formatted())
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 120, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                    .strokeBorder(selectedSegment == segment ? tint.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var compactEmptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DesignSystem.secondaryTextColor)
            Text("No \(selectedSegment.rawValue.lowercased()) tasks")
                .font(.subheadline)
            Text("Add a task to get started.")
                .font(.caption)
                .foregroundStyle(DesignSystem.secondaryTextColor)

            Button("Add") {
                showingAdd = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var todayTasks: [TaskItem] {
        filteredTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate) && !task.completed
        }
    }

    private var upcomingTasks: [TaskItem] {
        filteredTasks.filter { task in
            guard let dueDate = task.dueDate else { return !task.completed }
            return dueDate > Date() && !Calendar.current.isDateInToday(dueDate) && !task.completed
        }
    }

    private var completedTasks: [TaskItem] {
        filteredTasks.filter { $0.completed }
    }

    private func delete(_ task: TaskItem) {
        cancelReminder(id: task.notificationId)
        modelContext.delete(task)
    }

    private func scheduleReminder(for task: TaskItem) {
        cancelReminder(id: task.notificationId)
        guard task.reminderEnabled, let reminderDate = task.reminderDate else { return }

        let title = "Reminder: \(task.title)"
        let body = task.dueDate != nil ? "Due \(task.dueDate!.formatted(date: .abbreviated, time: .omitted))" : "Task reminder"

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: task.notificationId, content: content, trigger: trigger)

        Task {
            do {
                try await center.add(request)
            } catch {
                return
            }
        }
    }

    private func cancelReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func triggerLightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.subheadline)
                    if task.completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryTextColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(task.priority.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryTextColor)
                if let dueDate = task.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.secondaryTextColor)
                }
            }
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.18), value: task.completed)
    }
}

private struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var includeDueDate: Bool
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date

    private let task: TaskItem?
    private let onSave: (TaskItem) -> Void
    private let ownerUserId: String

    init(ownerUserId: String, task: TaskItem?, onSave: @escaping (TaskItem) -> Void) {
        self.ownerUserId = ownerUserId
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _priority = State(initialValue: task?.priority ?? .normal)
        _dueDate = State(initialValue: task?.dueDate ?? Date())
        _includeDueDate = State(initialValue: task?.dueDate != nil)
        _reminderEnabled = State(initialValue: task?.reminderEnabled ?? false)
        _reminderDate = State(initialValue: task?.reminderDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2 ... 4)
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue.capitalized)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Add due date", isOn: $includeDueDate)
                    if includeDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    }
                }

                Section("Reminder") {
                    Toggle("Reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Reminder Time", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let finalReminderDate = reminderEnabled ? reminderDate : nil
                        if let task {
                            task.title = title
                            task.notes = notes.isEmpty ? nil : notes
                            task.priority = priority
                            task.dueDate = includeDueDate ? dueDate : nil
                            task.reminderEnabled = reminderEnabled
                            task.reminderDate = finalReminderDate
                            onSave(task)
                        } else {
                            let item = TaskItem(
                                ownerUserId: ownerUserId,
                                title: title,
                                notes: notes.isEmpty ? nil : notes,
                                priority: priority,
                                dueDate: includeDueDate ? dueDate : nil,
                                reminderEnabled: reminderEnabled,
                                reminderDate: finalReminderDate
                            )
                            onSave(item)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    OrganizerView(ownerUserId: SampleData.previewUserId)
        .modelContainer(SampleData.makeContainer())
        .environmentObject(AuthManager())
}
