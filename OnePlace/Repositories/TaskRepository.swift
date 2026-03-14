import FirebaseFirestore
import Foundation

@MainActor
final class TaskRepository {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Fetch

    func fetchTasks(for uid: String) async throws -> [TaskItemRecord] {
        let snapshot = try await taskCollection(for: uid).getDocuments()

        return snapshot.documents.compactMap { document in
            guard let dto = parseDTO(from: document.data()),
                  let record = dto.toRecord(id: document.documentID, ownerUserId: uid) else {
                return nil
            }
            return record
        }
        .sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?):
                if left != right {
                    return left < right
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            if lhs.completed != rhs.completed {
                return !lhs.completed && rhs.completed
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - Create

    func createTask(for uid: String, draft: TaskItemDraft) async throws {
        let documentRef = taskCollection(for: uid).document()

        let record = TaskItemRecord(
            id: documentRef.documentID,
            ownerUserId: uid,
            title: draft.title,
            notes: draft.notes,
            priority: draft.priority,
            dueDate: draft.dueDate,
            completed: draft.completed,
            reminderEnabled: draft.reminderEnabled,
            reminderDate: draft.reminderDate
        )

        try await documentRef.setData(encode(record: record), merge: false)
    }

    // MARK: - Update

    func updateTask(_ task: TaskItemRecord) async throws {
        let documentRef = taskCollection(for: task.ownerUserId).document(task.id)
        try await documentRef.setData(encode(record: task), merge: false)
    }

    // MARK: - Delete

    func deleteTask(_ task: TaskItemRecord) async throws {
        try await taskCollection(for: task.ownerUserId)
            .document(task.id)
            .delete()
    }

    // MARK: - Firestore Path

    private func taskCollection(for uid: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("organizer")
            .document("tasks")
            .collection("items")
    }

    // MARK: - Parsing

    private func parseDTO(from data: [String: Any]) -> TaskItemDTO? {
        guard let title = data["title"] as? String,
              let priority = data["priority"] as? String else {
            return nil
        }

        let notes = data["notes"] as? String
        let completed = data["completed"] as? Bool ?? false
        let reminderEnabled = data["reminderEnabled"] as? Bool ?? false

        let dueDate: Date?
        if let timestamp = data["dueDate"] as? Timestamp {
            dueDate = timestamp.dateValue()
        } else if let milliseconds = data["dueDate"] as? Double {
            dueDate = Date(timeIntervalSince1970: milliseconds / 1000)
        } else if let seconds = data["dueDate"] as? Int64 {
            dueDate = Date(timeIntervalSince1970: TimeInterval(seconds))
        } else {
            dueDate = nil
        }

        let reminderDate: Date?
        if let timestamp = data["reminderDate"] as? Timestamp {
            reminderDate = timestamp.dateValue()
        } else {
            reminderDate = nil
        }

        return TaskItemDTO(
            title: title,
            notes: notes,
            priority: priority,
            dueDate: dueDate,
            completed: completed,
            reminderEnabled: reminderEnabled,
            reminderDate: reminderDate
        )
    }

    // MARK: - Encoding

    private func encode(record: TaskItemRecord) -> [String: Any] {
        var data: [String: Any] = [
            "title": record.title,
            "priority": record.priority.rawValue,
            "completed": record.completed,
            "reminderEnabled": record.reminderEnabled
        ]

        if let notes = record.notes {
            data["notes"] = notes
        }
        if let dueDate = record.dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        }
        if let reminderDate = record.reminderDate {
            data["reminderDate"] = Timestamp(date: reminderDate)
        }

        return data
    }

    // MARK: - Private DTO

    private struct TaskItemDTO {
        let title: String
        let notes: String?
        let priority: String
        let dueDate: Date?
        let completed: Bool
        let reminderEnabled: Bool
        let reminderDate: Date?

        func toRecord(id: String, ownerUserId: String) -> TaskItemRecord? {
            guard let taskPriority = TaskPriority(rawValue: priority) else {
                return nil
            }

            return TaskItemRecord(
                id: id,
                ownerUserId: ownerUserId,
                title: title,
                notes: notes,
                priority: taskPriority,
                dueDate: dueDate,
                completed: completed,
                reminderEnabled: reminderEnabled,
                reminderDate: reminderDate
            )
        }
    }
}
