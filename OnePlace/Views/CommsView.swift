import SwiftData
import SwiftUI
import UIKit

struct CommsView: View {
    let ownerUserId: String

    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CommsCard]

    @State private var showingEditor = false
    @State private var editingCard: CommsCard?
    @StateObject private var audioPlayer = AudioPlayerManager.shared

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
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(cards) { card in
                        CommsCardView(card: card)
                            .onTapGesture {
                                handleTap(for: card)
                            }
                            .contextMenu {
                                Button {
                                    editingCard = card
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                if card.audioData != nil {
                                    Button {
                                        audioPlayer.play(data: card.audioData, for: card.id)
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Comms")
            .toolbar {
                Button {
                    showingEditor = true
                } label: {
                    Label("New Card", systemImage: "plus")
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
        }
    }

    private func handleTap(for card: CommsCard) {
        guard let audioData = card.audioData else {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            return
        }
        audioPlayer.play(data: audioData, for: card.id)
    }
}

private struct CommsCardView: View {
    let card: CommsCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardVisual
            HStack {
                Text(card.title)
                    .font(.headline)
                Spacer()
                if let emoji = trimmedEmoji {
                    Text(emoji)
                }
            }
            if !card.phrase.isEmpty {
                Text(card.phrase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !card.language.isEmpty {
                Text(card.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct CommsCardEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var phrase: String
    @State private var language: String
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
        _language = State(initialValue: card?.language ?? "")
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
                    TextField("Language (optional)", text: $language)
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
                        if let card {
                            card.title = title
                            card.phrase = phrase
                            card.language = language
                            card.emoji = trimmedEmoji.isEmpty ? nil : trimmedEmoji
                            card.imageData = imageData
                            card.audioData = audioData
                        } else {
                            let newCard = CommsCard(
                                ownerUserId: ownerUserId,
                                title: title,
                                phrase: phrase,
                                language: language,
                                emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
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
