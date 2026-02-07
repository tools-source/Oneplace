import AVFoundation
import Foundation
import SwiftUI

final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var lastRecordingData: Data?

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("commsRecording.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
            isRecording = false
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        if let url = audioRecorder?.url {
            lastRecordingData = try? Data(contentsOf: url)
        }
    }

    func play(data: Data?) {
        guard let data else { return }
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
}
