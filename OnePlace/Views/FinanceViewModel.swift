import Foundation
import FirebaseAuth

@MainActor
final class FinanceViewModel: ObservableObject {

    // UI State
    @Published private(set) var entries: [FinanceEntryRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let repo: FinanceRepository

    // ✅ Avoid default-arg creating a @MainActor object
    init(repo: FinanceRepository? = nil) {
        self.repo = repo ?? FinanceRepository()
    }

    // MARK: - Public API

    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            entries = []
            errorMessage = "You’re not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            entries = try await repo.fetchEntries(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(draft: FinanceEntryDraft) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You’re not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.createEntry(for: uid, draft: draft)
            entries = try await repo.fetchEntries(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEntry(_ entry: FinanceEntryRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updateEntry(entry)
            guard let uid = Auth.auth().currentUser?.uid else { return }
            entries = try await repo.fetchEntries(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: FinanceEntryRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deleteEntry(entry)
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
