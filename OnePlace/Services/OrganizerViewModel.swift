import Foundation
import FirebaseAuth

@MainActor
final class OrganizerViewModel: ObservableObject {

    // UI State
    @Published private(set) var tasks: [TaskItemRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let repo: TaskRepository

    init(repo: TaskRepository? = nil) {
        self.repo = repo ?? TaskRepository()
    }

    // MARK: - Public API

    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            tasks = []
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tasks = try await repo.fetchTasks(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTask(draft: TaskItemDraft) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.createTask(for: uid, draft: draft)
            tasks = try await repo.fetchTasks(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(_ task: TaskItemRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updateTask(task)
            guard let uid = Auth.auth().currentUser?.uid else { return }
            tasks = try await repo.fetchTasks(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTask(_ task: TaskItemRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deleteTask(task)
            tasks.removeAll { $0.id == task.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCompletion(for task: TaskItemRecord) async {
        errorMessage = nil

        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let original = tasks[index]
        tasks[index].completed.toggle()

        do {
            try await repo.updateTask(tasks[index])
        } catch {
            tasks[index] = original
            errorMessage = error.localizedDescription
        }
    }
}
