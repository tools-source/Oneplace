import SwiftUI

struct CommsView: View {
    @StateObject private var vm = CommsViewModel()
    @StateObject private var audioPlayer = AudioPlayerManager.shared

    @State private var showingEditor = false
    @State private var editingCard: CommsCardRecord?
    @State private var deletingCard: CommsCardRecord?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if vm.isLoading && vm.cards.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if vm.cards.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(vm.cards) { card in
                                cardTile(for: card)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, DesignSystem.tabBarContentInset)
            }
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Talk")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                CommsCardEditorView(card: nil) { draft in
                    Task { await vm.addCard(draft: draft) }
                    showingEditor = false
                }
            }
            .sheet(item: $editingCard) { card in
                CommsCardEditorView(card: card) { draft in
                    let updated = CommsCardRecord(
                        id: card.id,
                        ownerUserId: card.ownerUserId,
                        title: draft.title,
                        phrase: draft.phrase,
                        emoji: draft.emoji,
                        hasImage: card.hasImage,
                        hasAudio: draft.audioData != nil || card.hasAudio,
                        audioData: draft.audioData ?? card.audioData
                    )
                    Task { await vm.updateCard(updated) }
                    editingCard = nil
                }
            }
            .alert("Delete Card?", isPresented: deletingCardBinding) {
                Button("Delete", role: .destructive) {
                    guard let deletingCard else { return }
                    Task { await vm.deleteCard(deletingCard) }
                    self.deletingCard = nil
                }
                Button("Cancel", role: .cancel) {
                    deletingCard = nil
                }
            } message: {
                Text("This removes the card and its recording.")
            }
            .alert("Talk Error", isPresented: commsErrorBinding) {
                Button("OK", role: .cancel) {
                    vm.errorMessage = nil
                }
            } message: {
                Text(vm.errorMessage ?? "Please try again.")
            }
            .task {
                await vm.refresh()
            }
        }
    }

    private var commsErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    vm.errorMessage = nil
                }
            }
        )
    }

    private var deletingCardBinding: Binding<Bool> {
        Binding(
            get: { deletingCard != nil },
            set: { isPresented in
                if !isPresented {
                    deletingCard = nil
                }
            }
        )
    }

    private var emptyState: some View {
        AppCard {
            VStack(spacing: 12) {
                ItemIconBadge(symbol: "waveform", tint: DesignSystem.accentColor, size: 52)

                Text("Voice Cards")
                    .font(.headline)

                Text("Create square talk cards with an emoji and a recorded voice message.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Create Card") {
                    showingEditor = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private func cardTile(for card: CommsCardRecord) -> some View {
        let isPlaying = audioPlayer.currentlyPlayingID == card.id
        let hasAudio = card.audioData != nil

        ZStack(alignment: .topTrailing) {
            Button {
                guard hasAudio else { return }
                audioPlayer.play(data: card.audioData, for: card.id)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(
                            isPlaying ? "Playing" : (hasAudio ? "Play" : "No audio"),
                            systemImage: isPlaying ? "waveform" : (hasAudio ? "play.fill" : "mic.slash")
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(hasAudio ? DesignSystem.accentColor : DesignSystem.secondaryTextColor)

                        Spacer()
                    }

                    Spacer(minLength: 0)

                    Text(displayEmoji(for: card))
                        .font(.system(size: 58))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.title)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !card.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(card.phrase)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        } else if hasAudio {
                            Text("Tap to play recording")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else {
                            Text("Add a recording to play")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                        .fill(isPlaying ? DesignSystem.highlightedCardGradient : DesignSystem.cardGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                        .strokeBorder(
                            isPlaying ? DesignSystem.accentColor.opacity(0.42) : DesignSystem.cardBorderColor,
                            lineWidth: 1.2
                        )
                )
                .shadow(color: DesignSystem.shadowColor.opacity(0.16), radius: DesignSystem.cardShadowRadius, x: 0, y: 10)
                .aspectRatio(1, contentMode: .fit)
                .opacity(hasAudio ? 1 : 0.82)
            }
            .buttonStyle(.plain)
            .disabled(isPlaying || !hasAudio)

            Menu {
                Button {
                    editingCard = card
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deletingCard = card
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.18))
                    )
            }
            .padding(10)
        }
    }

    private func displayEmoji(for card: CommsCardRecord) -> String {
        let trimmed = card.emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "💬" : trimmed
    }
}

private struct CommsCardEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var audioRecorder = AudioRecorder()

    @State private var title: String
    @State private var phrase: String
    @State private var emoji: String
    @State private var emojiSearchText: String
    @State private var recordingData: Data?

    private let card: CommsCardRecord?
    private let onSave: (CommsCardDraft) -> Void

    init(card: CommsCardRecord?, onSave: @escaping (CommsCardDraft) -> Void) {
        self.card = card
        self.onSave = onSave

        _title = State(initialValue: card?.title ?? "")
        _phrase = State(initialValue: card?.phrase ?? "")
        _emoji = State(initialValue: card?.emoji ?? "😊")
        _emojiSearchText = State(initialValue: "")
        _recordingData = State(initialValue: card?.audioData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    editorField(title: "Title") {
                        TextField("Card title", text: $title)
                            .textInputAutocapitalization(.words)
                    }

                    editorField(title: "Phrase") {
                        TextField("What should be spoken", text: $phrase, axis: .vertical)
                            .lineLimit(3...5)
                    }

                    recordingSection

                    emojiSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle(card == nil ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.large)
            .interactiveDismissDisabled(audioRecorder.isRecording)
            .onChange(of: audioRecorder.lastRecordingData) { _, newValue in
                guard let newValue else { return }
                recordingData = newValue
            }
            .onChange(of: title) { _, newValue in
                guard shouldAutoSelectEmoji else { return }
                if let first = emojiSuggestions(for: newValue).first {
                    emoji = first
                }
            }
            .alert("Recording Error", isPresented: recordingErrorBinding) {
                Button("OK", role: .cancel) {
                    audioRecorder.errorMessage = nil
                }
            } message: {
                Text(audioRecorder.errorMessage ?? "Please try again.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)

                        let draft = CommsCardDraft(
                            title: trimmedTitle,
                            phrase: trimmedPhrase,
                            emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
                            hasImage: card?.hasImage ?? false,
                            hasAudio: recordingData != nil,
                            audioData: recordingData
                        )

                        onSave(draft)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var shouldAutoSelectEmoji: Bool {
        let current = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty || current == "😊" || current == (card?.emoji ?? "")
    }

    private var recordingErrorBinding: Binding<Bool> {
        Binding(
            get: { audioRecorder.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    audioRecorder.errorMessage = nil
                }
            }
        )
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recordingData == nil
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recording")
                .font(.headline)

            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ItemIconBadge(
                            symbol: audioRecorder.isRecording ? "waveform.circle.fill" : "mic.fill",
                            tint: audioRecorder.isRecording ? DesignSystem.oweColor : DesignSystem.accentColor,
                            size: 48
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(audioRecorder.isRecording ? "Recording in progress" : "Voice message")
                                .font(.headline)

                            Text(recordingData == nil ? "Record the audio the card should play." : "Recording saved and ready to preview.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 10) {
                        Button(audioRecorder.isRecording ? "Stop Recording" : "Start Recording") {
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                            } else {
                                audioRecorder.startRecording()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(audioRecorder.isRecording ? DesignSystem.oweColor : DesignSystem.accentColor)

                        Button("Play") {
                            audioRecorder.play(data: recordingData)
                        }
                        .buttonStyle(.bordered)
                        .disabled(recordingData == nil || audioRecorder.isRecording)

                        Button("Clear") {
                            audioRecorder.clearRecording()
                            recordingData = nil
                        }
                        .buttonStyle(.bordered)
                        .disabled(recordingData == nil || audioRecorder.isRecording)
                    }
                }
            }
        }
    }

    private var emojiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Emoji")
                .font(.headline)

            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        Text(emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "💬" : emoji)
                            .font(.system(size: 56))
                            .frame(width: 82, height: 82)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(DesignSystem.accentSoft)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Suggested from title")
                                .font(.headline)

                            Text("Type in the title or search below to update the emoji options.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Search emoji", text: $emojiSearchText)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.primary.opacity(0.10))
                        )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 10)], spacing: 10) {
                        ForEach(emojiSuggestions, id: \.self) { suggestion in
                            Button {
                                emoji = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 30))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(emoji == suggestion ? DesignSystem.accentSoft : Color.primary.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                emoji == suggestion ? DesignSystem.accentColor.opacity(0.42) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var emojiSuggestions: [String] {
        emojiSuggestions(for: [title, emojiSearchText].joined(separator: " "))
    }

    private func emojiSuggestions(for query: String) -> [String] {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return EmojiLibrary.defaults
        }

        let matches = EmojiLibrary.entries.filter { entry in
            entry.keywords.contains { keyword in
                keyword.contains(normalized) || normalized.contains(keyword)
            }
        }

        let suggested = matches.map(\.emoji)
        let manualMatch = normalized.filter { !$0.isWhitespace }
        let base = manualMatch.isEmpty ? suggested : suggested
        let fallback = EmojiLibrary.defaults.filter { !suggested.contains($0) }
        return Array((base + fallback).prefix(12))
    }

    @ViewBuilder
    private func editorField<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            AppCard {
                content()
                    .font(.body)
                    .padding(.vertical, 4)
            }
        }
    }
}

