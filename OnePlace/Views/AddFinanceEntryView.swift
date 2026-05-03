import AVFoundation
import Speech
import SwiftUI

struct AddFinanceEntryView: View {
    let title: String
    @Binding var draft: FinanceEntryDraft
    @Binding var amountText: String
    let isSaving: Bool
    let onDismiss: () -> Void
    let onSave: (FinanceEntryDraft) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.title3.weight(.semibold))

                        Text("A compact editor for transaction details.")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.secondaryTextColor)
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DesignSystem.secondaryTextColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(DesignSystem.secondaryBackground)
                            )
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    FinanceInputField(title: "Description") {
                        TextField("Dinner with Sarah", text: $draft.entryDescription)
                            .textInputAutocapitalization(.sentences)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        FinanceInputField(title: "Amount") {
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                        }

                        FinanceInputField(title: "Date") {
                            DatePicker("", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.secondaryTextColor)

                        Picker("Type", selection: $draft.type) {
                            Text("Gain").tag(FinanceType.gain)
                            Text("Owe").tag(FinanceType.owe)
                        }
                        .pickerStyle(.segmented)
                    }

                    FinanceCategoryMenu(category: $draft.category)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Urgency")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.secondaryTextColor)

                        Picker("Urgency", selection: $draft.urgency) {
                            ForEach(FinanceUrgency.allCases, id: \.self) { urgency in
                                Text(urgency.rawValue.capitalized).tag(urgency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.bordered)

                Button {
                    guard let normalizedDraft = FinanceDraftDefaults.resolvedDraft(from: draft, amountText: amountText) else {
                        return
                    }

                    FinanceDraftDefaults.rememberCategoryIfKnown(normalizedDraft.category)
                    onSave(normalizedDraft)
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }

                        Text(title.lowercased().contains("edit") ? "Save Changes" : "Add Transaction")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignSystem.accentColor)
                )
                .disabled(isSaving || FinanceDraftDefaults.resolvedDraft(from: draft, amountText: amountText) == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(.ultraThinMaterial)
        }
        .background(DesignSystem.backgroundGradient.ignoresSafeArea())
    }
}

struct FinanceCategoryMenu: View {
    @Binding var category: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryTextColor)

            Menu {
                Section("Income") {
                    ForEach(FinanceCategory.incomeRawValues, id: \.self) { item in
                        Button(item) {
                            category = item
                        }
                    }
                }

                Section("Expenses") {
                    ForEach(FinanceCategory.expenseRawValues, id: \.self) { item in
                        Button(item) {
                            category = item
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(DesignSystem.accentColor)

                    Text(category)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.secondaryTextColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignSystem.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
                )
            }
        }
    }
}

private struct FinanceInputField<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryTextColor)

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignSystem.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorderColor, lineWidth: 1)
                )
        }
    }
}

extension FinanceEntryDraft {
    init(record: FinanceEntryRecord) {
        self.init(
            amount: record.amount,
            type: record.type,
            category: record.category,
            entryDescription: record.entryDescription,
            date: record.date,
            urgency: record.urgency
        )
    }
}

enum FinanceDraftDefaults {
    static let lastCategoryKey = "finance.lastCategory"

    static func blankDraft(preferredCategory: String? = nil, preferredType: FinanceType = .owe) -> FinanceEntryDraft {
        let remembered = preferredCategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = remembered.flatMap(normalizedCategory)
            ?? normalizedCategory(UserDefaults.standard.string(forKey: lastCategoryKey) ?? "")
            ?? defaultCategory(for: preferredType)

        return FinanceEntryDraft(
            amount: 0,
            type: type(for: category, fallback: preferredType),
            category: category,
            entryDescription: "",
            date: .now,
            urgency: .medium
        )
    }

    static func resolvedDraft(from draft: FinanceEntryDraft, amountText: String) -> FinanceEntryDraft? {
        guard let amount = parseAmount(amountText) else {
            return nil
        }

        let category = normalizedCategory(draft.category) ?? defaultCategory(for: draft.type)
        let description = draft.entryDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        return FinanceEntryDraft(
            amount: amount,
            type: draft.type,
            category: category,
            entryDescription: description.isEmpty ? category : description,
            date: draft.date,
            urgency: draft.urgency
        )
    }

    static func rememberCategoryIfKnown(_ category: String) {
        guard let category = normalizedCategory(category) else { return }
        UserDefaults.standard.set(category, forKey: lastCategoryKey)
    }

