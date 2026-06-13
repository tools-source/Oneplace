import SwiftUI
import UIKit
import AVFoundation
import Speech
import FirebaseAuth

// MARK: - AI Area

enum AIArea: String, Sendable {
    case finance, flow, organizer, split, talk, settings
}

// MARK: - AI Message

struct AIMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date

    init(text: String, isFromUser: Bool) {
        self.id = UUID()
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = Date()
    }
}

// MARK: - Pending Draft (cross-area)

enum AIPendingDraft: Sendable {
    case task(TaskItemDraft)
    case expense(SplitExpenseDraft)
    case flow(FlowItemDraft)
}

// MARK: - Missing Field

enum AIMissingField: String, Sendable {
    case dueDate
    case time
    case amount
    case participants
    case title
}

// MARK: - AI Assistant Manager

@MainActor
final class AIAssistantManager: NSObject, ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var isChatOpen: Bool = false
    @Published var isVoiceModeOpen: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var isThinking: Bool = false
    @Published var ttsEnabled: Bool = true
    @Published var voiceMode: Bool = false
    @Published var currentArea: AIArea = .organizer
    @Published var pendingDraft: AIPendingDraft? = nil
    @Published var missingFields: [AIMissingField] = []
    @Published var contextPeople: [SplitPersonRecord] = []
    @Published var pendingActionsToken: UUID = UUID()

    let synthesizer = AVSpeechSynthesizer()
    var onSpeechFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Public API

    func openChatFresh(area: AIArea, voice: Bool = false) {
        currentArea = area
        voiceMode = voice
        messages.removeAll()
        pendingDraft = nil
        missingFields = []
        ClaudeAIChatResponder.resetConversation()
        isChatOpen = true
    }

    func openVoiceMode(area: AIArea) {
        currentArea = area
        voiceMode = true
        isChatOpen = false
        stopSpeaking()
        isVoiceModeOpen = true
    }

    func toggleChat() {
        if isChatOpen {
            isChatOpen = false
            stopSpeaking()
        } else {
            isChatOpen = true
        }
    }

    func userSaid(_ text: String) {
        messages.append(AIMessage(text: text, isFromUser: true))
    }

    func assistantSay(_ text: String, speak: Bool? = nil) {
        messages.append(AIMessage(text: text, isFromUser: false))
        let shouldSpeak = speak ?? ((voiceMode || isVoiceModeOpen) && ttsEnabled)
        if shouldSpeak {
            speakNow(text)
        }
    }

    func resetConversation() {
        messages.removeAll()
        pendingDraft = nil
        missingFields = []
        ClaudeAIChatResponder.resetConversation()
        stopSpeaking()
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    func configureAudioForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // best-effort
        }
    }

    func configureAudioForPlayAndRecord() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // best-effort
        }
    }

    func speakNow(_ text: String) {
        guard ttsEnabled, !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Ensure audio plays even if recognizer left session in record-only mode
        if isVoiceModeOpen {
            configureAudioForPlayAndRecord()
        } else {
            configureAudioForPlayback()
        }

        let utterance = AVSpeechUtterance(string: text)
        let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zoe")
            ?? AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Samantha")
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.voice = voice
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }
}

extension AIAssistantManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onSpeechFinished?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onSpeechFinished?()
        }
    }
}

// MARK: - Root Tab

private enum RootTab: String, CaseIterable, Identifiable {
    case finance
    case flow
    case organizer
    case split
    case talk
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finance:   return "Finance"
        case .flow:      return "Flow"
        case .organizer: return "Tasks"
        case .split:     return "Split"
        case .talk:      return "Talk"
        case .settings:  return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .finance:   return "dollarsign.circle"
        case .flow:      return "calendar.badge.clock"
        case .organizer: return "checklist"
        case .split:     return "person.2"
        case .talk:      return "bubble.left.and.bubble.right"
        case .settings:  return "gearshape"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .finance:   return "dollarsign.circle.fill"
        case .flow:      return "calendar.badge.clock"
        case .organizer: return "checklist"
        case .split:     return "person.2.fill"
        case .talk:      return "bubble.left.and.bubble.right.fill"
        case .settings:  return "gearshape.fill"
        }
    }

    var aiArea: AIArea {
        switch self {
        case .finance:   return .finance
        case .flow:      return .flow
        case .organizer: return .organizer
        case .split:     return .split
        case .talk:      return .talk
        case .settings:  return .settings
        }
    }
}

// MARK: - Root Tab View

struct RootTabView: View {
    let ownerUserId: String

    @AppStorage("root.selectedTab") private var selectedTabValue = RootTab.finance.rawValue
    @StateObject private var aiAssistant = AIAssistantManager()

    init(ownerUserId: String) {
        self.ownerUserId = ownerUserId
        configureNavigationBarAppearance()
    }

