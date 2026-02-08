import Foundation
import AVFoundation
import SwiftUI

final class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()

    @Published private(set) var currentlyPlayingID: UUID?

    private var player: AVAudioPlayer?

    private override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // Fail silently to avoid issues in previews/tests
        }
    }

    func play(data: Data?, for id: UUID) {
        guard let data else {
            stop()
            return
        }

        // If the same item is tapped again, restart playback from the beginning
        if currentlyPlayingID == id, let player, player.isPlaying {
            player.stop()
        }

        do {
            let newPlayer = try AVAudioPlayer(data: data)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            currentlyPlayingID = id
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentlyPlayingID = nil
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stop()
    }
}
