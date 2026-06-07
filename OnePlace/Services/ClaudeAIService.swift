import Foundation

struct ClaudeConversationContext: Sendable {
    let area: AIArea
    let pendingDraft: AIPendingDraft?
    let missingFields: [AIMissingField]
}

actor ClaudeAIService {
    private let apiKey: String
    private let baseURL = "https://openrouter.ai/api/v1"
    // Valid OpenRouter free model IDs — pick one:
    //   "nvidia/nemotron-3-super:free"                 NVIDIA Nemotron 3 Super (fastest, #1 by usage, 1M ctx)
    //   "deepseek/deepseek-v4-flash:free"              DeepSeek V4 Flash
    //   "openai/gpt-oss-20b:free"                      OpenAI gpt-oss 20B (smallest, fastest)
    //   "deepseek/deepseek-r1:free"                    DeepSeek R1 (better reasoning, slower)
    private static let model = "openai/gpt-oss-20b:free"
    private static let timeoutSeconds: Double = 25

    private var conversationHistory: [Message] = []

    // MARK: - OpenAI-compatible types (used by OpenRouter)

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable {
        let model: String
        let max_tokens: Int
        let messages: [Message]
    }

    struct ChatResponse: Codable {
        let id: String
        let choices: [Choice]
        let usage: Usage

        struct Choice: Codable {
            let message: Message
            let finish_reason: String?
        }

        struct Usage: Codable {
            let prompt_tokens: Int
            let completion_tokens: Int
        }
    }

    // MARK: - Init

    init?(apiKey: String?) {
        guard let key = apiKey, !key.isEmpty else {
            print("[ClaudeAI] ❌ No API key — falling back to pattern-based AI")
            return nil
        }
        self.apiKey = key
        print("[ClaudeAI] ✅ Initialized | key: \(key.prefix(14))… | model: \(ClaudeAIService.model)")
    }

    // MARK: - Public

    func respondToUserInput(
        text: String,
        context: ClaudeConversationContext
    ) async throws -> ClaudeAIResponse {
        print("[ClaudeAI] ▶ User input: \"\(text)\"")
        print("[ClaudeAI]   Area: \(context.area.rawValue) | Pending: \(context.pendingDraft != nil) | Missing: \(context.missingFields.map(\.rawValue))")

        conversationHistory.append(Message(role: "user", content: text))

        let systemMessage = Message(role: "system", content: buildSystemPrompt(for: context))
        let allMessages = [systemMessage] + conversationHistory

        let request = ChatRequest(
            model: ClaudeAIService.model,
            max_tokens: 1024,
            messages: allMessages
        )

        print("[ClaudeAI] → Sending to \(ClaudeAIService.model) (\(conversationHistory.count) turn(s))")

        let response = try await makeRequest(request)

        guard let choice = response.choices.first else {
            print("[ClaudeAI] ❌ Response has no choices")
            throw ClaudeAIError.invalidResponse
        }

        let reply = choice.message.content
        print("[ClaudeAI] ← finish_reason=\(choice.finish_reason ?? "nil") | in=\(response.usage.prompt_tokens) out=\(response.usage.completion_tokens) tokens")
        print("[ClaudeAI]   Reply: \"\(reply.prefix(200))\(reply.count > 200 ? "…" : "")\"")

        conversationHistory.append(Message(role: "assistant", content: reply))

        let extractedData = extractStructuredData(from: reply, userInput: text, context: context)
        print("[ClaudeAI]   Extracted — amount: \(extractedData.amount.map { "$\($0)" } ?? "nil") | date: \(extractedData.date.map { "\($0)" } ?? "nil") | freq: \(extractedData.frequency ?? "nil") | title: \(extractedData.title ?? "nil") | needsFollowUp: \(extractedData.requiresFollowUp)")

        return ClaudeAIResponse(message: userFacingMessage(from: reply), extractedData: extractedData)
    }

    func resetConversation() {
        conversationHistory.removeAll()
        print("[ClaudeAI] 🔄 Conversation history cleared")
    }

    // MARK: - HTTP

    private func makeRequest(_ request: ChatRequest) async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = ClaudeAIService.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = try JSONEncoder().encode(request)
        urlRequest.httpBody = body

        print("[ClaudeAI] HTTP POST \(url.absoluteString) | body: \(body.count) bytes | timeout: \(Int(ClaudeAIService.timeoutSeconds))s")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ClaudeAI] ❌ Non-HTTP response")
            throw ClaudeAIError.networkError
        }

        print("[ClaudeAI] HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[ClaudeAI] ❌ Error body: \(errorBody)")
            throw ClaudeAIError.networkError
        }

        do {
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[ClaudeAI] ❌ Decode error: \(error)\n  Raw: \(raw.prefix(500))")
            throw error
        }
    }

    // MARK: - System prompt

    private func buildSystemPrompt(for context: ClaudeConversationContext) -> String {
        let areaDesc = areaDescription(for: context.area)
        let draftInfo = context.pendingDraft.map { "\n\nPending draft in progress: \($0)" } ?? ""
        let missingInfo = context.missingFields.isEmpty ? "" :
            "\n\nStill need from user: \(context.missingFields.map(\.rawValue).joined(separator: ", "))"

        return """
You are OnePlace AI, a personal finance and productivity assistant.
Current area: \(areaDesc)

Rules:
1. Extract ALL data from the user's message (amounts, dates, title, frequency, participants).
2. Only save information explicitly stated by the user. Never invent amounts, titles, people, debts, dates, or expenses.
3. If the user says no, cancel, never mind, or rejects a follow-up, do not save anything. Reply briefly that nothing changed.
4. If data is sufficient to complete the action, include one "SAVING:" block followed by a separate plain-English confirmation.
5. The text after "SAVING:" is private app data. Do not explain the block to the user.
6. If critical info is missing, ask ONE specific question.
7. Be brief and conversational.

Area rules:
- Finance may use add_expense and add_income.
- Flow may use add_flow_bill and add_flow_income.
- Organizer may use add_task.
- Split may only use add_split_expense for shared expenses with an amount. Adding people is handled by the app, so do not create an expense for a people-only request.
- Talk and Settings should not output SAVING blocks.

When saving, output a structured block like this (include only relevant fields):
SAVING:
- Action: add_expense / add_income / add_task / add_flow_bill / add_flow_income / add_split_expense
- Title: [name]
- Amount: $X.XX
- Date: YYYY-MM-DD
- Frequency: monthly/weekly/biweekly/quarterly/yearly
- Participants: [names]
\(draftInfo)\(missingInfo)
"""
    }

    private func userFacingMessage(from reply: String) -> String {
        guard let savingRange = reply.range(of: "SAVING:", options: .caseInsensitive) else {
            return reply.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let afterSaving = String(reply[savingRange.upperBound...])
        let lines = afterSaving.components(separatedBy: .newlines)
        var confirmationLines: [String] = []
        var passedSavingBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if !passedSavingBlock {
                if trimmed.isEmpty {
                    passedSavingBlock = true
                }
                continue
            }

            confirmationLines.append(line)
        }

        let confirmation = confirmationLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !confirmation.isEmpty {
            return confirmation
        }

        if let action = extractField("Action", from: afterSaving) {
            return "Done. I saved that \(friendlyActionName(action))."
        }

        return "Done."
    }

    private func friendlyActionName(_ action: String) -> String {
        switch action.lowercased() {
        case "add_income":
            return "income"
        case "add_expense":
            return "expense"
        case "add_task":
            return "task"
        case "add_flow_bill":
            return "bill"
        case "add_flow_income":
            return "income"
        case "add_split_expense":
            return "split expense"
        default:
            return "item"
        }
    }

    private func areaDescription(for area: AIArea) -> String {
        switch area {
        case .finance:   return "Finance — log income and expenses"
        case .flow:      return "Flow — manage recurring bills and income"
        case .organizer: return "Organizer — create and manage tasks"
        case .split:     return "Split — track shared expenses and who owes what"
        case .talk:      return "Talk — create communication cards"
        case .settings:  return "Settings"
        }
    }

    // MARK: - Data extraction

    private func extractStructuredData(from response: String, userInput: String, context: ClaudeConversationContext) -> ExtractedData {
        var data = ExtractedData()

        // Parse the SAVING: block Claude outputs
        if let savingRange = response.range(of: "SAVING:", options: .caseInsensitive) {
            let savingBlock = String(response[savingRange.upperBound...])
            data.action    = extractField("Action", from: savingBlock)
            data.title     = extractField("Title", from: savingBlock)
            data.frequency = extractField("Frequency", from: savingBlock)
            if let amtStr = extractField("Amount", from: savingBlock) {
                data.amount = parseAmount(amtStr)
            }
            if let dateStr = extractField("Date", from: savingBlock) {
                data.date = parseDate(dateStr)
            }
            data.requiresFollowUp = false
            print("[ClaudeAI]   SAVING block found — action: \(data.action ?? "nil")")
        } else {
            // Fall back: scrape raw numbers from user input (not AI reply) to avoid false positives
            data.amount = extractAmount(from: userInput)
            data.date   = extractDate(from: response)
            data.title  = extractField("Title", from: response)
            data.requiresFollowUp = response.last == "?" ||
                response.lowercased().contains("how much") ||
                response.lowercased().contains("what date") ||
                !context.missingFields.isEmpty
        }

        return data
    }

    private func extractField(_ key: String, from text: String) -> String? {
        let pattern = "(?:^|\\n)- \(key):[\\s]*([^\\n]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let result = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private func parseAmount(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let d = formatter.date(from: text) { return d }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        return detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).first?.date
    }

    private func extractAmount(from text: String) -> Double? {
        let pattern = #"\$(\d+(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    private func extractDate(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        return detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).first?.date
    }
}

// MARK: - Supporting types

struct ExtractedData {
    var action: String?       // e.g. "add_expense", "add_task"
    var amount: Double?
    var date: Date?
    var title: String?
    var frequency: String?
    var requiresFollowUp: Bool = true
}

struct ClaudeAIResponse {
    let message: String
    let extractedData: ExtractedData
}

enum ClaudeAIError: LocalizedError {
    case invalidResponse
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from AI"
        case .networkError:    return "Network error communicating with AI"
        }
    }
}
