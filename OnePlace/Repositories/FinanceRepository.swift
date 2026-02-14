import FirebaseFirestore
import Foundation

@MainActor
final class FinanceRepository {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func fetchEntries(for uid: String) async throws -> [FinanceEntryRecord] {
        let snapshot = try await transactionsCollection(for: uid)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let dto = parseDTO(from: document.data()) else { return nil }
            return dto.toRecord(id: document.documentID, ownerUserId: uid)
        }
    }

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

        try documentRef.setData(try encode(dto: FinanceEntryDocument(record: record)))
    }

    func updateEntry(_ entry: FinanceEntryRecord) async throws {
        let documentRef = transactionsCollection(for: entry.ownerUserId).document(entry.id)
        try await documentRef.setData(try encode(dto: FinanceEntryDocument(record: entry)), merge: false)
    }

    func deleteEntry(_ entry: FinanceEntryRecord) async throws {
        try await transactionsCollection(for: entry.ownerUserId).document(entry.id).delete()
    }

    private func transactionsCollection(for uid: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("finance")
            .document("entries")
            .collection("transactions")
    }

    private func parseDTO(from data: [String: Any]) -> FinanceEntryDocument? {
        guard let amount = data["amount"] as? Double,
              let type = data["type"] as? String,
              let category = data["category"] as? String,
              let entryDescription = data["entryDescription"] as? String,
              let urgency = data["urgency"] as? String,
              let date = (data["date"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return FinanceEntryDocument(
            amount: amount,
            type: type,
            category: category,
            entryDescription: entryDescription,
            date: date,
            urgency: urgency
        )
    }

    private func encode(dto: FinanceEntryDocument) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(dto)
        let object = try JSONSerialization.jsonObject(with: data)

        guard let dictionary = object as? [String: Any] else {
            throw NSError(domain: "FinanceRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode finance entry"])
        }

        var firestoreDictionary = dictionary
        if let milliseconds = dictionary["date"] as? Double {
            firestoreDictionary["date"] = Timestamp(date: Date(timeIntervalSince1970: milliseconds / 1000))
        }

        return firestoreDictionary
    }
}
