import SwiftData
import SwiftUI
import UIKit
import AVFoundation

struct CommsView: View {
    let ownerUserId: String

    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CommsCard]

    @State private var showingEditor = false
    @State private var editingCard: CommsCard?

    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var playbackGate = PlaybackGate()

    private let speech = AVSpeechSynthesizer()
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    init(ownerUserId: String) {
        self.ownerUserId = ownerUserId
        _cards = Query(
            filter: #Predicate<CommsCard> { $0.ownerUserId == ownerUserId },
            sort: [SortDescriptor(\.title)]
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if cards.isEmpty {
                    talkBoardEmptyState
                        .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(cards) { card in
                                CommsCardView(card: card)
                                    .onTapGesture { handleTap(for: card) }
                                    .contextMenu {
                                        Button {
                                            editingCard = card
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }

                                        // Optional utilities
                                        if card.audioData != nil {
                                            Button {
                                                handleTap(for: card)
                                            } label: {
                                                Label("Play", systemImage: "play.fill")
                                            }
                                        } else {
                                            Button {
                                                let text = card.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                ? card.title
                                                : card.phrase
                                                speakEnglish(text)
                                            } label: {
                                                Label("Speak", systemImage: "speaker.wave.2.fill")
                                            }
                                        }

                                        Button(role: .destructive) {
                                            modelContext.delete(card)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Talk Board")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("New Card", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingCard) { card in
                CommsCardEditor(ownerUserId: ownerUserId, card: card)
            }
            .sheet(isPresented: $showingEditor) {
                CommsCardEditor(ownerUserId: ownerUserId, card: nil) { newCard in
                    modelContext.insert(newCard)
                }
            }
            .onAppear {
                speech.delegate = playbackGate
            }
        }
    }

    private var talkBoardEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.and.waveform")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Speech cards that talk")
                .font(.title3.weight(.semibold))

            Text("Create picture cards with a recorded voice. When your child taps a card, it plays the sound.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)

            Button {
                showingEditor = true
            } label: {
                Label("Create First Card", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)

            Text("Tip: Taps won’t replay until the sound finishes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }

    private func handleTap(for card: CommsCard) {
        // ✅ Prevent repeated taps from replaying/overlapping
        guard !playbackGate.isLocked else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return
        }

        // 1) Prefer recorded audio (parent/kid voice)
        if let audioData = card.audioData {
            playRecordedAudio(data: audioData, cardId: card.id)
            return
        }

        // 2) Fallback: English TTS (phrase or title)
        let textToSpeak = card.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? card.title
        : card.phrase

        speakEnglish(textToSpeak)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func playRecordedAudio(data: Data, cardId: UUID) {
        // Lock for duration so kids can’t spam replay
        do {
            let temp = try AVAudioPlayer(data: data)
            let duration = max(0.25, temp.duration)
            playbackGate.lockFor(seconds: duration)
        } catch {
            playbackGate.lockFor(seconds: 1.0)
        }

        audioPlayer.play(data: data, for: cardId)
    }

    private func speakEnglish(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Lock until speech finishes (delegate unlocks)
        playbackGate.lockIndefinitely()

        if speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = 0.46 // kid-friendly
        utterance.pitchMultiplier = 1.0

        // Prefer Enhanced English (closest to “Siri-like” you can get via public APIs)
        if let enhanced = AVSpeechSynthesisVoice.speechVoices()
            .first(where: { $0.language == "en-US" && $0.quality == .enhanced }) {
            utterance.voice = enhanced
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        speech.speak(utterance)
    }
}

// MARK: - PlaybackGate (locks until audio/tts completes)

private final class PlaybackGate: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isLocked: Bool = false
    private var unlockWorkItem: DispatchWorkItem?

    func lockIndefinitely() {
        DispatchQueue.main.async {
            self.unlockWorkItem?.cancel()
            self.unlockWorkItem = nil
            self.isLocked = true
        }
    }

    func lockFor(seconds: TimeInterval) {
        DispatchQueue.main.async {
            self.unlockWorkItem?.cancel()
            self.isLocked = true

            let item = DispatchWorkItem { [weak self] in
                self?.isLocked = false
            }
            self.unlockWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
        }
    }

    private func unlock() {
        DispatchQueue.main.async {
            self.unlockWorkItem?.cancel()
            self.unlockWorkItem = nil
            self.isLocked = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        unlock()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        unlock()
    }
}

// MARK: - Card View

private struct CommsCardView: View {
    let card: CommsCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardVisual

            // ✅ No small emoji duplicate below
            Text(card.title)
                .font(.headline)

            if !card.phrase.isEmpty {
                Text(card.phrase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var cardVisual: some View {
        if let emoji = trimmedEmoji {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 100)
                .overlay(
                    Text(emoji)
                        .font(.system(size: 52))
                )
        } else if let data = card.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 100)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var trimmedEmoji: String? {
        guard let emoji = card.emoji?.trimmingCharacters(in: .whitespacesAndNewlines),
              !emoji.isEmpty else {
            return nil
        }
        return emoji
    }
}

// MARK: - Editor

private struct CommsCardEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var phrase: String
    @State private var emoji: String
    @State private var imageData: Data?
    @State private var audioData: Data?

    @StateObject private var recorder = AudioRecorder()
    @State private var showingImagePicker = false

    private let card: CommsCard?
    private let onSave: ((CommsCard) -> Void)?
    private let ownerUserId: String

    init(ownerUserId: String, card: CommsCard?, onSave: ((CommsCard) -> Void)? = nil) {
        self.ownerUserId = ownerUserId
        self.card = card
        self.onSave = onSave

        _title = State(initialValue: card?.title ?? "")
        _phrase = State(initialValue: card?.phrase ?? "")
        _emoji = State(initialValue: card?.emoji ?? "")
        _imageData = State(initialValue: card?.imageData)
        _audioData = State(initialValue: card?.audioData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Core") {
                    TextField("Title", text: $title)
                    TextField("Phrase (optional)", text: $phrase, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Emoji (optional)", text: $emoji)
                }

                Section("Image") {
                    if let data = imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                    } else {
                        Text("No image selected")
                            .foregroundStyle(.secondary)
                    }
                    Button("Pick Image") {
                        showingImagePicker = true
                    }
                }

                Section("Audio") {
                    HStack {
                        Button(recorder.isRecording ? "Stop Recording" : "Record") {
                            if recorder.isRecording {
                                recorder.stopRecording()
                                audioData = recorder.lastRecordingData
                            } else {
                                recorder.startRecording()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Play") {
                            recorder.play(data: audioData)
                        }
                        .disabled(audioData == nil)
                    }
                }
            }
            .navigationTitle(card == nil ? "New Card" : "Edit Card")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalEmoji = trimmedEmoji.isEmpty ? nil : trimmedEmoji

                        if let card {
                            card.title = title
                            card.phrase = phrase
                            card.emoji = finalEmoji
                            card.imageData = imageData
                            card.audioData = audioData

                            // English-only: keep language empty
                            card.language = ""
                        } else {
                            let newCard = CommsCard(
                                ownerUserId: ownerUserId,
                                title: title,
                                phrase: phrase,
                                language: "", // English-only
                                emoji: finalEmoji,
                                imageData: imageData,
                                audioData: audioData
                            )
                            onSave?(newCard)
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(imageData: $imageData)
            }
        }
    }
}

#Preview {
    CommsView(ownerUserId: SampleData.previewUserId)
        .modelContainer(SampleData.makeContainer())
        .environmentObject(AuthManager())
}