    static func parseAmount(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = Double(cleaned), amount > 0 else {
            return nil
        }

        return amount
    }

    static func amountText(for amount: Double) -> String {
        guard amount > 0 else { return "" }

        if amount.rounded() == amount {
            return String(Int(amount))
        }

        return String(format: "%.2f", amount)
    }

    static func normalizedCategory(_ category: String) -> String? {
        let value = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownCategories = FinanceCategory.incomeRawValues + FinanceCategory.expenseRawValues
        return knownCategories.first { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    static func type(for category: String, fallback: FinanceType = .owe) -> FinanceType {
        if FinanceCategory.incomeRawValues.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
            return .gain
        }

        if FinanceCategory.expenseRawValues.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
            return .owe
        }

        return fallback
    }

    static func defaultCategory(for type: FinanceType) -> String {
        switch type {
        case .gain:
            return FinanceCategory.incomeRawValues.first ?? "Salary"
        case .owe:
            return FinanceCategory.expenseRawValues.first ?? "Other Expense"
        }
    }
}

struct FinancePromptInterpretation {
    let draft: FinanceEntryDraft
    let message: String
    let isReadyToSave: Bool
}

enum FinancePromptInterpreter {
    private struct FinanceCategoryRule {
        let category: String
        let type: FinanceType
        let keywords: [String]
        let shortTitle: String?
    }

    private struct FinanceFlowSignal {
        let type: FinanceType
        let suggestedTitle: String?
        let suggestedCategory: String?
    }

    private static let categoryRules: [FinanceCategoryRule] = [
        FinanceCategoryRule(category: "Salary", type: .gain, keywords: ["salary", "paycheck", "pay day", "wages"], shortTitle: "Paycheck"),
        FinanceCategoryRule(category: "Freelance", type: .gain, keywords: ["freelance", "client", "invoice", "consulting", "contract"], shortTitle: "Client payment"),
        FinanceCategoryRule(category: "Investments", type: .gain, keywords: ["dividend", "interest", "investment", "stock", "portfolio"], shortTitle: "Investment income"),
        FinanceCategoryRule(category: "Other Income", type: .gain, keywords: ["bonus", "refund", "rebate", "cashback", "sold", "sale", "gift"], shortTitle: "Other income"),
        FinanceCategoryRule(category: "Food & Dining", type: .owe, keywords: ["coffee", "lunch", "dinner", "breakfast", "restaurant", "food", "groceries", "grocery", "meal", "snack", "doordash", "ubereats", "uber eats"], shortTitle: nil),
        FinanceCategoryRule(category: "Transport", type: .owe, keywords: ["uber", "lyft", "taxi", "train", "bus", "metro", "parking", "fuel", "gas", "transit", "toll", "flight"], shortTitle: nil),
        FinanceCategoryRule(category: "Shopping", type: .owe, keywords: ["shopping", "amazon", "target", "walmart", "clothes", "shoes", "purchase", "macy", "macy's", "nike", "zara"], shortTitle: nil),
        FinanceCategoryRule(category: "Entertainment", type: .owe, keywords: ["movie", "concert", "spotify", "netflix", "game", "entertainment", "subscription"], shortTitle: nil),
        FinanceCategoryRule(category: "Healthcare", type: .owe, keywords: ["doctor", "pharmacy", "medicine", "dentist", "therapy", "health"], shortTitle: nil),
        FinanceCategoryRule(category: "Education", type: .owe, keywords: ["tuition", "course", "book", "class", "school", "education"], shortTitle: nil),
        FinanceCategoryRule(category: "Bills & Utilities", type: .owe, keywords: ["rent", "mortgage", "electric", "water", "internet", "phone", "utility", "utilities", "insurance", "bill"], shortTitle: nil),
        FinanceCategoryRule(category: "Other Expense", type: .owe, keywords: ["expense", "misc", "miscellaneous", "other", "loan"], shortTitle: "Other expense")
    ]

    private static let gainKeywords = [
        "earned", "received", "made", "got paid", "income", "bonus", "refund", "sold"
    ]

    private static let oweKeywords = [
        "spent", "paid", "bought", "purchase", "charge", "cost", "bill", "expense", "owe"
    ]

    static func interpret(
        _ prompt: String,
        fallbackCategory: String,
        now: Date = .now
    ) -> FinancePromptInterpretation? {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return nil }

