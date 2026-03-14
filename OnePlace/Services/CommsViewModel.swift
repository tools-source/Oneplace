import Foundation
import FirebaseAuth

@MainActor
final class CommsViewModel: ObservableObject {

    // UI State
    @Published private(set) var cards: [CommsCardRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let repo: CommsRepository

    init(repo: CommsRepository? = nil) {
        self.repo = repo ?? CommsRepository()
    }

    // MARK: - Public API

    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            cards = []
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            cards = try await repo.fetchCards(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addCard(draft: CommsCardDraft) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.createCard(for: uid, draft: draft)
            cards = try await repo.fetchCards(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCard(_ card: CommsCardRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updateCard(card)
            guard let uid = Auth.auth().currentUser?.uid else { return }
            cards = try await repo.fetchCards(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCard(_ card: CommsCardRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deleteCard(card)
            cards.removeAll { $0.id == card.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