    var body: some View {
        ZStack {
            currentTabView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomNavigationBar
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .background(Color.clear)
                }

            if !aiAssistant.isChatOpen {
                FloatingAIButton()
                    .environmentObject(aiAssistant)
                    .ignoresSafeArea(.keyboard)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: aiAssistant.isChatOpen)
        .environmentObject(aiAssistant)
        .sheet(isPresented: $aiAssistant.isChatOpen, onDismiss: {
            aiAssistant.resetConversation()
        }) {
            AIChatSheet()
                .environmentObject(aiAssistant)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(.regularMaterial)
        }
        .fullScreenCover(isPresented: $aiAssistant.isVoiceModeOpen, onDismiss: {
            aiAssistant.resetConversation()
        }) {
            VoiceConversationView()
                .environmentObject(aiAssistant)
        }
        .onChange(of: selectedTabValue) { _, newValue in
            if let tab = RootTab(rawValue: newValue) {
                aiAssistant.currentArea = tab.aiArea
            }
        }
        .onAppear {
            if let tab = RootTab(rawValue: selectedTabValue) {
                aiAssistant.currentArea = tab.aiArea
            }

            let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
            let plistKey = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String ?? ""
            let apiKey = envKey.isEmpty ? plistKey : envKey
            print("[OnePlace] ANTHROPIC_API_KEY source: \(envKey.isEmpty ? "Info.plist" : "env") | length: \(apiKey.count)")
            if !apiKey.isEmpty {
                ClaudeAIChatResponder.initialize(apiKey: apiKey)
            } else {
                print("[OnePlace] ⚠️ ANTHROPIC_API_KEY not set — AI will use pattern-based fallback")
            }
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .finance:   FinanceView()
        case .flow:      FlowView()
        case .organizer: OrganizerView()
        case .split:     SplitView()
        case .talk:      CommsView()
        case .settings:  SettingsView()
        }
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: DesignSystem.shadowColor.opacity(0.22), radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
        )
    }

    private func tabButton(for tab: RootTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            guard !isSelected else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            select(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 20)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(tab.title)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .foregroundStyle(
                isSelected
                    ? DesignSystem.accentColor
                    : DesignSystem.secondaryTextColor
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(DesignSystem.accentSoft)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(DesignSystem.accentColor.opacity(0.22), lineWidth: 1)
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedTab: RootTab {
        RootTab(rawValue: selectedTabValue) ?? .finance
    }

    private func select(_ tab: RootTab) {
        selectedTabValue = tab.rawValue
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

// MARK: - Floating AI Button

struct FloatingAIButton: View {
    @EnvironmentObject private var assistant: AIAssistantManager
    @AppStorage("ai.floatingButton.xRatio") private var savedXRatio: Double = 0.88
    @AppStorage("ai.floatingButton.yRatio") private var savedYRatio: Double = 0.78

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var pulseOn: Bool = false
    @State private var ringOn: Bool = false

    private let buttonSize: CGFloat = 48

    var body: some View {
        GeometryReader { proxy in
            let bounds = proxy.size
            let safeBounds = CGSize(
                width: max(bounds.width - buttonSize, 1),
                height: max(bounds.height - buttonSize - 140, 1)
            )

            let basePoint = CGPoint(
                x: CGFloat(savedXRatio) * safeBounds.width + buttonSize / 2,
                y: CGFloat(savedYRatio) * safeBounds.height + buttonSize / 2
            )

            buttonContent
                .frame(width: buttonSize, height: buttonSize)
                .position(
                    x: basePoint.x + dragOffset.width,
                    y: basePoint.y + dragOffset.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            isDragging = true
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            let endPoint = CGPoint(
                                x: basePoint.x + value.translation.width,
                                y: basePoint.y + value.translation.height
                            )

                            let clampedX = min(max(endPoint.x, buttonSize / 2), bounds.width - buttonSize / 2)
                            let clampedY = min(max(endPoint.y, 90 + buttonSize / 2), bounds.height - 140 - buttonSize / 2)

                            let snapX = clampedX < bounds.width / 2
                                ? buttonSize / 2 + 12
                                : bounds.width - buttonSize / 2 - 12

                            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                                let newXRatio = (snapX - buttonSize / 2) / safeBounds.width
                                let newYRatio = (clampedY - buttonSize / 2) / safeBounds.height
                                savedXRatio = Double(min(max(newXRatio, 0), 1))
                                savedYRatio = Double(min(max(newYRatio, 0), 1))
                                dragOffset = .zero
                                isDragging = false
                            }

                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                )
                .onTapGesture {
                    if !isDragging {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if assistant.isChatOpen {
                            assistant.isChatOpen = false
                        } else {
                            if assistant.messages.isEmpty {
                                assistant.openChatFresh(area: assistant.currentArea, voice: false)
                                assistant.assistantSay(welcomeMessage(for: assistant.currentArea))
                            } else {
                                assistant.isChatOpen = true
                            }
                        }
                    }
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulseOn = true
            }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                ringOn = true
            }
        }
    }

    private var buttonContent: some View {
        ZStack {
            // Outer expanding rings (when speaking)
            if assistant.isSpeaking {
                Circle()
                    .stroke(DesignSystem.accentColor.opacity(ringOn ? 0 : 0.5), lineWidth: 2)
                    .scaleEffect(ringOn ? 1.6 : 1.0)
                    .frame(width: buttonSize, height: buttonSize)
                Circle()
                    .stroke(DesignSystem.secondaryAccent.opacity(ringOn ? 0 : 0.35), lineWidth: 2)
                    .scaleEffect(ringOn ? 1.9 : 1.0)
                    .frame(width: buttonSize, height: buttonSize)
            }

            // Soft glow (subtle)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignSystem.accentColor.opacity(0.28),
                            DesignSystem.accentColor.opacity(0)
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: pulseOn ? 32 : 26
                    )
                )
                .blur(radius: 6)
                .frame(width: buttonSize * 1.25, height: buttonSize * 1.25)

            // Main gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.accentColor,
                            DesignSystem.secondaryAccent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: DesignSystem.accentColor.opacity(0.35), radius: 10, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)

            // Sparkle icon
            Image(systemName: assistant.isSpeaking ? "waveform" : "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                .scaleEffect(pulseOn ? 1.05 : 0.95)
        }
    }

    private func welcomeMessage(for area: AIArea) -> String {
        switch area {
        case .finance:   return "Hi! I'm OnePlace. What would you like to add to Finance?"
        case .flow:      return "Hi! Want me to add a bill or income to Flow?"
        case .organizer: return "Hi! What task would you like to create?"
        case .split:     return "Hi! Want me to add a person or split an expense?"
        case .talk:      return "Hi! Want me to create a Talk card for you?"
        case .settings:  return "Hi! How can I help?"
        }
    }
}

