import FirebaseFirestore
import Foundation

@MainActor
final class FinanceViewModel: ObservableObject {
    @Published private(set) var entries: [FinanceEntryRecord] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository: FinanceRepository

    init(repository: FinanceRepository = FinanceRepository()) {
        self.repository = repository
    }

    func loadEntries(for uid: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            entries = try await repository.fetchEntries(for: uid)
            errorMessage = nil
        } catch {
            errorMessage = makeFriendlyError(error)
        }
    }

    func addEntry(for uid: String, draft: FinanceEntryDraft) async {
        do {
            try await repository.createEntry(for: uid, draft: draft)
            await loadEntries(for: uid)
        } catch {
            errorMessage = makeFriendlyError(error)
        }
    }

    func updateEntry(_ entry: FinanceEntryRecord) async {
        do {
            try await repository.updateEntry(entry)
            await loadEntries(for: entry.ownerUserId)
        } catch {
            errorMessage = makeFriendlyError(error)
        }
    }

    func deleteEntry(_ entry: FinanceEntryRecord) async {
        do {
            try await repository.deleteEntry(entry)
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = makeFriendlyError(error)
        }
    }

    private func makeFriendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           nsError.code == FirestoreErrorCode.unavailable.rawValue {
            return "You're offline. Changes sync automatically when connection returns."
        }

        return nsError.localizedDescription
    }
}
