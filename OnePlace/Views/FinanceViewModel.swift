import Foundation
import FirebaseAuth

@MainActor
final class FinanceViewModel: ObservableObject {

    // UI State
    @Published private(set) var entries: [FinanceEntryRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSaving: Bool = false
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

    @discardableResult
    func addEntry(draft: FinanceEntryDraft) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You’re not signed in."
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let createdRecord = try await repo.createEntry(for: uid, draft: draft)
            upsert(createdRecord)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateEntry(_ entry: FinanceEntryRecord) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            do {
                try await repo.updateEntry(entry)
                upsert(entry)
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }

        let original = entries[index]
        entries[index] = entry

        do {
            try await repo.updateEntry(entry)
            resortEntries()
            return true
        } catch {
            if let currentIndex = entries.firstIndex(where: { $0.id == original.id }) {
                entries[currentIndex] = original
            }
            errorMessage = error.localizedDescription
            return false
        }
    }


    func toggleCompletion(for entry: FinanceEntryRecord) async {
        errorMessage = nil

        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let original = entries[index]
        entries[index].isCompleted.toggle()

        do {
            try await repo.updateEntry(entries[index])
        } catch {
            entries[index] = original
            errorMessage = error.localizedDescription
        }
    }

    func setCompletion(for selectedIDs: Set<String>, isCompleted: Bool) async {
        let targetIDs = selectedIDs.intersection(entries.map(\.id))
        guard !targetIDs.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let originals = entries

        for index in entries.indices where targetIDs.contains(entries[index].id) {
            entries[index].isCompleted = isCompleted
        }

        do {
            for entry in entries where targetIDs.contains(entry.id) {
                try await repo.updateEntry(entry)
            }
            resortEntries()
        } catch {
            entries = originals
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: FinanceEntryRecord) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await repo.deleteEntry(entry)
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntries(withIDs selectedIDs: Set<String>) async {
        let targets = entries.filter { selectedIDs.contains($0.id) }
        guard !targets.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let originals = entries
        entries.removeAll { selectedIDs.contains($0.id) }

        do {
            for entry in targets {
                try await repo.deleteEntry(entry)
            }
        } catch {
            entries = originals
            errorMessage = error.localizedDescription
        }
    }

    func clearCompletedEntries() async {
        let completedEntries = entries.filter(\.isCompleted)
        guard !completedEntries.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            for entry in completedEntries {
                try await repo.deleteEntry(entry)
            }

            entries.removeAll(where: \.isCompleted)
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func upsert(_ entry: FinanceEntryRecord) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }

        resortEntries()
    }

    private func resortEntries() {
        entries.sort(by: FinanceEntryList.newestFirst)
    }
}