// MARK: - AI Chat Sheet

struct AIChatSheet: View {
    @EnvironmentObject private var assistant: AIAssistantManager
    @Environment(\.dismiss) private var dismiss
    @State private var userInput: String = ""
    @StateObject private var speechRecognizer = FinanceSpeechRecognizer()

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            messagesScroll

            if assistant.isThinking {
                typingIndicator
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            inputBar
        }
        .background(
            ZStack {
                DesignSystem.backgroundGradient
                LinearGradient(
                    colors: [
                        DesignSystem.accentColor.opacity(0.06),
                        Color.clear,
                        DesignSystem.secondaryAccent.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.accentColor, DesignSystem.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: DesignSystem.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("OnePlace AI")
                    .font(.system(size: 17, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(assistant.isSpeaking ? DesignSystem.accentColor : .secondary)
                    .animation(.default, value: assistant.isSpeaking)
            }

            Spacer()

            headerResetButton
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignSystem.cardBorderColor)
                        .frame(height: 0.5)
                }
        )
    }

    private var headerResetButton: some View {
        Button {
            assistant.resetConversation()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(Color.gray.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear conversation")
    }

    private var statusText: String {
        if assistant.isSpeaking { return "Speaking…" }
        if assistant.isThinking { return "Thinking…" }
        switch assistant.currentArea {
        case .finance:   return "Finance assistant"
        case .flow:      return "Flow assistant"
        case .organizer: return "Tasks assistant"
        case .split:     return "Split assistant"
        case .talk:      return "Talk assistant"
        case .settings:  return "Assistant"
        }
    }

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if assistant.messages.isEmpty {
                        emptyStateCard
                            .padding(.top, 20)
                    }

                    ForEach(assistant.messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.85, anchor: msg.isFromUser ? .bottomTrailing : .bottomLeading)
                                        .combined(with: .opacity)
                                        .combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: assistant.messages.count) { _, _ in
                guard let last = assistant.messages.last else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.accentColor.opacity(0.18),
                                DesignSystem.secondaryAccent.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.accentColor, DesignSystem.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("How can I help?")
                .font(.system(size: 22, weight: .bold))

            Text(emptyStateSubtitle)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            quickSuggestions
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var emptyStateSubtitle: String {
        switch assistant.currentArea {
        case .finance:   return "Tell me about an income or expense and I'll handle the rest."
        case .flow:      return "Tell me about a bill or recurring income and I'll set it up."
        case .organizer: return "Tell me what you need to do and I'll create a task."
        case .split:     return "Tell me about a shared expense or someone to add."
        case .talk:      return "Tell me what to say on a Talk card."
        case .settings:  return "Ask me anything about your account or app."
        }
    }

    private var quickSuggestions: some View {
        let suggestions = suggestionList(for: assistant.currentArea)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        userInput = suggestion
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.accentColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(DesignSystem.accentSoft)
                            )
                            .overlay(
                                Capsule().strokeBorder(DesignSystem.accentColor.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func suggestionList(for area: AIArea) -> [String] {
        switch area {
        case .finance:   return ["I spent $20 on lunch", "Got $1000 from work", "Add $50 gas"]
        case .flow:      return ["Rent $1500 monthly", "Netflix $15 monthly", "Salary $5000"]
        case .organizer: return ["Call John tomorrow", "Buy groceries", "Meeting next week"]
        case .split:     return ["Add John", "Split $50 dinner", "Add Sarah"]
        case .talk:      return ["I need water", "Make a yes card", "Help me"]
        case .settings:  return ["Sign out", "Change theme", "Privacy"]
        }
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                TypingDot(delay: 0)
                TypingDot(delay: 0.2)
                TypingDot(delay: 0.4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 0.5)
            )

            Spacer()
        }
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: 7) {
            Button(action: toggleMicCapture) {
                Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(speechRecognizer.isRecording ? DesignSystem.oweColor : DesignSystem.accentColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(speechRecognizer.isRecording ? DesignSystem.oweColor.opacity(0.16) : DesignSystem.accentSoft)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speechRecognizer.isRecording ? "Stop dictation" : "Start dictation")

            TextField("Message OnePlace", text: $userInput, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .padding(.horizontal, 4)
                .padding(.vertical, 10)
                .onSubmit { send() }

            composerIconButton(
                systemImage: "waveform",
                accessibilityLabel: "Open voice mode",
                isProminent: true
            ) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                assistant.openVoiceMode(area: assistant.currentArea)
            }

            sendButton
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignSystem.cardBorderColor)
                .frame(height: 0.5)
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            guard speechRecognizer.isRecording else { return }
            userInput = newValue
        }
        .onChange(of: speechRecognizer.isRecording) { oldValue, newValue in
            guard oldValue, !newValue else { return }
            let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else { return }
            userInput = transcript
            assistant.voiceMode = true
            send()
        }
    }

    private var sendButton: some View {
        Button(action: send) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.accentColor, DesignSystem.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: DesignSystem.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(userInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
        .accessibilityLabel("Send message")
    }

    private func composerIconButton(
        systemImage: String,
        accessibilityLabel: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(isProminent ? DesignSystem.accentColor : .secondary)
                .background(
                    Circle().fill(isProminent ? DesignSystem.accentSoft : Color.gray.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func send() {
        let text = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        userInput = ""
        assistant.userSaid(text)

        Task {
            await AIChatResponder.handleUserInput(text: text, assistant: assistant)
        }
    }

    private func toggleMicCapture() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            return
        }
        speechRecognizer.clearTranscript()
        Task { await speechRecognizer.startRecording() }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 40)
                bubbleBody(isUser: true)
            } else {
                aiAvatar
                bubbleBody(isUser: false)
                Spacer(minLength: 40)
            }
        }
    }

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.accentColor, DesignSystem.secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func bubbleBody(isUser: Bool) -> some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(isUser ? Color.white : DesignSystem.primaryTextColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isUser {
                            LinearGradient(
                                colors: [DesignSystem.accentColor, DesignSystem.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color.clear.background(.ultraThinMaterial)
                        }
                    }
                )
                .clipShape(BubbleShape(isUser: isUser))
                .overlay(
                    BubbleShape(isUser: isUser)
                        .stroke(
                            isUser
                                ? Color.white.opacity(0.18)
                                : DesignSystem.cardBorderColor,
                            lineWidth: isUser ? 1 : 0.5
                        )
                )
                .shadow(
                    color: isUser
                        ? DesignSystem.accentColor.opacity(0.22)
                        : Color.black.opacity(0.04),
                    radius: isUser ? 8 : 3,
                    x: 0,
                    y: isUser ? 4 : 1
                )

            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let bigRadius: CGFloat = 18
        let smallRadius: CGFloat = 6
        let topLeft = bigRadius
        let topRight = bigRadius
        let bottomLeft: CGFloat = isUser ? bigRadius : smallRadius
        let bottomRight: CGFloat = isUser ? smallRadius : bigRadius

        return Path { path in
            path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
            path.addArc(
                center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }
    }
}

// MARK: - Typing Dot

struct TypingDot: View {
    let delay: Double
    @State private var scale: CGFloat = 0.6

    var body: some View {
        Circle()
            .fill(DesignSystem.accentColor.opacity(0.7))
            .frame(width: 7, height: 7)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(delay)) {
                    scale = 1.1
                }
            }
    }
}

