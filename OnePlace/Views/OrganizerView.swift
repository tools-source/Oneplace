import SwiftData
import SwiftUI
import UserNotifications

struct OrganizerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]

    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    @State private var searchText = ""
    @State private var summaryWidth: CGFloat = 0

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
            LazyVGrid(columns: organizerSummaryColumns(for: summaryWidth), alignment: .leading, spacing: 12) {
                StatCard(
                    title: "Today",
                    value: todayTasks.count.formatted(),
                    subtitle: "Tasks",
                    icon: "checkmark.circle",
                    tint: .blue
                )
                StatCard(
                    title: "Upcoming",
                    value: upcomingTasks.count.formatted(),
                    subtitle: "Tasks",
                    icon: "clock",
                    tint: .purple
                )
                StatCard(
                    title: "Done",
                    value: completedTasks.count.formatted(),
                    subtitle: "Tasks",
                    icon: "checkmark.seal",
                    tint: .green
                )
            }
            .padding(.horizontal, 16)
            .background(WidthReader())
        }
        .listRowBackground(Color(.systemBackground))
        .onPreferenceChange(WidthPreferenceKey.self) { newWidth in
            summaryWidth = newWidth
        }
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
                                    cancelReminder(id: task.notificationId)
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

    private func organizerSummaryColumns(for width: CGFloat) -> [GridItem] {
        let useTwoColumns = width > 0 && width < 360
        let columnCount = useTwoColumns ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
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
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: WidthPreferenceKey.self, value: proxy.size.width)
        }
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
