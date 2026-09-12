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

struct WorkspacePulseCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        primaryValue: String,
        primaryLabel: String,
        secondaryValue: String,
        secondaryLabel: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.primaryValue = primaryValue
        self.primaryLabel = primaryLabel
        self.secondaryValue = secondaryValue
        self.secondaryLabel = secondaryLabel
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ItemIconBadge(symbol: icon, tint: tint, size: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 0)

                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(tint)
                    }
                }

                HStack(spacing: 10) {
                    pulseMetric(value: primaryValue, label: primaryLabel)
                    pulseMetric(value: secondaryValue, label: secondaryLabel)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func pulseMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .monospacedDigit()

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.09))
        )
    }
}

struct CreationGuideCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var status: String?

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 12) {
                ItemIconBadge(symbol: icon, tint: tint, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)

                if let status, !status.isEmpty {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(tint.opacity(0.12))
                        )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct InlineAddItemRow<Helpers: View>: View {
    @Binding var text: String

    let placeholder: String
    let systemImage: String
    let tint: Color
    var isSaving = false
    var autoFocus = false
    var alwaysShowHelpers = false
    var validationMessage: String?
    var onSubmit: () -> Void
    var onCancel: () -> Void
    private let helpers: Helpers

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String,
        systemImage: String,
        tint: Color,
        isSaving: Bool = false,
        autoFocus: Bool = false,
        alwaysShowHelpers: Bool = false,
        validationMessage: String? = nil,
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder helpers: () -> Helpers
    ) {
        _text = text
        self.placeholder = placeholder
        self.systemImage = systemImage
        self.tint = tint
        self.isSaving = isSaving
        self.autoFocus = autoFocus
        self.alwaysShowHelpers = alwaysShowHelpers
        self.validationMessage = validationMessage
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.helpers = helpers()
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isInUse: Bool {
        isFocused || !trimmedText.isEmpty
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button(action: submit) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: systemImage)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(trimmedText.isEmpty ? DesignSystem.secondaryTextColor : tint)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || trimmedText.isEmpty)

                    TextField(placeholder, text: $text)
                        .font(.body)
                        .lineLimit(1)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($isFocused)
                        .disabled(isSaving)
                        .onSubmit(submit)
                }

                if let validationMessage, !validationMessage.isEmpty {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.oweColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 40)
                }

                if isInUse || alwaysShowHelpers {
                    helpers
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(DesignSystem.interactiveSpring, value: isInUse)
        .onAppear {
            guard autoFocus else { return }
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func submit() {
        guard !isSaving, !trimmedText.isEmpty else { return }
        onSubmit()
    }

    private func cancel() {
        text = ""
        onCancel()
    }
}

extension InlineAddItemRow where Helpers == EmptyView {
    init(
        text: Binding<String>,
        placeholder: String,
        systemImage: String,
        tint: Color,
        isSaving: Bool = false,
        autoFocus: Bool = false,
        validationMessage: String? = nil,
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            systemImage: systemImage,
            tint: tint,
            isSaving: isSaving,
            autoFocus: autoFocus,
            validationMessage: validationMessage,
            onSubmit: onSubmit,
            onCancel: onCancel
        ) {
            EmptyView()
        }
    }
}

struct InlineAddHelperButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isSelected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? .white : tint)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(isSelected ? tint : Color.primary.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.white.opacity(0.26) : tint.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct InlineAddHelperMenu<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isSelected = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? .white : tint)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(isSelected ? tint : Color.primary.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.white.opacity(0.26) : tint.opacity(0.16), lineWidth: 1)
                )
        }
        .accessibilityLabel(title)
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

// One destination keeps new and existing items in the same presentation flow.
enum ItemEditorDestination<Item: Identifiable>: Identifiable {
    case new
    case edit(Item)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let item): return "edit-\(item.id)"
        }
    }

    var item: Item? {
        if case .edit(let item) = self { return item }
        return nil
    }
}