// MARK: - AI Chat Responder

@MainActor
enum AIChatResponder {
    static func handleUserInput(text: String, assistant: AIAssistantManager) async {
        if await OnePlaceAICommandExecutor.handleImmediateCommand(text: text, assistant: assistant) {
            return
        }

        if isBareNegative(text), assistant.pendingDraft == nil, assistant.missingFields.isEmpty {
            assistant.assistantSay("Okay, I won't change anything.")
            return
        }

        // 1. Try Claude AI if available for more intelligent handling
        if ClaudeAIChatResponder.isAvailable() {
            await ClaudeAIChatResponder.handleUserInput(text: text, assistant: assistant)
            return
        }

        assistant.isThinking = true
        try? await Task.sleep(nanoseconds: 120_000_000)
        defer { assistant.isThinking = false }

        // 2. Pending follow-up takes priority
        if let pending = assistant.pendingDraft, !assistant.missingFields.isEmpty {
            await continueConversation(text: text, pending: pending, assistant: assistant)
            return
        }

        // 3. Small-talk / conversational replies
        if let smallTalk = conversationalReply(for: text, area: assistant.currentArea) {
            assistant.assistantSay(smallTalk)
            return
        }

        // 4. Command routing by current area
        switch assistant.currentArea {
        case .organizer:
            await startTaskConversation(prompt: text, assistant: assistant)
        case .split:
            await startSplitConversation(prompt: text, assistant: assistant)
        case .flow:
            await startFlowConversation(prompt: text, assistant: assistant)
        case .finance:
            await startFinanceConversation(prompt: text, assistant: assistant)
        case .talk:
            assistant.assistantSay("I can help you make a Talk card. Just tell me what it should say — for example, 'create a card that says I need water.'")
        case .settings:
            assistant.assistantSay("I can help you sign out, switch the theme, or open Help. What would you like to do?")
        }
    }

    // MARK: Conversational layer

    private static func conversationalReply(for raw: String, area: AIArea) -> String? {
        let text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let words = text.split(whereSeparator: { !$0.isLetter }).map(String.init)
        let firstWord = words.first ?? ""

        // Greetings
        let greetings: Set<String> = ["hi", "hello", "hey", "yo", "sup", "howdy", "hiya", "heya"]
        if greetings.contains(firstWord) || text == "good morning" || text == "good afternoon" || text == "good evening" {
            return "\(greetingPrefix(text)) I'm OnePlace. \(areaCapabilitySentence(area))"
        }

        // Identity
        if text.contains("who are you") || text.contains("what are you") ||
           text.contains("your name") || text.contains("what's your name") {
            return "I'm OnePlace AI — your personal assistant for tracking finances, bills, tasks, splits, and talk cards. \(areaCapabilitySentence(area))"
        }

        // Capabilities / help
        if text.contains("what can you do") || text == "help" || text == "?" ||
           text.contains("how do you") || text.contains("how does this work") ||
           text.contains("what do you do") {
            return capabilityOverview(area: area)
        }

        // Thanks
        if text.contains("thank") || text == "ty" || text == "thx" {
            return "You're welcome! Want to add anything else?"
        }

        // How are you
        if text.contains("how are you") || text.contains("how's it going") || text.contains("how r u") {
            return "I'm doing great — ready to help. \(areaCapabilitySentence(area))"
        }

        // Goodbye
        if firstWord == "bye" || text.contains("goodbye") || text == "cya" || text == "see you" {
            return "Anytime — just tap the sparkle whenever you need me. 👋"
        }

        return nil
    }

    private static func greetingPrefix(_ text: String) -> String {
        if text.contains("morning") { return "Good morning!" }
        if text.contains("afternoon") { return "Good afternoon!" }
        if text.contains("evening") { return "Good evening!" }
        return "Hey!"
    }

