import SwiftUI
import FirebaseAuth

@MainActor
enum ClaudeAIChatResponder {
    private static var claudeService: ClaudeAIService?

    static func initialize(apiKey: String) {
        claudeService = ClaudeAIService(apiKey: apiKey)
        if claudeService != nil {
            print("[ClaudeAIChatResponder] ✅ Claude API ready")
        } else {
            print("[ClaudeAIChatResponder] ⚠️ Claude API key invalid or empty — using pattern-based fallback")
        }
    }

    static func isAvailable() -> Bool {
        return claudeService != nil
    }

    static func resetConversation() {
        Task {
            await claudeService?.resetConversation()
        }
    }

    static func handleUserInput(text: String, assistant: AIAssistantManager) async {
        guard let service = claudeService else {
            print("[ClaudeAIChatResponder] Fallback → AIChatResponder (no Claude service)")
            await AIChatResponder.handleUserInput(text: text, assistant: assistant)
            return
        }

        if isBareNegative(text), assistant.pendingDraft == nil, assistant.missingFields.isEmpty {
            assistant.assistantSay("Okay, I won't change anything.")
            return
        }

        print("[ClaudeAIChatResponder] Routing to Claude | area=\(assistant.currentArea.rawValue)")
        assistant.isThinking = true
        defer { assistant.isThinking = false }

        do {
            if await OnePlaceAICommandExecutor.handleImmediateCommand(text: text, assistant: assistant) {
                return
            }

            let context = ClaudeConversationContext(
                area: assistant.currentArea,
                pendingDraft: assistant.pendingDraft,
                missingFields: assistant.missingFields
            )

            let response = try await service.respondToUserInput(text: text, context: context)
            let data = response.extractedData

            if let action = data.action, !data.requiresFollowUp, !isAction(action, allowedIn: assistant.currentArea) {
                print("[ClaudeAIChatResponder] Blocked cross-area action: \(action) in \(assistant.currentArea.rawValue)")
                assistant.assistantSay("I couldn't safely save that because it doesn't match this tab.")
                return
            }

            assistant.assistantSay(response.message)

            // If there's a pending draft in progress, update it with new data
            if assistant.pendingDraft != nil {
                await updatePendingDraft(with: data, assistant: assistant, area: assistant.currentArea)
            } else if let action = data.action, !data.requiresFollowUp {
                // Claude provided a complete SAVING: block — dispatch immediately
                await dispatchAction(action: action, data: data, assistant: assistant)
            }
            // If requiresFollowUp == true and no pending draft, Claude is still asking questions — do nothing

        } catch {
            print("[ClaudeAIChatResponder] ❌ Error: \(error)")
            assistant.assistantSay("I couldn't process that. Could you try again?")
        }
    }

