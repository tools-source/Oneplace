import FirebaseFirestore
import Foundation

@MainActor
final class FlowRepository {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Fetch

    func fetchItems(for uid: String) async throws -> [FlowItemRecord] {
        let snapshot = try await flowCollection(for: uid)
            .order(by: "nextDueDate", descending: false)
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

    @discardableResult
    func createItem(for uid: String, draft: FlowItemDraft) async throws -> FlowItemRecord {
        let documentRef = flowCollection(for: uid).document()

        let record = FlowItemRecord(
            id: documentRef.documentID,
            ownerUserId: uid,
            title: draft.title,
            amount: draft.amount,
            type: draft.type,
            frequency: draft.frequency,
            nextDueDate: draft.nextDueDate,
            status: draft.status,
            notes: draft.notes,
            reminderEnabled: draft.reminderEnabled,
            reminderDate: draft.reminderDate,
            reminderHour: draft.reminderHour,
            reminderMinute: draft.reminderMinute,
            reminderRepeat: draft.reminderRepeat,
            reminderOffsetDays: draft.reminderOffsetDays
        )

        try await documentRef.setData(encode(record: record), merge: false)
        return record
    }

    // MARK: - Update

    func updateItem(_ item: FlowItemRecord) async throws {
        let documentRef = flowCollection(for: item.ownerUserId).document(item.id)
        try await documentRef.setData(encode(record: item), merge: false)
    }

    // MARK: - Delete

    func deleteItem(_ item: FlowItemRecord) async throws {
        try await flowCollection(for: item.ownerUserId)
            .document(item.id)
            .delete()
    }

    // MARK: - Firestore Path

    private func flowCollection(for uid: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("flow")
            .document("items")
            .collection("bills")
    }

    // MARK: - Parsing

    private func parseDTO(from data: [String: Any]) -> FlowItemDTO? {
        guard let title = data["title"] as? String,
              let amount = data["amount"] as? Double,
              let type = data["type"] as? String,
              let frequency = data["frequency"] as? String,
              let status = data["status"] as? String else {
            return nil
        }

        let nextDueDate: Date
        if let timestamp = data["nextDueDate"] as? Timestamp {
            nextDueDate = timestamp.dateValue()
        } else if let milliseconds = data["nextDueDate"] as? Double {
            nextDueDate = Date(timeIntervalSince1970: milliseconds / 1000)
        } else if let seconds = data["nextDueDate"] as? Int64 {
            nextDueDate = Date(timeIntervalSince1970: TimeInterval(seconds))
        } else {
            return nil
        }

        let reminderEnabled = data["reminderEnabled"] as? Bool ?? false
        let reminderOffsetDays = data["reminderOffsetDays"] as? Int ?? 0
        let notes = data["notes"] as? String
        let reminderRepeat = data["reminderRepeat"] as? String ?? ReminderRepeatRule.none.rawValue
        
        let reminderDate: Date?
        if let timestamp = data["reminderDate"] as? Timestamp {
            reminderDate = timestamp.dateValue()
        } else {
            reminderDate = nil
        }

        let reminderHour = data["reminderHour"] as? Int
        let reminderMinute = data["reminderMinute"] as? Int

        return FlowItemDTO(
            title: title,
            amount: amount,
            type: type,
            frequency: frequency,
            nextDueDate: nextDueDate,
            status: status,
            notes: notes,
            reminderEnabled: reminderEnabled,
            reminderDate: reminderDate,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderRepeat: reminderRepeat,
            reminderOffsetDays: reminderOffsetDays
        )
    }

    // MARK: - Encoding

    private func encode(record: FlowItemRecord) -> [String: Any] {
        var data: [String: Any] = [
            "title": record.title,
            "amount": record.amount,
            "type": record.type.rawValue,
            "frequency": record.frequency.rawValue,
            "nextDueDate": Timestamp(date: record.nextDueDate),
            "status": record.status.rawValue,
            "reminderEnabled": record.reminderEnabled,
            "reminderRepeat": record.reminderRepeat.rawValue,
            "reminderOffsetDays": record.reminderOffsetDays
        ]

        if let notes = record.notes {
            data["notes"] = notes
        }
        if let reminderDate = record.reminderDate {
            data["reminderDate"] = Timestamp(date: reminderDate)
        }
        if let reminderHour = record.reminderHour {
            data["reminderHour"] = reminderHour
        }
        if let reminderMinute = record.reminderMinute {
            data["reminderMinute"] = reminderMinute
        }

        return data
    }

    // MARK: - Private DTO

    private struct FlowItemDTO {
        let title: String
        let amount: Double
        let type: String
        let frequency: String
        let nextDueDate: Date
        let status: String
        let notes: String?
        let reminderEnabled: Bool
        let reminderDate: Date?
        let reminderHour: Int?
        let reminderMinute: Int?
        let reminderRepeat: String
        let reminderOffsetDays: Int

        func toRecord(id: String, ownerUserId: String) -> FlowItemRecord? {
            guard let flowType = FlowType(rawValue: type),
                  let flowFrequency = FlowFrequency(rawValue: frequency),
                  let flowStatus = FlowStatus(rawValue: status),
                  let flowReminderRepeat = ReminderRepeatRule(rawValue: reminderRepeat) else {
                return nil
            }

            return FlowItemRecord(
                id: id,
                ownerUserId: ownerUserId,
                title: title,
                amount: amount,
                type: flowType,
                frequency: flowFrequency,
                nextDueDate: nextDueDate,
                status: flowStatus,
                notes: notes,
                reminderEnabled: reminderEnabled,
                reminderDate: reminderDate,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                reminderRepeat: flowReminderRepeat,
                reminderOffsetDays: reminderOffsetDays
            )
        }
    }
}
