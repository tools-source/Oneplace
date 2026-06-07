import SwiftUI

struct OrganizerView: View {
    enum OrganizerSegment: String, CaseIterable, Identifiable {
        case today = "Today"
        case upcoming = "Upcoming"
        case done = "Done"

        var id: String { rawValue }
    }

    @StateObject private var vm = OrganizerViewModel()
    @EnvironmentObject private var aiAssistant: AIAssistantManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingAdd = false
    @State private var editingTask: TaskItemRecord?
    @State private var searchText = ""
    @State private var lastRefreshToken: UUID?
    @State private var showingClearDoneConfirm = false
    @State private var selectedSegment: OrganizerSegment = {
        let saved = UserDefaults.standard.string(forKey: "tasks.selectedSegment") ?? ""
        return OrganizerSegment(rawValue: saved) ?? .today
    }()

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
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return filteredTasks.filter { task in
            guard !task.completed else { return false }
            // No due date, due today, or overdue all belong here so nothing falls through the cracks.
            guard let dueDate = task.dueDate else { return true }
            return dueDate < startOfTomorrow
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

    private var allCompletedTasks: [TaskItemRecord] {
        vm.tasks.filter(\.completed)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OnePlaceAISearchBar(
                        text: $searchText,
                        placeholder: "Search or ask OnePlace",
                        isProcessing: vm.isLoading,
                        onSubmit: handleSearchSubmit
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
                }

                summarySection
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
            .navigationTitle("Tasks")
            .animation(.easeInOut(duration: 0.2), value: selectedSegment)
            .onChange(of: selectedSegment) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "tasks.selectedSegment")
            }
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
                    Task {
                        await vm.addTask(draft: draft)
                        showingAdd = false
                    }
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
                        reminderDate: draft.reminderDate,
                        reminderRepeat: draft.reminderRepeat,
                        remindersID: task.remindersID
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
            .alert("Clear Done Tasks?", isPresented: $showingClearDoneConfirm) {
                Button("Clear All", role: .destructive) {
                    Task { await vm.clearCompletedTasks() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every completed task from OnePlace and synced Reminders.")
            }
            .task {
                await vm.refresh()
            }
            .onChange(of: aiAssistant.pendingActionsToken) { _, newToken in
                guard lastRefreshToken != newToken else { return }
                lastRefreshToken = newToken
                Task { await vm.refresh() }
            }
            .onChange(of: scenePhase) { _, newValue in
                guard newValue == .active else { return }
                Task { await vm.refresh() }
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
                Button {
                    withAnimation { selectedSegment = .today }
                } label: {
                    StatCard(
                        title: "Today",
                        value: todayTasks.count.formatted(),
                        icon: "calendar",
                        tint: DesignSystem.accentColor,
                        isSelected: selectedSegment == .today
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation { selectedSegment = .upcoming }
                } label: {
                    StatCard(
                        title: "Upcoming",
                        value: upcomingTasks.count.formatted(),
                        icon: "calendar.badge.clock",
                        tint: DesignSystem.warmAccent,
                        isSelected: selectedSegment == .upcoming
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation { selectedSegment = .done }
                } label: {
                    StatCard(
                        title: "Done",
                        value: completedTasks.count.formatted(),
                        icon: "checkmark.circle.fill",
                        tint: DesignSystem.gainColor,
                        isSelected: selectedSegment == .done
                    )
                }
                .buttonStyle(.plain)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            .listRowBackground(Color.clear)
        }
    }

    private var tasksSection: some View {
        Section {
            if selectedSegment == .done && !allCompletedTasks.isEmpty {
                doneSectionActions
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if vm.isLoading && vm.tasks.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
            } else if selectedTasks.isEmpty {
                EmptyState(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: emptySystemImage,
                    ctaTitle: "Add Task"
                ) {
                    showingAdd = true
                }
                .padding(.vertical, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
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

    private var doneSectionActions: some View {
        HStack {
            Label("\(allCompletedTasks.count) completed", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                showingClearDoneConfirm = true
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

    private var emptyTitle: String {
        let hasSearch = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasSearch { return "No matching tasks" }

        switch selectedSegment {
        case .today: return "Nothing for today"
        case .upcoming: return "No upcoming tasks"
        case .done: return "No completed tasks"
        }
    }

    private var emptyMessage: String {
        switch selectedSegment {
        case .today:
            return "Tasks without due dates will appear here with anything due today."
        case .upcoming:
            return "Tasks with future due dates will appear here."
        case .done:
            return "Completed tasks will appear here."
        }
    }

    private var emptySystemImage: String {
        switch selectedSegment {
        case .today: return "calendar"
        case .upcoming: return "checklist"
        case .done: return "checkmark.circle"
        }
    }

    private func handleSearchSubmit(wasVoice: Bool) {
        let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              OnePlacePromptClassifier.isCommand(prompt, in: .organizer) else {
            if wasVoice {
                aiAssistant.openVoiceMode(area: .organizer)
            }
            return
        }

        if wasVoice {
            aiAssistant.openVoiceMode(area: .organizer)
        } else {
            aiAssistant.openChatFresh(area: .organizer, voice: false)
        }
        aiAssistant.userSaid(prompt)
        searchText = ""

        Task {
            await AIChatResponder.handleUserInput(text: prompt, assistant: aiAssistant)
            await vm.refresh()
            selectedSegment = .today
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

enum OrganizerPromptInterpreter {
    static func interpret(_ prompt: String, now: Date = .now) -> TaskItemDraft {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let today = Calendar.current.startOfDay(for: now)
        let dueDate = extractDate(from: trimmed, lowered: lowered, now: now) ?? today
        let reminderDate = lowered.contains("remind") ? dueDate : nil

        return TaskItemDraft(
            title: title(from: trimmed),
            notes: nil,
            priority: priority(from: lowered),
            dueDate: dueDate,
            completed: false,
            reminderEnabled: reminderDate != nil,
            reminderDate: reminderDate
        )
    }

    private static func priority(from prompt: String) -> TaskPriority {
        if ["urgent", "asap", "important", "high priority"].contains(where: prompt.contains) {
            return .high
        }

        if ["low priority", "someday", "later"].contains(where: prompt.contains) {
            return .low
        }

        return .normal
    }

    private static func extractDate(from prompt: String, lowered: String, now: Date) -> Date? {
        let calendar = Calendar.autoupdatingCurrent

        if lowered.contains("today") {
            return now
        }

        if lowered.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }

        if lowered.contains("next week") {
            return calendar.date(byAdding: .day, value: 7, to: now)
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        return detector?.matches(in: prompt, range: range).first?.date
    }

    private static func title(from prompt: String) -> String {
        var value = prompt
            .replacingOccurrences(of: #"(?i)\b(remind me to|add a task to|add task to|add todo to|add|create|make|task|todo|to do|remind|today|tomorrow|next week|urgent|asap|important|high priority|low priority|please)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^A-Za-z0-9'&\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if value.isEmpty {
            value = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return value.isEmpty ? "New Task" : value
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
    @State private var reminderRepeat: ReminderRepeat

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
        _reminderRepeat = State(initialValue: task?.reminderRepeat ?? .oneTime)
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
                    Toggle("Send notification reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker(
                            "Remind Me",
                            selection: $reminderDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        Picker("Repeat", selection: $reminderRepeat) {
                            ForEach(ReminderRepeat.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
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
                            reminderDate: reminderEnabled ? reminderDate : nil,
                            reminderRepeat: reminderEnabled ? reminderRepeat : .oneTime
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
