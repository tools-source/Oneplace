import SwiftData
import SwiftUI

struct CommsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CommsCard.title) private var cards: [CommsCard]

    @State private var showingEditor = false
    @State private var editingCard: CommsCard?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(cards) { card in
                        CommsCardView(card: card)
                            .onTapGesture {
                                editingCard = card
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
                CommsCardEditor(card: card)
            }
            .sheet(isPresented: $showingEditor) {
                CommsCardEditor(card: nil) { newCard in
                    modelContext.insert(newCard)
                }
            }
        }
    }
}

private struct CommsCardView: View {
    let card: CommsCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = card.imageData, let image = UIImage(data: data) {
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
            HStack {
                Text(card.title)
                    .font(.headline)
                Spacer()
                if let emoji = card.emoji {
                    Text(emoji)
                }
            }
            Text(card.phrase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(card.language)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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

    init(card: CommsCard?, onSave: ((CommsCard) -> Void)? = nil) {
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
                    TextField("Phrase", text: $phrase, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Language", text: $language)
                    TextField("Emoji", text: $emoji)
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
                        if let card {
                            card.title = title
                            card.phrase = phrase
                            card.language = language
                            card.emoji = emoji.isEmpty ? nil : emoji
                            card.imageData = imageData
                            card.audioData = audioData
                        } else {
                            let newCard = CommsCard(title: title, phrase: phrase, language: language, emoji: emoji.isEmpty ? nil : emoji, imageData: imageData, audioData: audioData)
                            onSave?(newCard)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || phrase.isEmpty || language.isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(imageData: $imageData)
            }
        }
    }
}

#Preview {
    CommsView()
        .modelContainer(SampleData.makeContainer())
}
