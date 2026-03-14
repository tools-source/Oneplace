import AVFoundation
import Foundation
import SwiftUI

final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var lastRecordingData: Data?
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    func startRecording() {
        errorMessage = nil
        let session = AVAudioSession.sharedInstance()
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.errorMessage = "Microphone access is required to record audio."
                    self.isRecording = false
                    return
                }

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

                    self.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                    self.audioRecorder?.record()
                    self.isRecording = true
                } catch {
                    self.errorMessage = "Could not start recording."
                    self.isRecording = false
                }
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        if let url = audioRecorder?.url {
            lastRecordingData = try? Data(contentsOf: url)
        }
    }

    func clearRecording() {
        audioRecorder?.stop()
        isRecording = false
        lastRecordingData = nil
    }

    func play(data: Data?) {
        guard let data else { return }
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            errorMessage = "Could not play the recording."
        }
    }
}