    private static func areaCapabilitySentence(_ area: AIArea) -> String {
        switch area {
        case .finance:
            return "On Finance I can log incomes or expenses for you — try 'I spent $20 on lunch'."
        case .flow:
            return "On Flow I can set up bills or recurring income — try 'rent $1500 monthly'."
        case .organizer:
            return "On Tasks I can create a to-do — try 'remind me to call John tomorrow at 10am'."
        case .split:
            return "On Split I can add people or shared expenses — try 'add Sarah' or 'split $50 dinner with Sarah'."
        case .talk:
            return "On Talk I can make communication cards — try 'card that says I need water'."
        case .settings:
            return "Ask me anything about your account."
        }
    }

    private static func capabilityOverview(area: AIArea) -> String {
        switch area {
        case .finance:
            return "I can log incomes or expenses for you. Try things like:\n• 'I spent $20 on lunch'\n• 'Got $1000 from work'\n• 'Add $50 gas'"
        case .flow:
            return "I can manage your bills and recurring income. Try:\n• 'Rent $1500 monthly'\n• 'Salary $5000 biweekly'\n• 'Netflix $15 monthly'"
        case .organizer:
            return "I can create tasks with due dates and reminders. Try:\n• 'Call John tomorrow at 10am'\n• 'Buy groceries on Saturday'\n• 'Meeting next week'"
        case .split:
            return "I can add people and split expenses. Try:\n• 'Add Sarah'\n• 'Split $50 dinner with Sarah and John'\n• 'Add expense $80 paid by Mom'"
        case .talk:
            return "I can build communication cards. Try:\n• 'Card that says I need water'\n• 'Make a yes card'"
        case .settings:
            return "I can help you sign out, switch themes, or open Help."
        }
    }

    // MARK: Finance

    private static func startFinanceConversation(prompt: String, assistant: AIAssistantManager) async {
        let interpreter = FinanceAIInterpreter()
        let result = await interpreter.interpret(
            prompt: prompt,
            fallbackCategory: "Other Expense",
            now: .now,
            timeZone: .autoupdatingCurrent
        )

        let interpretation: FinancePromptInterpretation
        switch result {
        case .success(let value):
            interpretation = value
        case .failure:
            guard let fallback = FinancePromptInterpreter.interpret(prompt, fallbackCategory: "Other Expense", now: .now) else {
                assistant.assistantSay("I couldn't quite understand. Try something like 'I spent $20 on lunch' or 'got $1000 from work'.")
                return
            }
            interpretation = fallback
        }

        guard interpretation.draft.amount > 0 else {
            assistant.assistantSay("How much was it? You can say something like '$20' or '50 dollars'.")
            return
        }

        do {
            let uid = try AIAuth.requireUID()
            let record = try await FinanceRepository().createEntry(for: uid, draft: interpretation.draft)
            assistant.assistantSay("Done! Logged \(record.entryDescription) for $\(formatted(record.amount)). 💸")
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("Hmm, I couldn't save that: \(error.localizedDescription)")
        }
    }

    // MARK: Task

    private static func startTaskConversation(prompt: String, assistant: AIAssistantManager) async {
        var draft = OrganizerPromptInterpreter.interpret(prompt)

        // The interpreter always returns a date (today fallback). Detect whether the user
        // actually mentioned one so we can ask if missing.
        if !promptHasDate(prompt) {
            draft.dueDate = nil
            assistant.pendingDraft = .task(draft)
            assistant.missingFields = [.dueDate]
            assistant.assistantSay("When would you like '\(draft.title)' to happen?")
            return
        }

        assistant.pendingDraft = .task(draft)

        if !promptHasTime(prompt) {
            assistant.missingFields = [.time]
            let dateStr = draft.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "that day"
            assistant.assistantSay("Got it. What time on \(dateStr)?")
        } else {
            await commitTask(draft: draft, assistant: assistant)
        }
    }

    // MARK: Split

    private static func startSplitConversation(prompt: String, assistant: AIAssistantManager) async {
        if let names = SplitPromptInterpreter.personNames(from: prompt), !names.isEmpty {
            if let uid = try? AIAuth.requireUID() {
                let repository = SplitRepository()
                var existingNames = Set(((try? await repository.fetchPeople(for: uid)) ?? []).map { $0.name.lowercased() })
                var addedNames: [String] = []

                for name in names {
                    guard !existingNames.contains(name.lowercased()) else { continue }
                    _ = try? await repository.createPerson(for: uid, name: name)
                    existingNames.insert(name.lowercased())
                    addedNames.append(name)
                }
                assistant.assistantSay(
                    addedNames.isEmpty
                        ? "Those people are already in Split."
                        : "Added \(joinedNames(addedNames)) to Split."
                )
                assistant.pendingActionsToken = UUID()
            }
            return
        }

        let people = assistant.contextPeople
        guard let draft = SplitPromptInterpreter.expenseDraft(from: prompt, people: people) else {
            if people.isEmpty {
                assistant.assistantSay("Add some people first, then I can split expenses between them.")
            } else {
                assistant.assistantSay("Tell me about the expense (e.g., 'dinner $40 with John').")
            }
            return
        }

        assistant.pendingDraft = .expense(draft)

        if draft.amount <= 0 {
            assistant.missingFields = [.amount]
            assistant.assistantSay("How much was '\(draft.title)'?")
        } else if draft.participantIds.isEmpty {
            assistant.missingFields = [.participants]
            assistant.assistantSay("Who was this split between?")
        } else {
            await commitExpense(draft: draft, assistant: assistant)
        }
    }

    // MARK: Flow

