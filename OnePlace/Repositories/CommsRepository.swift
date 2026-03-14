import FirebaseFirestore
import Foundation

@MainActor
final class CommsRepository {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Fetch

    func fetchCards(for uid: String) async throws -> [CommsCardRecord] {
        let snapshot = try await cardsCollection(for: uid)
            .order(by: "title", descending: false)
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

    func createCard(for uid: String, draft: CommsCardDraft) async throws {
        let documentRef = cardsCollection(for: uid).document()

        let record = CommsCardRecord(
            id: documentRef.documentID,
            ownerUserId: uid,
            title: draft.title,
            phrase: draft.phrase,
            emoji: draft.emoji,
            hasImage: draft.hasImage,
            hasAudio: draft.audioData != nil || draft.hasAudio,
            audioData: draft.audioData
        )

        try await documentRef.setData(encode(record: record), merge: false)
    }

    // MARK: - Update

    func updateCard(_ card: CommsCardRecord) async throws {
        let documentRef = cardsCollection(for: card.ownerUserId).document(card.id)
        try await documentRef.setData(encode(record: card), merge: false)
    }

    // MARK: - Delete

    func deleteCard(_ card: CommsCardRecord) async throws {
        try await cardsCollection(for: card.ownerUserId)
            .document(card.id)
            .delete()
    }

    // MARK: - Firestore Path

    private func cardsCollection(for uid: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("comms")
            .document("cards")
            .collection("items")
    }

    // MARK: - Parsing

    private func parseDTO(from data: [String: Any]) -> CommsCardDTO? {
        guard let title = data["title"] as? String else {
            return nil
        }

        let phrase = data["phrase"] as? String ?? ""
        let emoji = data["emoji"] as? String
        let hasImage = data["hasImage"] as? Bool ?? false
        let audioData = parseAudioData(from: data["audioData"])
        let hasAudio = data["hasAudio"] as? Bool ?? (audioData != nil)

        return CommsCardDTO(
            title: title,
            phrase: phrase,
            emoji: emoji,
            hasImage: hasImage,
            hasAudio: hasAudio,
            audioData: audioData
        )
    }

    // MARK: - Encoding

    private func encode(record: CommsCardRecord) -> [String: Any] {
        var data: [String: Any] = [
            "title": record.title,
            "phrase": record.phrase,
            "hasImage": record.hasImage,
            "hasAudio": record.hasAudio
        ]

        if let emoji = record.emoji {
            data["emoji"] = emoji
        }
        if let audioData = record.audioData {
            data["audioData"] = audioData
        }

        return data
    }

    private func parseAudioData(from value: Any?) -> Data? {
        if let data = value as? Data {
            return data
        }
        if let nsData = value as? NSData {
            return nsData as Data
        }
        return nil
    }

    // MARK: - Private DTO

    private struct CommsCardDTO {
        let title: String
        let phrase: String
        let emoji: String?
        let hasImage: Bool
        let hasAudio: Bool
        let audioData: Data?

        func toRecord(id: String, ownerUserId: String) -> CommsCardRecord? {
            return CommsCardRecord(
                id: id,
                ownerUserId: ownerUserId,
                title: title,
                phrase: phrase,
                emoji: emoji,
                hasImage: hasImage,
                hasAudio: hasAudio,
                audioData: audioData
            )
        }
    }
}
