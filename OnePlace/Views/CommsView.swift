import SwiftUI
import UIKit

struct CommsView: View {
    @StateObject private var vm = CommsViewModel()
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @EnvironmentObject private var aiAssistant: AIAssistantManager

    @State private var editingCard: ItemEditorDestination<CommsCardRecord>?
    @State private var deletingCard: CommsCardRecord?
    @State private var inlineCardText = ""
    @State private var inlineCardError: String?
    @State private var inlineCardEmoji = "💬"
    @State private var searchText = ""
    @State private var lastRefreshToken: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var filteredCards: [CommsCardRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.cards }

        return vm.cards.filter { card in
            card.title.localizedCaseInsensitiveContains(query) ||
            card.phrase.localizedCaseInsensitiveContains(query)
        }
    }

    private var playableCardsCount: Int {
        vm.cards.filter { $0.audioData != nil || $0.hasAudio }.count
    }

    private var cardsNeedingAudioCount: Int {
        max(0, vm.cards.count - playableCardsCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    talkPulseCard

                    inlineCardAddRow

                    if vm.isLoading && vm.cards.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if filteredCards.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredCards) { card in
                                cardTile(for: card)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, DesignSystem.tabBarContentInset)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Talk")
            .searchable(text: $searchText, prompt: "Search cards and phrases")
            .refreshable { await vm.refresh() }
            .sheet(item: $editingCard) { destination in
                CommsCardEditorView(card: destination.item) { draft in
                    if let card = destination.item {
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
                        await vm.updateCard(updated)
                    } else {
                        await vm.addCard(draft: draft)
                    }
                    let error = vm.errorMessage
                    if error == nil, destination.item == nil {
                        searchText = ""
                    }
                    vm.errorMessage = nil
                    return error
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
            .onChange(of: aiAssistant.pendingActionsToken) { _, newToken in
                guard lastRefreshToken != newToken else { return }
                lastRefreshToken = newToken
                Task { await vm.refresh() }
            }
        }
    }

    private var commsErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil && editingCard == nil },
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
        EmptyState(
            title: "Voice Cards",
            message: "Create square talk cards with an emoji and a recorded voice message.",
            systemImage: "waveform",
            ctaTitle: nil
        )
    }

    private var talkPulseCard: some View {
        WorkspacePulseCard(
            title: "Talk Board",
            subtitle: talkPulseSubtitle,
            icon: playableCardsCount == vm.cards.count && !vm.cards.isEmpty ? "speaker.wave.2.fill" : "bubble.left.and.bubble.right.fill",
            tint: playableCardsCount == vm.cards.count && !vm.cards.isEmpty ? DesignSystem.gainColor : DesignSystem.accentColor,
            primaryValue: "\(vm.cards.count)",
            primaryLabel: "cards",
            secondaryValue: "\(playableCardsCount)",
            secondaryLabel: "playable",
            actionTitle: "Create"
        ) {
            inlineCardText = ""
        }
    }

    private var inlineCardAddRow: some View {
        InlineAddItemRow(
            text: $inlineCardText,
            placeholder: "New talk card phrase",
            systemImage: "plus.circle.fill",
            tint: DesignSystem.accentColor,
            isSaving: vm.isLoading,
            validationMessage: inlineCardError,
            onSubmit: saveInlineCard,
            onCancel: cancelInlineCardAdd
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["💬", "😊", "❤️", "🍽️", "💧", "🙋", "🏠"], id: \.self) { emoji in
                        Button { inlineCardEmoji = emoji } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 42, height: 42)
                                .background(inlineCardEmoji == emoji ? DesignSystem.accentSoft : Color.clear, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(emoji) for this card")
                        .accessibilityAddTraits(inlineCardEmoji == emoji ? .isSelected : [])
                    }
                }
                .padding(.leading, 40)
            }
        }
    }

    private var talkPulseSubtitle: String {
        if vm.cards.isEmpty {
            return "Create a card with a phrase, emoji, and optional voice recording."
        }

        if cardsNeedingAudioCount > 0 {
            return "\(cardsNeedingAudioCount) card\(cardsNeedingAudioCount == 1 ? "" : "s") could use a recording."
        }

        return "Every card is ready to play."
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
                    editingCard = .edit(card)
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

    private func handleSearchSubmit() {
        let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              OnePlacePromptClassifier.isCommand(prompt, in: .talk) else { return }

        let lowered = prompt.lowercased()
        if lowered.contains("delete") || lowered.contains("remove") || lowered.contains("erase") {
            aiAssistant.openChatFresh(area: .talk, voice: false)
            aiAssistant.userSaid(prompt)
            searchText = ""
            Task {
                _ = await OnePlaceAICommandExecutor.handleImmediateCommand(text: prompt, assistant: aiAssistant)
                await vm.refresh()
            }
            return
        }

        let draft = TalkPromptInterpreter.interpret(prompt)
        Task {
            await vm.addCard(draft: draft)
            await MainActor.run {
                searchText = ""
            }
        }
    }

    private func cancelInlineCardAdd() {
        inlineCardText = ""
        inlineCardError = nil
    }

    private func saveInlineCard() {
        let prompt = inlineCardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        var draft = TalkPromptInterpreter.interpret(prompt)
        draft.emoji = inlineCardEmoji
        Task {
            await vm.addCard(draft: draft)
            guard vm.errorMessage == nil else {
                inlineCardError = vm.errorMessage
                return
            }

            await MainActor.run {
                searchText = ""
                inlineCardText = ""
                inlineCardError = nil
                inlineCardEmoji = "💬"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

enum TalkPromptInterpreter {
    static func interpret(_ prompt: String) -> CommsCardDraft {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = phraseText(from: trimmed)

        return CommsCardDraft(
            title: title(from: trimmed, phrase: phrase),
            phrase: phrase,
            emoji: emoji(for: trimmed),
            hasImage: false,
            hasAudio: false,
            audioData: nil
        )
    }

    private static func phraseText(from prompt: String) -> String {
        let cleaned = prompt
            .replacingOccurrences(of: #"(?i)^(add|create|make)\s+(?:a\s+)?(?:talk\s+)?(?:card\s+)?(?:that\s+says\s+|saying\s+)?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? prompt : cleaned
    }

    private static func title(from prompt: String, phrase: String) -> String {
        let words = phrase.split(whereSeparator: \.isWhitespace).prefix(4)
        guard !words.isEmpty else { return "Talk Card" }
        return words.joined(separator: " ")
    }

    private static func emoji(for prompt: String) -> String {
        let lowered = prompt.lowercased()
        if lowered.contains("help") { return "🆘" }
        if lowered.contains("food") || lowered.contains("hungry") { return "🍽️" }
        if lowered.contains("water") || lowered.contains("drink") { return "💧" }
        if lowered.contains("happy") || lowered.contains("thank") { return "😊" }
        if lowered.contains("sad") || lowered.contains("hurt") { return "💙" }
        return "💬"
    }
}

private struct CommsCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var saveError: String?

    @StateObject private var audioRecorder = AudioRecorder()

    @State private var title: String
    @State private var phrase: String
    @State private var emoji: String
    @State private var emojiSearchText: String
    @State private var recordingData: Data?

    private let card: CommsCardRecord?
    private let onSave: (CommsCardDraft) async -> String?

    init(card: CommsCardRecord?, onSave: @escaping (CommsCardDraft) async -> String?) {
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
                    CreationGuideCard(
                        title: card == nil ? "Create Talk Card" : "Update Talk Card",
                        subtitle: "Cards can be text-only or include a voice recording. Add an emoji so the card is easy to recognize at a glance.",
                        icon: recordingData == nil ? "bubble.left.and.bubble.right.fill" : "speaker.wave.2.fill",
                        tint: recordingData == nil ? DesignSystem.accentColor : DesignSystem.gainColor,
                        status: recordingData == nil ? "Text ready" : "Audio ready"
                    )

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
            .navigationBarTitleDisplayMode(.inline)
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isSaving || audioRecorder.isRecording)
            .disabled(isSaving)
            .overlay {
                if isSaving { ProgressView("Saving…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
            }
            .alert("Couldn’t save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again. Your entries are still here.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        }
                        dismiss()
                    }
                    .disabled(isSaving || audioRecorder.isRecording)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(card == nil ? "Add" : "Save") {
                        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedTitle = normalizedTitle(phrase: trimmedPhrase)
                        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)

                        let draft = CommsCardDraft(
                            title: trimmedTitle,
                            phrase: trimmedPhrase,
                            emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
                            hasImage: card?.hasImage ?? false,
                            hasAudio: recordingData != nil,
                            audioData: recordingData
                        )

                        isSaving = true
                        Task {
                            saveError = await onSave(draft)
                            isSaving = false
                            if saveError == nil {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving || isSaveDisabled)
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
        audioRecorder.isRecording || normalizedTitle(phrase: phrase.trimmingCharacters(in: .whitespacesAndNewlines)).isEmpty ||
        (phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && recordingData == nil)
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

                            Text(recordingData == nil ? "Optional. Record audio if the card should play a voice message." : "Recording saved and ready to preview.")
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

    private func normalizedTitle(phrase: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return String(phrase.prefix(32)).trimmingCharacters(in: .whitespacesAndNewlines)
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
