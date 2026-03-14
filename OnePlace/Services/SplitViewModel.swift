import Foundation
import FirebaseAuth

@MainActor
final class SplitViewModel: ObservableObject {

    // UI State
    @Published private(set) var people: [SplitPersonRecord] = []
    @Published private(set) var expenses: [SplitExpenseRecord] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let repo: SplitRepository

    init(repo: SplitRepository? = nil) {
        self.repo = repo ?? SplitRepository()
    }

    // MARK: - Public API

    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            people = []
            expenses = []
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            people = try await repo.fetchPeople(for: uid)
            expenses = try await repo.fetchExpenses(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - People Operations

    func addPerson(name: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await repo.createPerson(for: uid, name: name)
            people = try await repo.fetchPeople(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePerson(_ person: SplitPersonRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updatePerson(person)
            guard let uid = Auth.auth().currentUser?.uid else { return }
            people = try await repo.fetchPeople(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePerson(_ person: SplitPersonRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deletePerson(person)
            people.removeAll { $0.id == person.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Expense Operations

    func addExpense(draft: SplitExpenseDraft) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not signed in."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await repo.createExpense(for: uid, draft: draft)
            expenses = try await repo.fetchExpenses(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateExpense(_ expense: SplitExpenseRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updateExpense(expense)
            guard let uid = Auth.auth().currentUser?.uid else { return }
            expenses = try await repo.fetchExpenses(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteExpense(_ expense: SplitExpenseRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deleteExpense(expense)
            expenses.removeAll { $0.id == expense.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Calculations

    func getBalance(for person: SplitPersonRecord) -> Double {
        repo.calculateBalance(for: person.id, expenses: expenses)
    }
}