        let normalizedPrompt = trimmedPrompt.lowercased()
        let amount = extractAmount(from: trimmedPrompt)
        let flowSignal = semanticMoneyFlowSignal(from: trimmedPrompt, normalizedPrompt: normalizedPrompt)
        let categoryMatch = categoryRules.first { rule in
            rule.keywords.contains(where: normalizedPrompt.contains)
        }
        let explicitType = explicitTypeSignal(from: normalizedPrompt)
        let fallbackCategoryValue = FinanceDraftDefaults.normalizedCategory(fallbackCategory)
        let fallbackType = fallbackCategoryValue.map { FinanceDraftDefaults.type(for: $0, fallback: .owe) }
        let type = flowSignal?.type ?? explicitType ?? categoryMatch?.type ?? fallbackType ?? .owe
        let category = resolvedCategory(
            flowSignal: flowSignal,
            categoryMatch: categoryMatch,
            fallbackCategory: fallbackCategoryValue,
            fallbackType: fallbackType,
            explicitType: explicitType,
            resolvedType: type
        )

        let resolvedDate = extractDate(from: trimmedPrompt, now: now) ?? now
        let urgency = extractUrgency(from: normalizedPrompt)

        let description = shortDescription(
            from: trimmedPrompt,
            normalizedPrompt: normalizedPrompt,
            amount: amount,
            category: category,
            type: type,
            flowSignal: flowSignal,
            categoryMatch: categoryMatch,
            date: resolvedDate,
            now: now
        )

        let draft = FinanceEntryDraft(
            amount: amount ?? 0,
            type: type,
            category: category,
            entryDescription: description.isEmpty ? category : description,
            date: resolvedDate,
            urgency: urgency
        )

        let isReadyToSave = amount != nil
        let message: String
        if isReadyToSave, let amount {
            message = "Parsed \(StatCard.currencyString(for: amount)) for \(category)."
        } else {
            message = "I filled the row. Add an amount to save it."
        }