    private static func startFlowConversation(prompt: String, assistant: AIAssistantManager) async {
        guard let draft = FlowPromptInterpreter.interpret(prompt) else {
            assistant.assistantSay("Tell me about the bill or income (e.g., 'rent $1500 monthly').")
            return
        }
        assistant.pendingDraft = .flow(draft)

        if draft.amount <= 0 {
            assistant.missingFields = [.amount]
            assistant.assistantSay("How much is '\(draft.title)'?")
        } else if draft.frequency == .monthly && !promptContainsFrequency(prompt) {
            assistant.missingFields = [.dueDate]
            assistant.assistantSay("How often? (weekly, biweekly, monthly, quarterly, yearly)")
        } else {
            await commitFlow(draft: draft, assistant: assistant)
        }
    }

    private static func promptContainsFrequency(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return lowered.contains("weekly") || lowered.contains("biweekly") ||
               lowered.contains("monthly") || lowered.contains("quarterly") ||
               lowered.contains("yearly") || lowered.contains("annual") ||
               lowered.contains("every week") || lowered.contains("every month")
    }

    private static func isBareNegative(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^a-z\s]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ["no", "nope", "nah", "cancel", "never mind", "nevermind"].contains(normalized)
    }

    // MARK: Continue

    private static func continueConversation(text: String, pending: AIPendingDraft, assistant: AIAssistantManager) async {
        switch pending {
        case .task(var draft):
            await continueTask(text: text, draft: &draft, assistant: assistant)
        case .expense(var draft):
            await continueExpense(text: text, draft: &draft, assistant: assistant)
        case .flow(var draft):
            await continueFlow(text: text, draft: &draft, assistant: assistant)
        }
    }

    private static func continueTask(text: String, draft: inout TaskItemDraft, assistant: AIAssistantManager) async {
        if assistant.missingFields.contains(.dueDate) {
            if let newDate = extractDate(from: text) {
                draft.dueDate = newDate
                assistant.pendingDraft = .task(draft)
                assistant.missingFields = [.time]
                assistant.assistantSay("Got it. What time?")
            } else {
                assistant.assistantSay("Sorry, I didn't catch that date. Try 'tomorrow', 'Monday', or a specific day.")
            }
            return
        }
        if assistant.missingFields.contains(.time) {
            if let timeDate = extractTime(from: text), var dueDate = draft.dueDate {
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: timeDate)
                dueDate = cal.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: dueDate) ?? dueDate
                draft.dueDate = dueDate
                await commitTask(draft: draft, assistant: assistant)
            } else {
                assistant.assistantSay("Sorry, I didn't get the time. Try '10am' or '2:30 pm'.")
            }
        }
    }

    private static func continueExpense(text: String, draft: inout SplitExpenseDraft, assistant: AIAssistantManager) async {
        if assistant.missingFields.contains(.amount) {
            if let amount = parseAmount(from: text) {
                draft.amount = amount
                assistant.pendingDraft = .expense(draft)
                if draft.participantIds.isEmpty {
                    assistant.missingFields = [.participants]
                    assistant.assistantSay("Got it — $\(formatted(amount)). Who was it split between?")
                } else {
                    await commitExpense(draft: draft, assistant: assistant)
                }
            } else {
                assistant.assistantSay("Sorry, I didn't catch the amount. Try '$50' or '25.99'.")
            }
            return
        }
        if assistant.missingFields.contains(.participants) {
            let names = text.lowercased()
                .replacingOccurrences(of: " and ", with: ",")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let matched = assistant.contextPeople.filter { person in
                names.contains(where: { person.name.lowercased().contains($0) })
            }
            if !matched.isEmpty {
                draft.participantIds = matched.map(\.id)
                await commitExpense(draft: draft, assistant: assistant)
            } else {
                assistant.assistantSay("I couldn't find those people. Who should be on the split?")
            }
        }
    }

    private static func continueFlow(text: String, draft: inout FlowItemDraft, assistant: AIAssistantManager) async {
        if assistant.missingFields.contains(.amount) {
            if let amount = parseAmount(from: text) {
                draft.amount = amount
                assistant.pendingDraft = .flow(draft)
                assistant.missingFields = [.dueDate]
                assistant.assistantSay("How often? (weekly, biweekly, monthly, quarterly, yearly)")
            } else {
                assistant.assistantSay("Sorry, I didn't catch the amount. Try '$100' or '50'.")
            }
            return
        }
        if assistant.missingFields.contains(.dueDate) {
            if let frequency = extractFrequency(from: text) {
                draft.frequency = frequency
                await commitFlow(draft: draft, assistant: assistant)
            } else {
                assistant.assistantSay("Sorry, I didn't catch that. Try 'weekly', 'monthly', 'biweekly', 'quarterly', or 'yearly'.")
            }
        }
    }

    private static func extractFrequency(from text: String) -> FlowFrequency? {
        let lowered = text.lowercased()
        if lowered.contains("weekly") || lowered.contains("every week") { return .weekly }
        if lowered.contains("biweekly") || lowered.contains("every two weeks") { return .biweekly }
        if lowered.contains("quarterly") { return .quarterly }
        if lowered.contains("yearly") || lowered.contains("annual") || lowered.contains("every year") { return .yearly }
        if lowered.contains("monthly") || lowered.contains("every month") { return .monthly }
        return nil
    }

    // MARK: Commits

    private static func commitTask(draft: TaskItemDraft, assistant: AIAssistantManager) async {
        do {
            let uid = try AIAuth.requireUID()
            try await TaskRepository().createTask(for: uid, draft: draft)
            let dateStr = draft.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? "no date"
            assistant.assistantSay("Done! Created '\(draft.title)' for \(dateStr). ✨")
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("Hmm, I couldn't save that task: \(error.localizedDescription)")
        }
        assistant.pendingDraft = nil
        assistant.missingFields = []
    }

    private static func commitExpense(draft: SplitExpenseDraft, assistant: AIAssistantManager) async {
        do {
            let uid = try AIAuth.requireUID()
            _ = try await SplitRepository().createExpense(for: uid, draft: draft)
            assistant.assistantSay("Done! Recorded '\(draft.title)' for $\(formatted(draft.amount)). 🎉")
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("Hmm, I couldn't save that expense: \(error.localizedDescription)")
        }
        assistant.pendingDraft = nil
        assistant.missingFields = []
    }

    private static func commitFlow(draft: FlowItemDraft, assistant: AIAssistantManager) async {
        do {
            let uid = try AIAuth.requireUID()
            try await FlowRepository().createItem(for: uid, draft: draft)
            assistant.assistantSay("Done! Added '\(draft.title)' for $\(formatted(draft.amount)). 🎉")
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("Hmm, I couldn't save that: \(error.localizedDescription)")
        }
        assistant.pendingDraft = nil
        assistant.missingFields = []
    }

    // MARK: Helpers

    private static func promptHasTime(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return lowered.contains(":") || lowered.contains("am") || lowered.contains("pm") ||
               lowered.contains("morning") || lowered.contains("afternoon") || lowered.contains("evening") ||
               lowered.contains("noon") || lowered.contains("midnight")
    }

    private static func promptHasDate(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        let keywords = [
            "today", "tomorrow", "tonight", "yesterday", "next week", "next month",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "january", "february", "march", "april", "may", "june", "july",
            "august", "september", "october", "november", "december",
            "weekend", "this week"
        ]
        if keywords.contains(where: lowered.contains) { return true }

        // Detect dates via NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
            if detector.firstMatch(in: prompt, range: range) != nil {
                return true
            }
        }
        return false
    }

    private static func extractDate(from text: String) -> Date? {
        let lowered = text.lowercased()
        let today = Calendar.current.startOfDay(for: Date())
        if lowered.contains("today") { return today }
        if lowered.contains("tomorrow") { return Calendar.current.date(byAdding: .day, value: 1, to: today) }
        if lowered.contains("next week") { return Calendar.current.date(byAdding: .day, value: 7, to: today) }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector?.matches(in: text, range: range).first?.date
    }

    private static func extractTime(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector?.matches(in: text, range: range).first?.date
    }

    private static func parseAmount(from text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let direct = Double(cleaned) { return direct }
        let pattern = #"(\d+(?:\.\d{1,2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let r = Range(match.range(at: 1), in: text) {
                return Double(text[r])
            }
        }
        return nil
    }

    private static func formatted(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    private static func joinedNames(_ names: [String]) -> String {
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            return "\(names.dropLast().joined(separator: ", ")), and \(names.last ?? "")"
        }
    }
}

