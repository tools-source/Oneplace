import Foundation

struct CommsCardRecord: Identifiable, Equatable {
    let id: String
    let ownerUserId: String
    var title: String
    var phrase: String
    var emoji: String?
    var hasImage: Bool
    var hasAudio: Bool
    var audioData: Data?
}
