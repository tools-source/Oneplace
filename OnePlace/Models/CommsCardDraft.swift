import Foundation

struct CommsCardDraft {
    var title: String = ""
    var phrase: String = ""
    var emoji: String? = nil
    var hasImage: Bool = false
    var hasAudio: Bool = false
    var audioData: Data? = nil
}