// MARK: - Voice Conversation View

struct VoiceConversationView: View {
    @EnvironmentObject private var assistant: AIAssistantManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recognizer = FinanceSpeechRecognizer()

    @State private var isListening: Bool = false
    @State private var lastTranscript: String = ""
    @State private var lastAIMessage: String = ""
    @State private var silenceTimer: Task<Void, Never>?
    @State private var pendingAutoListen: Bool = false

    private var voiceState: VoiceOrbState {
        if assistant.isSpeaking { return .speaking }
        if assistant.isThinking { return .thinking }
        if isListening { return .listening }
        return .idle
    }

    private var statusText: String {
        switch voiceState {
        case .listening: return "Listening…"
        case .thinking:  return "Thinking…"
        case .speaking:  return "Speaking…"
        case .idle:      return "Tap to speak"
        }
    }

    var body: some View {
        ZStack {
            // Cinematic dark background with subtle accent
            ZStack {
                Color.black
                RadialGradient(
                    colors: [
                        DesignSystem.accentColor.opacity(0.25),
                        DesignSystem.secondaryAccent.opacity(0.12),
                        Color.black.opacity(0)
                    ],
                    center: .center,
                    startRadius: 30,
                    endRadius: 600
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                Spacer()

                VoiceOrb(state: voiceState)
                    .frame(width: 240, height: 240)
                    .onTapGesture {
                        if assistant.isSpeaking {
                            assistant.stopSpeaking()
                        } else if isListening {
                            stopListening(submit: true)
                        } else {
                            startListening()
                        }
                    }

                Text(statusText)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 28)
                    .animation(.easeInOut(duration: 0.2), value: statusText)

                // Live transcript / last AI line
                Group {
                    if isListening && !recognizer.transcript.isEmpty {
                        Text(recognizer.transcript)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    } else if !lastAIMessage.isEmpty {
                        Text(lastAIMessage)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
                .padding(.top, 18)

                Spacer()

                bottomControls
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            assistant.isVoiceModeOpen = true
            assistant.voiceMode = true
            assistant.configureAudioForPlayAndRecord()

            // Greet if conversation is empty
            if assistant.messages.isEmpty {
                let intro = greetingForArea(assistant.currentArea)
                assistant.assistantSay(intro)
                lastAIMessage = intro
            } else if let last = assistant.messages.last(where: { !$0.isFromUser }) {
                lastAIMessage = last.text
                // If we open mid-conversation and last AI message hasn't been spoken, speak it
                if !assistant.isSpeaking {
                    assistant.speakNow(last.text)
                }
            }

            assistant.onSpeechFinished = {
                // Auto-resume listening after AI finishes
                if assistant.isVoiceModeOpen {
                    startListening()
                }
            }
        }
        .onDisappear {
            stopListening(submit: false)
            assistant.onSpeechFinished = nil
            assistant.isVoiceModeOpen = false
        }
        .onChange(of: assistant.messages.count) { _, _ in
            if let last = assistant.messages.last(where: { !$0.isFromUser }) {
                lastAIMessage = last.text
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                stopListening(submit: false)
                assistant.stopSpeaking()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.10)))
            }

            Spacer()

            Text("Voice mode")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.10)))

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                assistant.ttsEnabled.toggle()
                if !assistant.ttsEnabled { assistant.stopSpeaking() }
            } label: {
                Image(systemName: assistant.ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 24) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if isListening {
                    stopListening(submit: false)
                } else {
                    startListening()
                }
            } label: {
                Image(systemName: isListening ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(isListening ? DesignSystem.oweColor.opacity(0.85) : .white.opacity(0.15))
                    )
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                stopListening(submit: false)
                assistant.stopSpeaking()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
        }
    }

    private func startListening() {
        guard !isListening, !assistant.isSpeaking else { return }
        recognizer.clearTranscript()
        isListening = true
        Task { await recognizer.startRecording() }
        scheduleSilenceCheck()
    }

    private func stopListening(submit: Bool) {
        silenceTimer?.cancel()
        silenceTimer = nil
        guard isListening else { return }
        isListening = false
        recognizer.stopRecording()

        guard submit else { return }
        let transcript = recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            // Restart listening after a brief pause
            return
        }
        lastTranscript = transcript
        assistant.userSaid(transcript)
        Task {
            await AIChatResponder.handleUserInput(text: transcript, assistant: assistant)
        }
    }

    private func scheduleSilenceCheck() {
        silenceTimer?.cancel()
        silenceTimer = Task {
            var lastText = ""
            while !Task.isCancelled && isListening {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if Task.isCancelled { return }
                let current = recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !current.isEmpty && current == lastText {
                    // No new speech for 1.2s → submit
                    await MainActor.run { stopListening(submit: true) }
                    return
                }
                lastText = current
            }
        }
    }

    private func greetingForArea(_ area: AIArea) -> String {
        switch area {
        case .finance:   return "Hi! I'm OnePlace. What would you like to log in Finance?"
        case .flow:      return "Hi! What bill or income should I set up in Flow?"
        case .organizer: return "Hi! What task would you like me to add?"
        case .split:     return "Hi! Want to add a person or split an expense?"
        case .talk:      return "Hi! Tell me what your Talk card should say."
        case .settings:  return "Hi! How can I help with settings?"
        }
    }
}

