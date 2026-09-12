import SwiftUI
import UIKit

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
    @Environment(\.editMode) private var editMode

    @State private var editingTask: ItemEditorDestination<TaskItemRecord>?
    @State private var inlineTaskText = ""
    @State private var inlineTaskError: String?
    @State private var inlineTaskDueDate: Date? = nil
    @State private var inlineTaskPriority: TaskPriority = .normal
    @State private var searchText = ""
    @State private var lastRefreshToken: UUID?
    @State private var showingClearDoneConfirm = false
    @State private var completingTaskIDs: Set<String> = []
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

    private var taskPriorityGroups: [TaskPriorityGroup] {
        [TaskPriority.high, .normal, .low].compactMap { priority in
            let tasks = selectedTasks.filter { $0.priority == priority }
            return tasks.isEmpty ? nil : TaskPriorityGroup(priority: priority, tasks: tasks)
        }
    }

    private var isEditingTasks: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    private var canReorderTasks: Bool {
        selectedSegment != .done &&
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vm.isLoading
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
                    organizerPulseCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                summarySection
                tasksSection
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
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks and notes")
            .refreshable { await vm.refresh() }
            .animation(.easeInOut(duration: 0.2), value: selectedSegment)
            .onChange(of: selectedSegment) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "tasks.selectedSegment")
                if isEditingTasks {
                    editMode?.wrappedValue = .inactive
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                        .disabled(!canReorderTasks || selectedTasks.isEmpty)
                }
            }
            .sheet(item: $editingTask) { destination in
                TaskEditorView(task: destination.item) { draft in
                    if let task = destination.item {
                        let updated = TaskItemRecord(
                            id: task.id,
                            ownerUserId: task.ownerUserId,
                            title: draft.title,
                            notes: draft.notes,
                            priority: draft.priority,
                            manualOrder: task.priority == draft.priority ? task.manualOrder : nil,
                            dueDate: draft.dueDate,
                            completed: draft.completed,
                            reminderEnabled: draft.reminderEnabled,
                            reminderDate: draft.reminderDate,
                            reminderRepeat: draft.reminderRepeat,
                            remindersID: task.remindersID
                        )
                        await vm.updateTask(updated)
                    } else {
                        await vm.addTask(draft: draft)
                    }
                    let error = vm.errorMessage
                    if error == nil, destination.item == nil {
                        searchText = ""
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
                        selectedSegment = (draft.dueDate.map { $0 >= tomorrow } ?? false) ? .upcoming : .today
                    }
                    vm.errorMessage = nil
                    return error
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
            get: { vm.errorMessage != nil && editingTask == nil },
            set: { isPresented in
                if !isPresented {
                    vm.errorMessage = nil
                }
            }
        )
    }

    private var highPriorityTodayCount: Int {
        todayTasks.filter { $0.priority == .high }.count
    }

    private var organizerPulseCard: some View {
        WorkspacePulseCard(
            title: "Task Focus",
            subtitle: organizerPulseSubtitle,
            icon: highPriorityTodayCount > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
            tint: highPriorityTodayCount > 0 ? DesignSystem.oweColor : DesignSystem.accentColor,
            primaryValue: "\(todayTasks.count)",
            primaryLabel: "today",
            secondaryValue: "\(highPriorityTodayCount)",
            secondaryLabel: "high priority",
            actionTitle: selectedSegment == .upcoming ? "Today" : "Upcoming"
        ) {
            withAnimation {
                selectedSegment = selectedSegment == .upcoming ? .today : .upcoming
            }
        }
    }

    private var organizerPulseSubtitle: String {
        if todayTasks.isEmpty && upcomingTasks.isEmpty {
            return "Your task list is quiet. Add the next thing when it appears."
        }

        if highPriorityTodayCount > 0 {
            return "\(highPriorityTodayCount) high-priority task\(highPriorityTodayCount == 1 ? "" : "s") need attention today."
        }

        if let next = upcomingTasks.first, let dueDate = next.dueDate {
            return "Next scheduled task: \(next.title), due \(dueDate.formatted(date: .abbreviated, time: .omitted))."
        }

        return "\(todayTasks.count) open task\(todayTasks.count == 1 ? "" : "s") are in today's lane."
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
        Group {
            if selectedSegment == .done && !allCompletedTasks.isEmpty {
                Section {
                    doneSectionActions
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            if vm.isLoading && vm.tasks.isEmpty {
                Section {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    inlineTaskAddRow
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if selectedTasks.isEmpty {
                Section {
                    EmptyState(
                        title: emptyTitle,
                        message: emptyMessage,
                        systemImage: emptySystemImage,
                        ctaTitle: nil
                    )
                    .padding(.vertical, 10)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                } else {
                    ForEach(taskPriorityGroups) { group in
                        Section {
                            ForEach(group.tasks) { task in
                                taskRow(for: task)
                                    .onTapGesture {
                                        editingTask = .edit(task)
                                    }
                                    .moveDisabled(!canReorderTasks)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            .onMove { source, destination in
                                moveTasks(from: source, to: destination, in: group)
                            }
                        } header: {
                            priorityHeader(for: group)
                        }
                    }
                }
            }
        }
    }

    private var inlineTaskAddRow: some View {
        InlineAddItemRow(
            text: $inlineTaskText,
            placeholder: "New task",
            systemImage: "plus.circle.fill",
            tint: DesignSystem.accentColor,
            isSaving: vm.isLoading,
            validationMessage: inlineTaskError,
            onSubmit: saveInlineTask,
            onCancel: cancelInlineTaskAdd
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    InlineAddHelperButton(title: "Today", systemImage: "calendar", tint: DesignSystem.accentColor, isSelected: inlineTaskDueDate.map(Calendar.current.isDateInToday) == true) {
                        inlineTaskDueDate = .now
                    }
                    InlineAddHelperButton(title: "Tomorrow", systemImage: "calendar.badge.clock", tint: DesignSystem.warmAccent, isSelected: inlineTaskDueDate.map(Calendar.current.isDateInTomorrow) == true) {
                        inlineTaskDueDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)
                    }
                    InlineAddHelperButton(title: "No due date", systemImage: "calendar.badge.minus", tint: DesignSystem.secondaryTextColor, isSelected: inlineTaskDueDate == nil) {
                        inlineTaskDueDate = nil
                    }
                    InlineAddHelperMenu(title: "Priority", systemImage: priorityHeaderIcon(for: inlineTaskPriority), tint: priorityTint(for: inlineTaskPriority), isSelected: inlineTaskPriority != .normal) {
                        ForEach([TaskPriority.high, .normal, .low], id: \.self) { priority in
                            Button(priority.displayName) { inlineTaskPriority = priority }
                        }
                    }
                }
                .padding(.leading, 40)
            }
        }
    }

    private func priorityHeader(for group: TaskPriorityGroup) -> some View {
        HStack {
            Label(group.priority.displayName, systemImage: priorityHeaderIcon(for: group.priority))
                .font(.caption.weight(.semibold))
                .foregroundStyle(priorityTint(for: group.priority))
            Spacer()
            Text(group.tasks.count.formatted())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.horizontal, 4)
    }

    private func moveTasks(from source: IndexSet, to destination: Int, in group: TaskPriorityGroup) {
        guard canReorderTasks else { return }

        var reorderedTasks = group.tasks
        reorderedTasks.move(fromOffsets: source, toOffset: destination)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            await vm.reorderTasks(reorderedTasks)
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
        let isCompleting = completingTaskIDs.contains(task.id)

        AppCard {
            HStack(spacing: 12) {
                Button {
                    completeTaskWithMotion(task)
                } label: {
                    completionControl(for: task, isCompleting: isCompleting)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.completed ? "Mark task incomplete" : "Mark task complete")

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
                    Image(systemName: task.completed ? "checkmark.circle.fill" : priorityHeaderIcon(for: task.priority))
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(taskTint(for: task))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(taskTint(for: task).opacity(0.14))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(taskTint(for: task).opacity(0.22), lineWidth: 1)
                        )
                        .accessibilityLabel(task.completed ? "Done" : "\(task.priority.displayName) priority")

                    if let dueDate = task.dueDate, !task.completed {
                        Text(shortRelativeLabel(for: dueDate))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(task.completed ? 0.62 : 1)
        }
        .scaleEffect(isCompleting ? 0.94 : 1)
        .offset(x: isCompleting ? 36 : 0)
        .opacity(isCompleting ? 0.18 : 1)
        .animation(.easeInOut(duration: 0.48), value: isCompleting)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                completeTaskWithMotion(task)
            } label: {
                Label(task.completed ? "Undo" : "Complete",
                      systemImage: task.completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(DesignSystem.gainColor)
        }
        .swipeActions(edge: .trailing) {
            Button {
                editingTask = .edit(task)
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
        .contextMenu {
            ForEach([TaskPriority.high, .normal, .low], id: \.self) { priority in
                Button {
                    updatePriority(priority, for: task)
                } label: {
                    Label(priority.displayName, systemImage: priorityHeaderIcon(for: priority))
                }
            }
        }
    }

    private func completionControl(for task: TaskItemRecord, isCompleting: Bool) -> some View {
        AnimatedCompletionControl(
            isCompleted: task.completed || isCompleting,
            tint: isCompleting ? DesignSystem.gainColor : taskTint(for: task)
        )
    }

    private func completeTaskWithMotion(_ task: TaskItemRecord) {
        guard !completingTaskIDs.contains(task.id) else { return }

        if task.completed {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            Task { await vm.toggleCompletion(for: task) }
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.48)) {
            _ = completingTaskIDs.insert(task.id)
        }

        Task {
            try? await Task.sleep(nanoseconds: 520_000_000)
            await vm.toggleCompletion(for: task)
            await MainActor.run {
                _ = completingTaskIDs.remove(task.id)
            }
        }
    }

    private func updatePriority(_ priority: TaskPriority, for task: TaskItemRecord) {
        guard task.priority != priority else { return }

        var updated = task
        updated.priority = priority
        updated.manualOrder = nil
        Task { await vm.updateTask(updated) }
    }

    private func cancelInlineTaskAdd() {
        inlineTaskText = ""
        inlineTaskError = nil
    }

    private func saveInlineTask() {
        let prompt = inlineTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        var draft = OrganizerPromptInterpreter.interpret(prompt)
        if let inlineTaskDueDate {
            draft.dueDate = inlineTaskDueDate
        } else if !OrganizerPromptInterpreter.promptHasDate(prompt) {
            draft.dueDate = nil
            draft.reminderEnabled = false
            draft.reminderDate = nil
        }
        draft.priority = inlineTaskPriority

        Task {
            await vm.addTask(draft: draft)
            guard vm.errorMessage == nil else {
                inlineTaskError = vm.errorMessage
                return
            }

            await MainActor.run {
                searchText = ""
                inlineTaskText = ""
                inlineTaskError = nil
                inlineTaskDueDate = nil
                inlineTaskPriority = .normal
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
                selectedSegment = (draft.dueDate.map { $0 >= tomorrow } ?? false) ? .upcoming : .today
                UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        guard !prompt.isEmpty else { return }

        guard shouldRouteToAssistant(prompt) else {
            Task {
                var draft = OrganizerPromptInterpreter.interpret(prompt)
                if !OrganizerPromptInterpreter.promptHasDate(prompt) {
                    draft.dueDate = nil
                    draft.reminderEnabled = false
                    draft.reminderDate = nil
                }

                await vm.addTask(draft: draft)
                guard vm.errorMessage == nil else { return }

                searchText = ""
                selectedSegment = .today
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        aiAssistant.openChatFresh(area: .organizer, voice: wasVoice)
        aiAssistant.userSaid(prompt)
        searchText = ""

        Task {
            await AIChatResponder.handleUserInput(text: prompt, assistant: aiAssistant)
            await vm.refresh()
            selectedSegment = .today
        }
    }

    private func shouldRouteToAssistant(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return [
            "delete", "remove", "erase", "complete", "mark done", "finished",
            "finish ", "reopen", "undo", "not done"
        ].contains { lowered.contains($0) }
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

    private func priorityHeaderIcon(for priority: TaskPriority) -> String {
        switch priority {
        case .high:
            return "exclamationmark.circle.fill"
        case .normal:
            return "circle.grid.2x2.fill"
        case .low:
            return "arrow.down.circle.fill"
        }
    }

    private func priorityTint(for priority: TaskPriority) -> Color {
        switch priority {
        case .high:
            return DesignSystem.oweColor
        case .normal:
            return DesignSystem.accentColor
        case .low:
            return DesignSystem.secondaryTextColor
        }
    }

    private func taskTint(for task: TaskItemRecord) -> Color {
        if task.completed {
            return DesignSystem.gainColor
        }

        return priorityTint(for: task.priority)
    }
}

private struct TaskPriorityGroup: Identifiable {
    let priority: TaskPriority
    let tasks: [TaskItemRecord]

    var id: TaskPriority { priority }
}

private struct AnimatedCompletionControl: View {
    let isCompleted: Bool
    let tint: Color

    @State private var fillScale: CGFloat = 0.1
    @State private var checkProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.08))

            Circle()
                .fill(tint)
                .scaleEffect(fillScale)
                .opacity(isCompleted ? 1 : 0)

            Circle()
                .stroke(tint.opacity(isCompleted ? 0 : 0.5), lineWidth: 2)

            if isCompleted || checkProgress > 0 {
                AnimatedCheckmark()
                    .trim(from: 0, to: checkProgress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 16, height: 12)
                    .scaleEffect(isCompleted ? 1 : 0.86)
            }
        }
        .frame(width: 32, height: 32)
        .frame(width: 36, height: 36)
        .onAppear {
            fillScale = isCompleted ? 1 : 0.1
            checkProgress = isCompleted ? 1 : 0
        }
        .onChange(of: isCompleted) { _, completed in
            if completed {
                fillScale = 0.62
                checkProgress = 0

                withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
                    fillScale = 1
                }

                withAnimation(.easeOut(duration: 0.22).delay(0.07)) {
                    checkProgress = 1
                }
            } else {
                withAnimation(.easeIn(duration: 0.14)) {
                    fillScale = 0.1
                    checkProgress = 0
                }
            }
        }
    }
}

private struct AnimatedCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.56))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.84))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.14))
        return path
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

    static func promptHasDate(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        let keywords = [
            "today", "tomorrow", "tonight", "next week", "next month",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "january", "february", "march", "april", "may", "june", "july",
            "august", "september", "october", "november", "december",
            "weekend", "this week"
        ]

        if keywords.contains(where: lowered.contains) {
            return true
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        return detector?.firstMatch(in: prompt, range: range) != nil
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
            .replacingOccurrences(of: #"(?i)\b(remind me to|add a task to|add task to|add todo to|add|create|make|task|todo|to do|remind|today|tomorrow|tonight|next week|next month|this week|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday|urgent|asap|important|high priority|low priority|please)\b"#, with: " ", options: .regularExpression)
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
    @State private var isSaving = false
    @State private var saveError: String?

    private enum Field {
        case title
        case notes
    }

    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date
    @State private var reminderRepeat: ReminderRepeat
    @FocusState private var focusedField: Field?

    private let task: TaskItemRecord?
    private let onSave: (TaskItemDraft) async -> String?

    init(task: TaskItemRecord?, onSave: @escaping (TaskItemDraft) async -> String?) {
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
                Section {
                    CreationGuideCard(
                        title: task == nil ? "Capture The Next Thing" : "Refine Task",
                        subtitle: "Give it a clear title, choose priority, and add dates or reminders only when they help you act.",
                        icon: priority == .high ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                        tint: editorPriorityTint(for: priority),
                        status: hasDueDate ? dueDate.formatted(date: .abbreviated, time: .omitted) : "No due date"
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    TextField("Task title", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .notes
                        }

                    Picker("Priority", selection: $priority) {
                        ForEach([TaskPriority.high, .normal, .low], id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Add due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                        HStack {
                            Button("Today") { dueDate = .now }
                            Button("Tomorrow") {
                                dueDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
                            }
                        }
                        .buttonStyle(.bordered)
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
                        .focused($focusedField, equals: .notes)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(task == nil ? "Add" : "Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

                        let draft = TaskItemDraft(
                            title: trimmedTitle,
                            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                            priority: priority,
                            dueDate: hasDueDate ? dueDate : nil,
                            completed: task?.completed ?? false,
                            reminderEnabled: reminderEnabled,
                            reminderDate: reminderEnabled ? reminderDate : nil,
                            reminderRepeat: reminderEnabled ? reminderRepeat : .oneTime
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
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: hasDueDate) { _, enabled in
                guard enabled, reminderEnabled, reminderDate < Date() else { return }
                reminderDate = dueDate
            }
            .onChange(of: dueDate) { _, newValue in
                guard reminderEnabled, reminderDate < Date() else { return }
                reminderDate = newValue
            }
            .onChange(of: reminderEnabled) { _, enabled in
                guard enabled, reminderDate < Date() else { return }
                reminderDate = hasDueDate ? dueDate : Date()
            }
            .onAppear {
                if task == nil {
                    focusedField = .title
                }
            }
        }
    }

    private func editorPriorityTint(for priority: TaskPriority) -> Color {
        switch priority {
        case .high:
            return DesignSystem.oweColor
        case .normal:
            return DesignSystem.accentColor
        case .low:
            return DesignSystem.secondaryTextColor
        }
    }
}