private enum EmojiLibrary {
    struct Entry {
        let emoji: String
        let keywords: [String]
    }

    static let defaults = ["😊", "👋", "❤️", "🙏", "💬", "👍", "🎉", "😴"]

    static let entries: [Entry] = [
        Entry(emoji: "🚗", keywords: ["car", "drive", "vehicle", "ride", "travel"]),
        Entry(emoji: "🏠", keywords: ["home", "house", "room", "apartment"]),
        Entry(emoji: "🍔", keywords: ["food", "eat", "burger", "meal", "dinner", "lunch"]),
        Entry(emoji: "🥤", keywords: ["drink", "water", "juice", "soda", "thirsty"]),
        Entry(emoji: "😴", keywords: ["sleep", "bed", "nap", "tired", "rest"]),
        Entry(emoji: "🛁", keywords: ["bath", "shower", "wash", "clean"]),
        Entry(emoji: "❤️", keywords: ["love", "heart", "like", "care"]),
        Entry(emoji: "😊", keywords: ["happy", "smile", "good", "great", "yes"]),
        Entry(emoji: "😢", keywords: ["sad", "cry", "upset", "hurt"]),
        Entry(emoji: "😡", keywords: ["angry", "mad", "frustrated"]),
        Entry(emoji: "🧸", keywords: ["toy", "bear", "comfort"]),
        Entry(emoji: "💊", keywords: ["medicine", "pill", "medication", "doctor"]),
        Entry(emoji: "🩺", keywords: ["doctor", "health", "medical", "hospital"]),
        Entry(emoji: "📞", keywords: ["call", "phone", "contact"]),
        Entry(emoji: "💬", keywords: ["talk", "speak", "message", "say", "chat"]),
        Entry(emoji: "📚", keywords: ["school", "book", "study", "read", "learn"]),
        Entry(emoji: "🙏", keywords: ["pray", "thanks", "please", "grateful"]),
        Entry(emoji: "🎉", keywords: ["party", "celebrate", "fun", "birthday"]),
        Entry(emoji: "👋", keywords: ["hello", "hi", "bye", "wave"]),
        Entry(emoji: "👍", keywords: ["okay", "yes", "good", "approve"]),
        Entry(emoji: "👎", keywords: ["no", "bad", "dislike"]),
        Entry(emoji: "🧃", keywords: ["juice", "drink", "box"]),
        Entry(emoji: "🍎", keywords: ["apple", "fruit", "snack"]),
        Entry(emoji: "🎵", keywords: ["music", "song", "listen"]),
        Entry(emoji: "⚽", keywords: ["ball", "sport", "soccer", "play"]),
        Entry(emoji: "✈️", keywords: ["plane", "travel", "airport", "fly"]),
        Entry(emoji: "🛒", keywords: ["shop", "shopping", "store", "buy"]),
        Entry(emoji: "🐶", keywords: ["dog", "pet", "animal"]),
        Entry(emoji: "🐱", keywords: ["cat", "pet", "animal"]),
        Entry(emoji: "🎮", keywords: ["game", "gaming", "controller", "play"])
    ]
}
