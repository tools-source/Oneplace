import FirebaseFirestore
import Foundation

@MainActor
final class SplitRepository {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Fetch People

    func fetchPeople(for uid: String) async throws -> [SplitPersonRecord] {
        let snapshot = try await peopleCollection(for: uid)
            .order(by: "name", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            parsePersonDTO(from: document.data(), id: document.documentID, ownerUserId: uid)
        }
    }

    // MARK: - Create Person

    func createPerson(for uid: String, name: String) async throws -> String {
        let documentRef = peopleCollection(for: uid).document()
        let data: [String: Any] = [
            "name": name
        ]
        try await documentRef.setData(data, merge: false)
        return documentRef.documentID
    }

    // MARK: - Update Person

    func updatePerson(_ person: SplitPersonRecord) async throws {
        let documentRef = peopleCollection(for: person.ownerUserId).document(person.id)
        try await documentRef.setData(["name": person.name], merge: false)
    }

    // MARK: - Delete Person

    func deletePerson(_ person: SplitPersonRecord) async throws {
        try await peopleCollection(for: person.ownerUserId)
            .document(person.id)
            .delete()
    }

    // MARK: - Fetch Expenses

    func fetchExpenses(for uid: String) async throws -> [SplitExpenseRecord] {
        let snapshot = try await expensesCollection(for: uid)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            parseExpenseDTO(from: document.data(), id: document.documentID, ownerUserId: uid)
        }
    }

    // MARK: - Create Expense

    func createExpense(for uid: String, draft: SplitExpenseDraft) async throws -> String {
        let documentRef = expensesCollection(for: uid).document()
        let data = encodeExpense(draft: draft)
        try await documentRef.setData(data, merge: false)
        return documentRef.documentID
    }

    // MARK: - Update Expense

    func updateExpense(_ expense: SplitExpenseRecord) async throws {
        let documentRef = expensesCollection(for: expense.ownerUserId).document(expense.id)
        let data: [String: Any] = [
            "title": expense.title,
            "amount": expense.amount,
            "date": Timestamp(date: expense.date),
            "participantIds": expense.participantIds,
            "paidById": expense.paidById ?? NSNull()
        ]
        try await documentRef.setData(data, merge: false)
    }

    // MARK: - Delete Expense

    func deleteExpense(_ expense: SplitExpenseRecord) async throws {
        try await expensesCollection(for: expense.ownerUserId)
            .document(expense.id)
            .delete()
    }

    // MARK: - Calculate Balance

    func calculateBalance(for personId: String, expenses: [SplitExpenseRecord]) -> Double {
        var balance = 0.0

        for expense in expenses {
            let splitAmount = expense.amount / Double(max(1, expense.participantIds.count))

            if expense.paidById == personId {
                balance += expense.amount
            }

            if expense.participantIds.contains(personId) {
                balance -= splitAmount
            }
        }

        return balance
    }

    // MARK: - Firestore Paths

    private func peopleCollection(for uid: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("split")
            .document("data")
            .collection("people")
    }

    private func expensesCollection(for uid: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("split")
            .document("data")
            .collection("expenses")
    }

    // MARK: - Parsing

    private func parsePersonDTO(from data: [String: Any], id: String, ownerUserId: String) -> SplitPersonRecord? {
        guard let name = data["name"] as? String else {
            return nil
        }

        return SplitPersonRecord(
            id: id,
            ownerUserId: ownerUserId,
            name: name
        )
    }

    private func parseExpenseDTO(from data: [String: Any], id: String, ownerUserId: String) -> SplitExpenseRecord? {
        guard let title = data["title"] as? String,
              let amount = data["amount"] as? Double,
              let participantIds = data["participantIds"] as? [String] else {
            return nil
        }

        let date: Date
        if let timestamp = data["date"] as? Timestamp {
            date = timestamp.dateValue()
        } else if let milliseconds = data["date"] as? Double {
            date = Date(timeIntervalSince1970: milliseconds / 1000)
        } else if let seconds = data["date"] as? Int64 {
            date = Date(timeIntervalSince1970: TimeInterval(seconds))
        } else {
            date = Date()
        }

        let paidById = data["paidById"] as? String

        return SplitExpenseRecord(
            id: id,
            ownerUserId: ownerUserId,
            title: title,
            amount: amount,
            date: date,
            participantIds: participantIds,
            paidById: paidById
        )
    }

    // MARK: - Encoding

    private func encodeExpense(draft: SplitExpenseDraft) -> [String: Any] {
        var data: [String: Any] = [
            "title": draft.title,
            "amount": draft.amount,
            "date": Timestamp(date: draft.date),
            "participantIds": draft.participantIds
        ]

        if let paidById = draft.paidById {
            data["paidById"] = paidById
        } else {
            data["paidById"] = NSNull()
        }

        return data
    }
}
