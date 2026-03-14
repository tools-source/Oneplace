import SwiftUI

struct OrganizerView: View {
    enum OrganizerSegment: String, CaseIterable, Identifiable {
        case today = "Today"
        case upcoming = "Upcoming"
        case done = "Done"

        var id: String { rawValue }
    }

    @StateObject private var vm = OrganizerViewModel()

    @State private var showingAdd = false
    @State private var editingTask: TaskItemRecord?
    @State private var searchText = ""
    @State private var selectedSegment: OrganizerSegment = .today

    private var filteredTasks: [TaskItemRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.tasks }

        return vm.tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(query) ||
            (task.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var selectedTasks: [TaskItemRecord] {
        switch selectedSegment {
        case .today:
            return todayTasks
        case .upcoming:
            return upcomingTasks
        case .done:
            return completedTasks
        }
    }

    private var todayTasks: [TaskItemRecord] {
        filteredTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate) && !task.completed
        }
    }

    private var upcomingTasks: [TaskItemRecord] {
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return filteredTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfTomorrow && !task.completed
        }
    }

    private var completedTasks: [TaskItemRecord] {
        filteredTasks.filter(\.completed)
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                filterSection
                tasksSection
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: DesignSystem.tabBarContentInset)
            }
            .navigationTitle("Organizer")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search tasks"
            )
            .animation(.easeInOut(duration: 0.2), value: selectedSegment)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                TaskEditorView(task: nil) { draft in
                    Task { await vm.addTask(draft: draft) }
                    showingAdd = false
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorView(task: task) { draft in
                    let updated = TaskItemRecord(
                        id: task.id,
                        ownerUserId: task.ownerUserId,
                        title: draft.title,
                        notes: draft.notes,
                        priority: draft.priority,
                        dueDate: draft.dueDate,
                        completed: draft.completed,
                        reminderEnabled: draft.reminderEnabled,
                        reminderDate: draft.reminderDate
                    )
                    Task { await vm.updateTask(updated) }
                    editingTask = nil
                }
            }
            .alert("Organizer Error", isPresented: organizerErrorBinding) {
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

    private var organizerErrorBinding: Binding<Bool> {
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
                    title: "Today",
                    value: todayTasks.count.formatted(),
                    icon: "calendar",
                    tint: DesignSystem.accentColor
                )
                StatCard(
                    title: "Upcoming",
                    value: upcomingTasks.count.formatted(),
                    icon: "calendar.badge.clock",
                    tint: DesignSystem.warmAccent
                )
                StatCard(
                    title: "Done",
                    value: completedTasks.count.formatted(),
                    icon: "checkmark.circle.fill",
                    tint: DesignSystem.gainColor
                )
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .listRowBackground(Color.clear)
        }
    }

    private var filterSection: some View {
        Section {
            Picker("Show", selection: $selectedSegment) {
                ForEach(OrganizerSegment.allCases) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
        }
    }

    private var tasksSection: some View {
        Section {
            if vm.isLoading && vm.tasks.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
            } else if selectedTasks.isEmpty {
                Text("No tasks.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(selectedTasks) { task in
                    taskRow(for: task)
                        .onTapGesture {
                            editingTask = task
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private func taskRow(for task: TaskItemRecord) -> some View {
        AppCard {
            HStack(spacing: 12) {
                ItemIconBadge(symbol: taskIcon(for: task), tint: taskTint(for: task))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.completed)

                    Text(taskSubtitle(for: task))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(task.completed ? "Done" : task.priority.rawValue.capitalized)
                        .font(.headline)
                        .foregroundStyle(taskTint(for: task))

                    if let dueDate = task.dueDate, !task.completed {
                        Text(shortRelativeLabel(for: dueDate))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(task.completed ? 0.62 : 1)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await vm.toggleCompletion(for: task) }
            } label: {
                Label(task.completed ? "Undo" : "Complete",
                      systemImage: task.completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(DesignSystem.gainColor)
        }
        .swipeActions(edge: .trailing) {
            Button {
                editingTask = task
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(DesignSystem.accentColor)

            Button(role: .destructive) {
                Task { await vm.deleteTask(task) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func taskSubtitle(for task: TaskItemRecord) -> String {
        var parts: [String] = []

        if let dueDate = task.dueDate {
            parts.append(dueDate.formatted(date: .abbreviated, time: .omitted))
        } else {
            parts.append("No due date")
        }

        if let notes = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            parts.append(notes)
        }

        return parts.joined(separator: " • ")
    }

    private func shortRelativeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func taskIcon(for task: TaskItemRecord) -> String {
        if task.completed {
            return "checkmark.circle.fill"
        }

        switch task.priority {
        case .high:
            return "exclamationmark.circle.fill"
        case .normal:
            return "calendar"
        case .low:
            return "circle.fill"
        }
    }

    private func taskTint(for task: TaskItemRecord) -> Color {
        if task.completed {
            return DesignSystem.gainColor
        }

        switch task.priority {
        case .high:
            return DesignSystem.warmAccent
        case .normal:
            return DesignSystem.accentColor
        case .low:
            return DesignSystem.secondaryTextColor
        }
    }
}

private struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date

    private let task: TaskItemRecord?
    private let onSave: (TaskItemDraft) -> Void

    init(task: TaskItemRecord?, onSave: @escaping (TaskItemDraft) -> Void) {
        self.task = task
        self.onSave = onSave

        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _priority = State(initialValue: task?.priority ?? .normal)
        _dueDate = State(initialValue: task?.dueDate ?? Date())
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _reminderEnabled = State(initialValue: task?.reminderEnabled ?? false)
        _reminderDate = State(initialValue: task?.reminderDate ?? task?.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Task title", text: $title)
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue.capitalized).tag(priority)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Add due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Reminder") {
                    Toggle("Reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: $reminderDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let draft = TaskItemDraft(
                            title: title,
                            notes: notes.isEmpty ? nil : notes,
                            priority: priority,
                            dueDate: hasDueDate ? dueDate : nil,
                            completed: task?.completed ?? false,
                            reminderEnabled: reminderEnabled,
                            reminderDate: reminderEnabled ? reminderDate : nil
                        )
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
