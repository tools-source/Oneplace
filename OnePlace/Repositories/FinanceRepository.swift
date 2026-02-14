import FirebaseFirestore
import Foundation

@MainActor
final class FinanceRepository {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Fetch

    func fetchEntries(for uid: String) async throws -> [FinanceEntryRecord] {
        let snapshot = try await transactionsCollection(for: uid)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let dto = parseDTO(from: document.data()),
                  let record = dto.toRecord(id: document.documentID, ownerUserId: uid) else {
                return nil
            }
            return record
        }
    }

    // MARK: - Create

    func createEntry(for uid: String, draft: FinanceEntryDraft) async throws {
        let documentRef = transactionsCollection(for: uid).document()

        let record = FinanceEntryRecord(
            id: documentRef.documentID,
            ownerUserId: uid,
            amount: draft.amount,
            type: draft.type,
            category: draft.category,
            entryDescription: draft.entryDescription,
            date: draft.date,
            urgency: draft.urgency
        )

        try await documentRef.setData(encode(record: record), merge: false)
    }

    // MARK: - Update

    func updateEntry(_ entry: FinanceEntryRecord) async throws {
        let documentRef = transactionsCollection(for: entry.ownerUserId).document(entry.id)
        try await documentRef.setData(encode(record: entry), merge: false)
    }

    // MARK: - Delete

    func deleteEntry(_ entry: FinanceEntryRecord) async throws {
        try await transactionsCollection(for: entry.ownerUserId)
            .document(entry.id)
            .delete()
    }

    // MARK: - Firestore Path

    private func transactionsCollection(for uid: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("finance")
            .document("entries")
            .collection("transactions")
    }

    // MARK: - Parsing

    private func parseDTO(from data: [String: Any]) -> FinanceEntryDTO? {
        guard let amount = data["amount"] as? Double,
              let type = data["type"] as? String,
              let category = data["category"] as? String,
              let entryDescription = data["entryDescription"] as? String,
              let urgency = data["urgency"] as? String else {
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
            return nil
        }

        return FinanceEntryDTO(
            amount: amount,
            type: type,
            category: category,
            entryDescription: entryDescription,
            date: date,
            urgency: urgency
        )
    }

    // MARK: - Encoding

    private func encode(record: FinanceEntryRecord) -> [String: Any] {
        [
            "amount": record.amount,
            "type": record.type.rawValue,               // enum -> String
            "category": record.category,
            "entryDescription": record.entryDescription,
            "urgency": record.urgency.rawValue,         // enum -> String
            "date": Timestamp(date: record.date)
        ]
    }

    // MARK: - Private DTO (prevents naming conflicts)

    private struct FinanceEntryDTO {
        let amount: Double
        let type: String
        let category: String
        let entryDescription: String
        let date: Date
        let urgency: String

        func toRecord(id: String, ownerUserId: String) -> FinanceEntryRecord? {
            guard let financeType = FinanceType(rawValue: type),
                  let financeUrgency = FinanceUrgency(rawValue: urgency) else {
                // If Firestore contains an unknown string, skip the record instead of crashing.
                return nil
            }

            return FinanceEntryRecord(
                id: id,
                ownerUserId: ownerUserId,
                amount: amount,
                type: financeType,
                category: category,
                entryDescription: entryDescription,
                date: date,
                urgency: financeUrgency
            )
        }
    }
}
