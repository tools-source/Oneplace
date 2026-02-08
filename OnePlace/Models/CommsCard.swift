import Foundation
import SwiftData

@Model
final class CommsCard {
    var id: UUID = UUID()
    var ownerUserId: String = ""
    var title: String = ""
    var phrase: String = ""
    var language: String = ""
    var emoji: String?
    var imageData: Data?
    var audioData: Data?

    init(
        id: UUID = UUID(),
        ownerUserId: String,
        title: String = "",
        phrase: String = "",
        language: String = "",
        emoji: String? = nil,
        imageData: Data? = nil,
        audioData: Data? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.title = title
        self.phrase = phrase
        self.language = language
        self.emoji = emoji
        self.imageData = imageData
        self.audioData = audioData
    }
}