        return FinancePromptInterpretation(
            draft: draft,
            message: message,
            isReadyToSave: isReadyToSave
        )
    }

    private static func explicitTypeSignal(from prompt: String) -> FinanceType? {
        if gainKeywords.contains(where: prompt.contains) {
            return .gain
        }

        if oweKeywords.contains(where: prompt.contains) {
            return .owe
        }

        return nil
    }

    private static func resolvedCategory(
        flowSignal: FinanceFlowSignal?,
        categoryMatch: FinanceCategoryRule?,
        fallbackCategory: String?,
        fallbackType: FinanceType?,
        explicitType: FinanceType?,
        resolvedType: FinanceType
    ) -> String {
        if let suggestedCategory = flowSignal?.suggestedCategory {
            return suggestedCategory
        }

        if let categoryMatch, categoryMatch.type == resolvedType {
            return categoryMatch.category
        }

        if let categoryMatch {
            if resolvedType == .gain, categoryMatch.type == .owe {
                return "Other Income"
            }

            if resolvedType == .owe, categoryMatch.type == .gain {
                return "Other Expense"
            }
        }

        if explicitType == nil, fallbackType == resolvedType, let fallbackCategory {
            return fallbackCategory
        }

        return FinanceDraftDefaults.defaultCategory(for: resolvedType)
    }

    private static func extractAmount(from prompt: String) -> Double? {
        let pattern = #"(?:^|[\s])\$?(\d+(?:\.\d{1,2})?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        guard let match = regex.firstMatch(in: prompt, range: range),
              let amountRange = Range(match.range(at: 1), in: prompt) else {
            return nil
        }

        return Double(prompt[amountRange])
    }

    private static func extractDate(from prompt: String, now: Date) -> Date? {
        let lowered = prompt.lowercased()
        let calendar = Calendar.autoupdatingCurrent

        if lowered.contains("yesterday") || lowered.contains("last night") {
            return calendar.date(byAdding: .day, value: -1, to: now)
        }

        if lowered.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }

        if lowered.contains("today") || lowered.contains("tonight") {
            return now
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        return detector?.matches(in: prompt, range: range).first?.date
    }

    private static func extractUrgency(from prompt: String) -> FinanceUrgency {
        if ["urgent", "asap", "overdue", "immediately", "tonight"].contains(where: prompt.contains) {
            return .high
        }

        if ["soon", "this week", "upcoming"].contains(where: prompt.contains) {
            return .medium
        }

        return .medium
    }

    private static func shortDescription(
        from prompt: String,
        normalizedPrompt: String,
        amount: Double?,
        category: String,
        type: FinanceType,
        flowSignal: FinanceFlowSignal?,
        categoryMatch: FinanceCategoryRule?,
        date: Date,
        now: Date
    ) -> String {
        if let suggestedTitle = flowSignal?.suggestedTitle, !suggestedTitle.isEmpty {
            return suggestedTitle
        }

        if type == .gain, normalizedPrompt.contains("got paid") || normalizedPrompt.contains("paycheck") {
            return "Paycheck"
        }

        if let merchant = merchantTitle(from: normalizedPrompt) {
            return merchant
        }

        if let shortTitle = categoryMatch?.shortTitle {
            return shortTitle
        }

        let cleanedTokens = condensedTokens(from: prompt, amount: amount)
        if !cleanedTokens.isEmpty {
            return cleanedTokens.prefix(3)
                .map(capitalizedDisplayToken)
                .joined(separator: " ")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relativeLabel = formatter.localizedString(for: date, relativeTo: now)
        if !relativeLabel.isEmpty {
            return relativeLabel.capitalized
        }

        return category
    }

    private static func semanticMoneyFlowSignal(from prompt: String, normalizedPrompt: String) -> FinanceFlowSignal? {
        let reason = conciseReasonPhrase(from: prompt, normalizedPrompt: normalizedPrompt)

        if let person = captureFirstGroup(
            pattern: #"(?:^|.*?\b)([A-Za-z]+)\s+owes\s+me\b"#,
            in: prompt
        ) {
            return FinanceFlowSignal(
                type: .gain,
                suggestedTitle: owesMeTitle(person: capitalizedDisplayToken(person), reason: reason),
                suggestedCategory: "Other Income"
            )
        }

        if normalizedPrompt.contains("owe me") || normalizedPrompt.contains("owed me") {
            return FinanceFlowSignal(
                type: .gain,
                suggestedTitle: reason.map { "\($0) reimbursement" } ?? "Money owed to me",
                suggestedCategory: "Other Income"
            )
        }

        if let person = captureFirstGroup(
            pattern: #"(?:^|.*?\b)i\s+owe\s+(?:my\s+)?([A-Za-z]+)\b"#,
            in: prompt
        ) {
            return FinanceFlowSignal(
                type: .owe,
                suggestedTitle: payTitle(person: capitalizedDisplayToken(person), reason: reason),
                suggestedCategory: "Other Expense"
            )
        }

        if let person = captureFirstGroup(
            pattern: #"(?:^|.*?\b)(?:pay|paid|repay|pay back)\s+(?:my\s+)?([A-Za-z]+)\b"#,
            in: prompt
        ) {
            return FinanceFlowSignal(
                type: .owe,
                suggestedTitle: payTitle(person: capitalizedDisplayToken(person), reason: reason),
                suggestedCategory: "Other Expense"
            )
        }

        if normalizedPrompt.contains("pay me back") || normalizedPrompt.contains("paid me back") || normalizedPrompt.contains("reimburse me") {
            return FinanceFlowSignal(
                type: .gain,
                suggestedTitle: reason.map { "\($0) reimbursement" } ?? "Reimbursement",
                suggestedCategory: "Other Income"
            )
        }

        return nil
    }

    private static func captureFirstGroup(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[captureRange])
    }

    private static func conciseReasonPhrase(from prompt: String, normalizedPrompt: String) -> String? {
        if let merchant = merchantTitle(from: normalizedPrompt) {
            if normalizedPrompt.contains("shopping") {
                return "\(merchant) shopping"
            }

            return merchant
        }

        guard let reason = captureFirstGroup(
            pattern: #"\bfor\s+([A-Za-z0-9'&\s]+)"#,
            in: prompt
        ) else {
            return nil
        }

        let cleaned = reason
            .replacingOccurrences(of: #"[^A-Za-z0-9'&\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = cleaned
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .prefix(3)

        guard !tokens.isEmpty else { return nil }
        return tokens.map(capitalizedDisplayToken).joined(separator: " ")
    }

    private static func owesMeTitle(person: String, reason: String?) -> String {
        guard let reason, !reason.isEmpty else {
            return "\(person) owes me"
        }

        return "\(person) owes me for \(reason)"
    }

    private static func payTitle(person: String, reason: String?) -> String {
        guard let reason, !reason.isEmpty else {
            return "Pay \(person)"
        }

        return "Pay \(person) for \(reason)"
    }

    private static func merchantTitle(from normalizedPrompt: String) -> String? {
        let merchantMap: [(String, String)] = [
            ("uber", "Uber"),
            ("lyft", "Lyft"),
            ("amazon", "Amazon"),
            ("target", "Target"),
            ("walmart", "Walmart"),
            ("macy's", "Macy's"),
            ("macy", "Macy's"),
            ("starbucks", "Starbucks"),
            ("netflix", "Netflix"),
            ("spotify", "Spotify")
        ]

        return merchantMap.first(where: { normalizedPrompt.contains($0.0) })?.1
    }

    private static func personAfterDebtPhrase(in prompt: String) -> String? {
        let patterns = [
            #"(?:owe|repay|pay back|paid back)\s+(?:my\s+)?([A-Za-z]+)"#,
            #"(?:to)\s+(?:my\s+)?([A-Za-z]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
            guard let match = regex.firstMatch(in: prompt, range: range),
                  let personRange = Range(match.range(at: 1), in: prompt) else {
                continue
            }

            return capitalizedDisplayToken(String(prompt[personRange]))
        }

        return nil
    }

    private static func condensedTokens(from prompt: String, amount: Double?) -> [String] {
        var value = prompt

        if let amount {
            let amountText = amount.rounded() == amount ? String(Int(amount)) : String(amount)
            value = value.replacingOccurrences(of: "$\(amountText)", with: "", options: .caseInsensitive)
            value = value.replacingOccurrences(of: amountText, with: "", options: .caseInsensitive)
        }

        let disposableTerms = [
            "add", "log", "record", "track", "transaction", "expense", "income",
            "today", "yesterday", "tomorrow", "last", "night", "tonight", "please",
            "my", "me", "for", "with", "the", "a", "an", "i", "owe", "paid", "pay",
            "back", "got", "received", "made", "asked"
        ]

        value = value.replacingOccurrences(of: #"[^A-Za-z0-9'\s]"#, with: " ", options: .regularExpression)

        return value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { token in
                let lowered = token.lowercased()
                return !disposableTerms.contains(lowered) && lowered.rangeOfCharacter(from: .decimalDigits) == nil
            }
    }

    private static func capitalizedDisplayToken(_ token: String) -> String {
        let lowered = token.lowercased()

        if lowered == "macy's" || lowered == "macys" {
            return "Macy's"
        }

        return lowered.prefix(1).uppercased() + lowered.dropFirst()
    }
}

@MainActor
final class FinanceSpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
    private var silenceWorkItem: DispatchWorkItem?

    func startRecording() async {
        errorMessage = nil
        transcript = ""

        do {
            try await requestPermissions()
            try beginRecognition()
        } catch {
            errorMessage = error.localizedDescription
            stopRecording()
        }
    }

    func stopRecording() {
        silenceWorkItem?.cancel()
        finishCapture(cancelTask: true)
    }

    func clearTranscript() {
        transcript = ""
    }

    private func requestPermissions() async throws {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAuthorized else {
            throw FinanceVoiceError.speechPermissionDenied
        }

        let micAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micAuthorized else {
            throw FinanceVoiceError.microphonePermissionDenied
        }
    }

    private func beginRecognition() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw FinanceVoiceError.recognizerUnavailable
        }

        stopRecording()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.transcript = result.bestTranscription.formattedString
                self.scheduleSilenceTimeout()

                if result.isFinal {
                    self.finishCapture(cancelTask: false)
                }
            }

            if let error {
                self.errorMessage = error.localizedDescription
                self.finishCapture(cancelTask: true)
            }
        }
    }

    private func scheduleSilenceTimeout() {
        silenceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.finishCapture(cancelTask: false)
        }

        silenceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
    }

    private func finishCapture(cancelTask: Bool) {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
        }

        if cancelTask {
            recognitionTask?.cancel()
        }

        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum FinanceVoiceError: LocalizedError {
    case speechPermissionDenied
    case microphonePermissionDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "Speech recognition access is required for voice transaction capture."
        case .microphonePermissionDenied:
            return "Microphone access is required for voice transaction capture."
        case .recognizerUnavailable:
            return "Speech recognition is not available right now."
        }
    }
}