// MARK: - Voice Orb

enum VoiceOrbState {
    case idle, listening, speaking, thinking
}

struct VoiceOrb: View {
    let state: VoiceOrbState

    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 0
    @State private var rotation3: Double = 0
    @State private var pulse: CGFloat = 0
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignSystem.accentColor.opacity(0.5),
                            DesignSystem.accentColor.opacity(0)
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 160 + pulse * 20
                    )
                )
                .blur(radius: 30)

            // Speaking rings
            if state == .speaking {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(DesignSystem.accentColor.opacity(0.55 - Double(i) * 0.15), lineWidth: 2)
                        .scaleEffect(ringScale + CGFloat(i) * 0.12)
                        .opacity(ringOpacity)
                }
            }

            // Layered animated gradient blobs
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            DesignSystem.accentColor,
                            DesignSystem.secondaryAccent,
                            DesignSystem.accentColor.opacity(0.7),
                            DesignSystem.secondaryAccent.opacity(0.8),
                            DesignSystem.accentColor
                        ],
                        center: .center
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 12)
                .rotationEffect(.degrees(rotation1))
                .scaleEffect(scaleForState)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            DesignSystem.accentColor,
                            Color.white.opacity(0.4),
                            DesignSystem.secondaryAccent,
                            Color.white.opacity(0.85)
                        ],
                        center: .center
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: 18)
                .rotationEffect(.degrees(rotation2))
                .scaleEffect(scaleForState * 1.05)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            DesignSystem.accentColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90 + pulse * 8, height: 90 + pulse * 8)
                .blur(radius: 6)
                .rotationEffect(.degrees(rotation3))
                .scaleEffect(scaleForState * 1.1)

            // Glossy highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.75),
                            Color.white.opacity(0)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 110, height: 110)
                .blur(radius: 6)
                .scaleEffect(scaleForState)
        }
        .onAppear { startAnimations() }
        .onChange(of: state) { _, _ in startAnimations() }
    }

    private var scaleForState: CGFloat {
        switch state {
        case .idle:      return 0.92 + pulse * 0.02
        case .listening: return 1.0 + pulse * 0.08
        case .thinking:  return 0.96 + pulse * 0.04
        case .speaking:  return 1.04 + pulse * 0.06
        }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            rotation1 = 360
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotation2 = -360
        }
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            rotation3 = 360
        }

        let pulseDuration: Double
        switch state {
        case .listening: pulseDuration = 0.65
        case .speaking:  pulseDuration = 0.4
        case .thinking:  pulseDuration = 0.9
        case .idle:      pulseDuration = 1.6
        }

        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            pulse = 1.0
        }

        if state == .speaking {
            ringScale = 1.0
            ringOpacity = 0.9
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                ringScale = 1.8
                ringOpacity = 0
            }
        }
    }
}

// MARK: - Auth shim

enum AIAuthError: LocalizedError {
    case notSignedIn
    var errorDescription: String? { "You're not signed in." }
}

enum AIAuth {
    static func requireUID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw AIAuthError.notSignedIn
        }
        return uid
    }
}

#Preview {
    RootTabView(ownerUserId: SampleData.previewUserId)
        .environmentObject(AuthManager())
}