    private static func isBareNegative(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^a-z\s]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ["no", "nope", "nah", "cancel", "never mind", "nevermind"].contains(normalized)
    }

    private static func isAction(_ action: String, allowedIn area: AIArea) -> Bool {
        switch (area, action.lowercased()) {
        case (.finance, "add_expense"),
             (.finance, "add_income"),
             (.flow, "add_flow_bill"),
             (.flow, "add_flow_income"),
             (.organizer, "add_task"),
             (.split, "add_split_expense"):
            return true
        default:
            return false
        }
    }

    // MARK: - Dispatch new saves (no pending draft yet)

    private static func dispatchAction(action: String, data: ExtractedData, assistant: AIAssistantManager) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            assistant.assistantSay("You're not signed in. Please sign in and try again.")
            return
        }

        print("[ClaudeAIChatResponder] dispatchAction: \(action)")

        switch action.lowercased() {

        case "add_task":
            var draft = TaskItemDraft()
            draft.title = data.title ?? "New Task"
            if let date = data.date { draft.dueDate = date }
            await commitTask(draft: draft, uid: uid, assistant: assistant)

        case "add_flow_bill":
            var draft = FlowItemDraft()
            draft.title = data.title ?? "New Bill"
            draft.amount = data.amount ?? 0
            draft.type = .bill
            if let freq = data.frequency, let f = FlowFrequency(rawValue: freq.lowercased()) {
                draft.frequency = f
            }
            if let date = data.date { draft.nextDueDate = date }
            if draft.amount <= 0 {
                assistant.pendingDraft = .flow(draft)
                assistant.missingFields = [.amount]
                return
            }
            await commitFlowItem(draft: draft, uid: uid, assistant: assistant)

        case "add_flow_income":
            var draft = FlowItemDraft()
            draft.title = data.title ?? "New Income"
            draft.amount = data.amount ?? 0
            draft.type = .income
            if let freq = data.frequency, let f = FlowFrequency(rawValue: freq.lowercased()) {
                draft.frequency = f
            }
            if let date = data.date { draft.nextDueDate = date }
            if draft.amount <= 0 {
                assistant.pendingDraft = .flow(draft)
                assistant.missingFields = [.amount]
                return
            }
            await commitFlowItem(draft: draft, uid: uid, assistant: assistant)

        case "add_expense":
            let expenseAmount = data.amount ?? 0
            if expenseAmount <= 0 {
                assistant.assistantSay("How much was the expense?")
                return
            }
            let draft = FinanceEntryDraft(
                amount: expenseAmount,
                type: .owe,
                category: "General",
                entryDescription: data.title ?? "Expense",
                date: data.date ?? Date(),
                urgency: .medium
            )
            await commitFinanceEntry(draft: draft, uid: uid, assistant: assistant)

        case "add_income":
            let draft = FinanceEntryDraft(
                amount: data.amount ?? 0,
                type: .gain,
                category: "General",
                entryDescription: data.title ?? "Income",
                date: data.date ?? Date(),
                urgency: .low
            )
            if draft.amount <= 0 {
                assistant.assistantSay("How much income would you like to record?")
                return
            }
            await commitFinanceEntry(draft: draft, uid: uid, assistant: assistant)

        case "add_split_expense":
            var draft = SplitExpenseDraft()
            draft.title = data.title ?? "Shared Expense"
            draft.amount = data.amount ?? 0
            if let date = data.date { draft.date = date }
            if draft.amount <= 0 {
                assistant.pendingDraft = .expense(draft)
                assistant.missingFields = [.amount]
                return
            }
            await commitSplitExpense(draft: draft, uid: uid, assistant: assistant)

        default:
            print("[ClaudeAIChatResponder] Unknown action: \(action) — no save dispatched")
        }
    }

    // MARK: - Update existing pending drafts

    private static func updatePendingDraft(
        with data: ExtractedData,
        assistant: AIAssistantManager,
        area: AIArea
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let pendingDraft = assistant.pendingDraft else { return }

        switch pendingDraft {
        case .task(var draft):
            if let date = data.date { draft.dueDate = date }
            if let title = data.title { draft.title = title }
            assistant.pendingDraft = .task(draft)
            if !assistant.missingFields.contains(.dueDate) && !assistant.missingFields.contains(.time) {
                await commitTask(draft: draft, uid: uid, assistant: assistant)
            }

        case .flow(var draft):
            if let amount = data.amount, amount > 0 {
                draft.amount = amount
                assistant.missingFields.removeAll { $0 == .amount }
            }
            if let date = data.date { draft.nextDueDate = date }
            if let title = data.title { draft.title = title }
            if let frequency = data.frequency, let f = FlowFrequency(rawValue: frequency.lowercased()) {
                draft.frequency = f
            }
            assistant.pendingDraft = .flow(draft)
            if assistant.missingFields.isEmpty && draft.amount > 0 {
                await commitFlowItem(draft: draft, uid: uid, assistant: assistant)
            }

        case .expense(var draft):
            if let amount = data.amount, amount > 0 {
                draft.amount = amount
                assistant.missingFields.removeAll { $0 == .amount }
            }
            if let date = data.date { draft.date = date }
            if let title = data.title { draft.title = title }
            assistant.pendingDraft = .expense(draft)
            if assistant.missingFields.isEmpty && draft.amount > 0 {
                await commitSplitExpense(draft: draft, uid: uid, assistant: assistant)
            }
        }
    }

    // MARK: - Commit helpers

    private static func commitTask(draft: TaskItemDraft, uid: String, assistant: AIAssistantManager) async {
        do {
            try await TaskRepository().createTask(for: uid, draft: draft)
            let dateStr = draft.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "today"
            assistant.assistantSay("Done! I've created '\(draft.title)' for \(dateStr). ✅")
            assistant.pendingDraft = nil
            assistant.missingFields = []
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't save that task: \(error.localizedDescription)")
        }
    }

    private static func commitFlowItem(draft: FlowItemDraft, uid: String, assistant: AIAssistantManager) async {
        do {
            try await FlowRepository().createItem(for: uid, draft: draft)
            let amountStr = "$\(String(format: "%.2f", draft.amount))"
            let freqStr = draft.frequency.rawValue.capitalized
            assistant.assistantSay("Done! Added '\(draft.title)' (\(amountStr) \(freqStr)). 💸")
            assistant.pendingDraft = nil
            assistant.missingFields = []
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't save that: \(error.localizedDescription)")
        }
    }

    private static func commitFinanceEntry(draft: FinanceEntryDraft, uid: String, assistant: AIAssistantManager) async {
        do {
            _ = try await FinanceRepository().createEntry(for: uid, draft: draft)
            let typeStr = draft.type == .gain ? "income" : "expense"
            let amountStr = "$\(String(format: "%.2f", draft.amount))"
            assistant.assistantSay("Logged! '\(draft.entryDescription)' recorded as \(typeStr) of \(amountStr). ✅")
            assistant.pendingDraft = nil
            assistant.missingFields = []
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't save that entry: \(error.localizedDescription)")
        }
    }

    private static func commitSplitExpense(draft: SplitExpenseDraft, uid: String, assistant: AIAssistantManager) async {
        do {
            _ = try await SplitRepository().createExpense(for: uid, draft: draft)
            assistant.assistantSay("Split created! '\(draft.title)' for $\(String(format: "%.2f", draft.amount)). 🎯")
            assistant.pendingDraft = nil
            assistant.missingFields = []
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't save that expense: \(error.localizedDescription)")
        }
    }
}
