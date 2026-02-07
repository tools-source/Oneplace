import SwiftData
import SwiftUI

struct OrganizerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                taskSection(title: "Today", tasks: todayTasks)
                taskSection(title: "Upcoming", tasks: upcomingTasks)
                taskSection(title: "Completed", tasks: completedTasks)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Organizer")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                TaskEditor { item in
                    modelContext.insert(item)
                }
            }
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
                                modelContext.delete(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                task.completed.toggle()
                            } label: {
                                Label(task.completed ? "Reopen" : "Complete", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                }
            }
        }
    }

    private var todayTasks: [TaskItem] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate) && !task.completed
        }
    }

    private var upcomingTasks: [TaskItem] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return !task.completed }
            return dueDate > Date() && !Calendar.current.isDateInToday(dueDate) && !task.completed
        }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter { $0.completed }
    }
}

private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
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
    }
}

private struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var priority: TaskPriority = .normal
    @State private var dueDate = Date()
    @State private var includeDueDate = false

    let onSave: (TaskItem) -> Void

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
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let item = TaskItem(title: title, notes: notes.isEmpty ? nil : notes, priority: priority, dueDate: includeDueDate ? dueDate : nil)
                        onSave(item)
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
