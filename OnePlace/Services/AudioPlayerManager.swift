import AVFoundation
import Foundation

final class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()

    @Published private(set) var playingCardID: UUID?

    private var audioPlayer: AVAudioPlayer?

    func play(data: Data?, for cardID: UUID) {
        guard let data else {
            stop()
            return
        }

        stop()

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            playingCardID = cardID
        } catch {
            print("Failed to play audio: \(error)")
            playingCardID = nil
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingCardID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingCardID = nil
    }
}
