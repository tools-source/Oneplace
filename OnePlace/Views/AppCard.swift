import SwiftUI
import UIKit

public struct AppCard<Content: View>: View {
    private let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(DesignSystem.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.largeCardCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.glassStroke, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
        .shadow(
            color: DesignSystem.shadowColor.opacity(colorScheme == .dark ? 0.20 : 0.10),
            radius: colorScheme == .dark ? 10 : 12,
            x: 0, y: colorScheme == .dark ? 5 : 7
        )
    }


}

struct ItemIconBadge: View {
    private let symbol: String?
    private let text: String?
    private let tint: Color
    private let size: CGFloat

    init(symbol: String, tint: Color, size: CGFloat = DesignSystem.badgeSize) {
        self.symbol = symbol
        self.text = nil
        self.tint = tint
        self.size = size
    }

    init(text: String, tint: Color = DesignSystem.accentColor, size: CGFloat = DesignSystem.badgeSize) {
        self.symbol = nil
        self.text = text
        self.tint = tint
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: size, height: size)

            if let text, !text.isEmpty {
                Text(text)
                    .font(.system(size: size * 0.52))
                    .minimumScaleFactor(0.6)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
        .accessibilityHidden(symbol != nil)
    }
}

enum OnePlaceAITab {
    case finance
    case flow
    case organizer
    case split
    case talk
    case settings
}

enum OnePlacePromptClassifier {
    static func isCommand(_ prompt: String, in tab: OnePlaceAITab) -> Bool {
        let lowered = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return false }

        switch tab {
        case .finance:
            return hasCommandVerb(lowered) || (hasAmount(lowered) && containsLetters(lowered)) || hasDebtPhrase(lowered)
        case .flow:
            return hasCommandVerb(lowered) || hasFlowSignal(lowered) || (hasAmount(lowered) && hasRecurringSignal(lowered))
        case .organizer:
            // Accept any non-trivial input — the search bar doubles as task creation,
            // so treat any text with letters as a potential task.
            return lowered.rangeOfCharacter(from: .letters) != nil
        case .split:
            return hasCommandVerb(lowered) || lowered.hasPrefix("add ") || lowered.contains("split") || lowered.contains("paid by") || hasAmount(lowered)
        case .talk:
            return hasCommandVerb(lowered) ||
                lowered.contains("talk card") ||
                lowered.contains("card that says") ||
                lowered.contains("saying ") ||
                lowered.hasPrefix("i need ") ||
                lowered.hasPrefix("i want ") ||
                lowered.hasPrefix("help ")
        case .settings:
            return true
        }
    }

    private static func hasCommandVerb(_ prompt: String) -> Bool {
        let commandWords = [
            "add", "create", "make", "log", "record", "track", "schedule", "set",
            "remind", "mark", "pay", "paid", "split", "delete", "remove", "erase",
            "complete", "finish", "finished", "reopen", "undo"
        ]

        return commandWords.contains { word in
            prompt.hasPrefix("\(word) ") || prompt.contains(" \(word) ")
        }
    }

    private static func hasAmount(_ prompt: String) -> Bool {
        prompt.range(of: #"\$?\d+(?:\.\d{1,2})?\b"#, options: .regularExpression) != nil
    }

    private static func containsLetters(_ prompt: String) -> Bool {
        prompt.rangeOfCharacter(from: .letters) != nil
    }

    private static func hasDebtPhrase(_ prompt: String) -> Bool {
        [
            "owes me", "owe me", "i owe", "pay me back", "reimburse me", "paid me back"
        ].contains(where: prompt.contains)
    }

    private static func hasFlowSignal(_ prompt: String) -> Bool {
        [
            "bill", "bowl", "income", "salary", "paycheck", "due", "reminder",
            "remind", "subscription", "credit card", "rent", "electric", "water"
        ].contains(where: prompt.contains)
    }

    private static func hasRecurringSignal(_ prompt: String) -> Bool {
        [
            "monthly", "weekly", "biweekly", "quarterly", "yearly", "annual",
            "every month", "every week", "repeats"
        ].contains(where: prompt.contains)
    }
}

struct OnePlaceAISearchBar: View {
    @Binding var text: String
    let placeholder: String
    let isProcessing: Bool
    let onSubmit: (Bool) -> Void

    @StateObject private var speechRecognizer = FinanceSpeechRecognizer()
    @State private var lastSubmitWasVoice: Bool = false

    init(text: Binding<String>,
         placeholder: String,
         isProcessing: Bool,
         onSubmit: @escaping (Bool) -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.isProcessing = isProcessing
        self.onSubmit = onSubmit
    }

    init(text: Binding<String>,
         placeholder: String,
         isProcessing: Bool,
         onSubmit: @escaping () -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.isProcessing = isProcessing
        self.onSubmit = { _ in onSubmit() }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.search)
                .onSubmit { submit(wasVoice: false) }

            if isProcessing {
                ProgressView()
                    .tint(DesignSystem.accentColor)
            }

            Button(action: toggleVoiceCapture) {
                ZStack {
                    Circle()
                        .fill(speechRecognizer.isRecording ? DesignSystem.oweColor.opacity(0.16) : DesignSystem.accentSoft)
                        .frame(width: 36, height: 36)

                    if speechRecognizer.isRecording {
                        Circle()
                            .stroke(DesignSystem.oweColor.opacity(0.55), lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .scaleEffect(speechRecognizer.isRecording ? 1.25 : 1.0)
                            .opacity(speechRecognizer.isRecording ? 0 : 1)
                            .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: speechRecognizer.isRecording)
                    }

                    Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(speechRecognizer.isRecording ? DesignSystem.oweColor : DesignSystem.accentColor)
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .accessibilityLabel(speechRecognizer.isRecording ? "Stop voice command" : "Start voice command")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    AnyShapeStyle(
                        speechRecognizer.isRecording
                            ? AnyShapeStyle(DesignSystem.oweColor.opacity(0.4))
                            : AnyShapeStyle(DesignSystem.glassStroke)
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: DesignSystem.shadowColor.opacity(0.07), radius: 10, x: 0, y: 6)
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            guard speechRecognizer.isRecording else { return }
            text = newValue
        }
        .onChange(of: speechRecognizer.isRecording) { oldValue, newValue in
            guard oldValue, !newValue else { return }
            let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else { return }
            text = transcript
            submit(wasVoice: true)
        }
    }

    private func submit(wasVoice: Bool) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        onSubmit(wasVoice)
    }

    private func toggleVoiceCapture() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            return
        }

        speechRecognizer.clearTranscript()
        Task {
            await speechRecognizer.startRecording()
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    AppCard {
        Text("Example card content")
            .font(.headline)
            .foregroundColor(.primary)
    }
    .padding()
}
