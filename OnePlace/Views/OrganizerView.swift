import SwiftData
import SwiftUI

struct OrganizerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]

    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    @State private var searchText = ""

    private var filteredTasks: [TaskItem] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                taskSection(title: "Today", tasks: todayTasks)
                taskSection(title: "Upcoming", tasks: upcomingTasks)
                taskSection(title: "Completed", tasks: completedTasks)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Organizer")
            .searchable(text: $searchText, prompt: "Search tasks")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                TaskEditor(task: nil) { item in
                    modelContext.insert(item)
                    scheduleReminder(for: item)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditor(task: task) { updatedTask in
                    scheduleReminder(for: updatedTask)
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            LazyVGrid(columns: organizerSummaryColumns, alignment: .leading, spacing: 12) {
                SummaryCard(title: "Today", value: Double(todayTasks.count), subtitle: "Tasks")
                SummaryCard(title: "Upcoming", value: Double(upcomingTasks.count), subtitle: "Tasks")
                SummaryCard(title: "Done", value: Double(completedTasks.count), subtitle: "Tasks")
            }
        }
        .listRowBackground(Color(.systemBackground))
    }

    private func taskSection(title: String, tasks: [TaskItem]) -> some View {
        Section(title) {
            if tasks.isEmpty {
                Text("No tasks")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(task)
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
                                task.completed.toggle()
                                if task.completed {
                                    NotificationManager.shared.cancelReminder(id: task.notificationId)
                                }
                            } label: {
                                Label(task.completed ? "Reopen" : "Complete", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                }
            }
        }
    }

    private var organizerSummaryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
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
        NotificationManager.shared.cancelReminder(id: task.notificationId)
        modelContext.delete(task)
    }

    private func scheduleReminder(for task: TaskItem) {
        NotificationManager.shared.cancelReminder(id: task.notificationId)
        guard task.reminderEnabled, let reminderDate = task.reminderDate else { return }

        let title = "Reminder: \(task.title)"
        let body = task.dueDate != nil ? "Due \(task.dueDate!.formatted(date: .abbreviated, time: .omitted))" : "Task reminder"

        Task {
            await NotificationManager.shared.scheduleReminder(
                id: task.notificationId,
                title: title,
                body: body,
                date: reminderDate,
                repeats: false,
                calendarComponents: nil
            )
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: Double
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15))
        )
    }
}

private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(task.priority.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let dueDate = task.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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

    init(task: TaskItem?, onSave: @escaping (TaskItem) -> Void) {
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
                        .lineLimit(2...4)
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
    OrganizerView()
        .modelContainer(SampleData.makeContainer())
}
