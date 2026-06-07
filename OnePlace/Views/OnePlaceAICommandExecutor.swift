import Foundation

@MainActor
enum OnePlaceAICommandExecutor {
    private enum Intent: Equatable {
        case delete
        case complete
        case reopen
        case markPaid
        case markUpcoming
    }

    private struct MatchCandidate {
        let label: String
        let searchText: String
        let amount: Double?
    }

    static func handleImmediateCommand(text: String, assistant: AIAssistantManager) async -> Bool {
        if await handleLocalAddCommand(text: text, assistant: assistant) {
            return true
        }

        guard let intent = intent(for: text) else { return false }

        switch assistant.currentArea {
        case .finance:
            return await handleFinance(intent: intent, text: text, assistant: assistant)
        case .flow:
            return await handleFlow(intent: intent, text: text, assistant: assistant)
        case .organizer:
            return await handleTasks(intent: intent, text: text, assistant: assistant)
        case .split:
            return await handleSplit(intent: intent, text: text, assistant: assistant)
        case .talk:
            return await handleTalk(intent: intent, text: text, assistant: assistant)
        case .settings:
            return false
        }
    }

    private static func handleLocalAddCommand(text: String, assistant: AIAssistantManager) async -> Bool {
        guard assistant.currentArea == .split else { return false }
        guard let names = splitPersonNames(from: text), !names.isEmpty else { return false }

        do {
            let uid = try AIAuth.requireUID()
            let repo = SplitRepository()
            var addedNames: [String] = []

            for name in names {
                _ = try await repo.createPerson(for: uid, name: name)
                addedNames.append(name)
            }

            assistant.assistantSay("Added \(joinedNames(addedNames)) to Split.")
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't add those people: \(error.localizedDescription)")
        }

        return true
    }

    private static func handleFinance(intent: Intent, text: String, assistant: AIAssistantManager) async -> Bool {
        guard intent == .delete || intent == .complete || intent == .reopen else { return false }

        do {
            let uid = try AIAuth.requireUID()
            let repo = FinanceRepository()
            let entries = try await repo.fetchEntries(for: uid)
            guard let entry = match(
                in: entries,
                text: text,
                assistant: assistant,
                emptyMessage: "I don't see any finance entries to change.",
                noMatchMessage: "Which finance entry should I change?",
                ambiguousPrefix: "I found more than one matching finance entry",
                candidate: { entry in
                    MatchCandidate(
                        label: entry.entryDescription,
                        searchText: "\(entry.entryDescription) \(entry.category) \(entry.type.rawValue)",
                        amount: entry.amount
                    )
                }
            ) else { return true }

            switch intent {
            case .delete:
                try await repo.deleteEntry(entry)
                assistant.assistantSay("Deleted \(entry.entryDescription).")
            case .complete, .reopen:
                var updated = entry
                updated.isCompleted = intent == .complete
                try await repo.updateEntry(updated)
                assistant.assistantSay("\(updated.isCompleted ? "Completed" : "Reopened") \(entry.entryDescription).")
            case .markPaid, .markUpcoming:
                return false
            }

            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't update Finance: \(error.localizedDescription)")
        }

        return true
    }

    private static func handleFlow(intent: Intent, text: String, assistant: AIAssistantManager) async -> Bool {
        guard intent == .delete || intent == .markPaid || intent == .markUpcoming || intent == .complete || intent == .reopen else {
            return false
        }

        do {
            let uid = try AIAuth.requireUID()
            let repo = FlowRepository()
            let items = try await repo.fetchItems(for: uid)
            guard let item = match(
                in: items,
                text: text,
                assistant: assistant,
                emptyMessage: "I don't see any Flow items to change.",
                noMatchMessage: "Which Flow item should I change?",
                ambiguousPrefix: "I found more than one matching Flow item",
                candidate: { item in
                    MatchCandidate(
                        label: item.title,
                        searchText: "\(item.title) \(item.type.rawValue) \(item.frequency.rawValue) \(item.status.rawValue)",
                        amount: item.amount
                    )
                }
            ) else { return true }

            switch intent {
            case .delete:
                try await repo.deleteItem(item)
                assistant.assistantSay("Deleted \(item.title).")
            case .markPaid, .complete:
                var updated = item
                updated.status = .paid
                try await repo.updateItem(updated)
                assistant.assistantSay("Marked \(item.title) as paid.")
            case .markUpcoming, .reopen:
                var updated = item
                updated.status = .upcoming
                try await repo.updateItem(updated)
                assistant.assistantSay("Marked \(item.title) as upcoming.")
            }

            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't update Flow: \(error.localizedDescription)")
        }

        return true
    }

    private static func handleTasks(intent: Intent, text: String, assistant: AIAssistantManager) async -> Bool {
        guard intent == .delete || intent == .complete || intent == .reopen else { return false }

        do {
            let uid = try AIAuth.requireUID()
            let repo = TaskRepository()
            let tasks = try await repo.fetchTasks(for: uid)
            guard let task = match(
                in: tasks,
                text: text,
                assistant: assistant,
                emptyMessage: "I don't see any tasks to change.",
                noMatchMessage: "Which task should I change?",
                ambiguousPrefix: "I found more than one matching task",
                candidate: { task in
                    MatchCandidate(
                        label: task.title,
                        searchText: "\(task.title) \(task.notes ?? "") \(task.priority.rawValue)",
                        amount: nil
                    )
                }
            ) else { return true }

            switch intent {
            case .delete:
                try await repo.deleteTask(task)
                assistant.assistantSay("Deleted \(task.title).")
            case .complete:
                var updated = task
                updated.completed = true
                try await repo.updateTask(updated)
                assistant.assistantSay("Completed \(task.title).")
            case .reopen:
                var updated = task
                updated.completed = false
                try await repo.updateTask(updated)
                assistant.assistantSay("Reopened \(task.title).")
            case .markPaid, .markUpcoming:
                return false
            }

            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't update Tasks: \(error.localizedDescription)")
        }

        return true
    }

    private static func handleSplit(intent: Intent, text: String, assistant: AIAssistantManager) async -> Bool {
        guard intent == .delete else { return false }

        do {
            let uid = try AIAuth.requireUID()
            let repo = SplitRepository()
            let people = try await repo.fetchPeople(for: uid)
            let expenses = try await repo.fetchExpenses(for: uid)
            let lowered = text.lowercased()

            if lowered.contains("person") || lowered.contains("people") {
                guard let person = matchSplitPerson(people, text: text, assistant: assistant) else { return true }
                try await repo.deletePerson(person)
                assistant.assistantSay("Deleted \(person.name).")
                assistant.pendingActionsToken = UUID()
                return true
            }

            if lowered.contains("expense") || parseAmount(from: text) != nil {
                guard let expense = matchSplitExpense(expenses, text: text, assistant: assistant) else { return true }
                try await repo.deleteExpense(expense)
                assistant.assistantSay("Deleted \(expense.title).")
                assistant.pendingActionsToken = UUID()
                return true
            }

            if let expense = bestMatch(
                in: expenses,
                text: text,
                candidate: { MatchCandidate(label: $0.title, searchText: $0.title, amount: $0.amount) }
            )?.item {
                try await repo.deleteExpense(expense)
                assistant.assistantSay("Deleted \(expense.title).")
                assistant.pendingActionsToken = UUID()
            } else if let person = bestMatch(
                in: people,
                text: text,
                candidate: { MatchCandidate(label: $0.name, searchText: $0.name, amount: nil) }
            )?.item {
                try await repo.deletePerson(person)
                assistant.assistantSay("Deleted \(person.name).")
                assistant.pendingActionsToken = UUID()
            } else {
                assistant.assistantSay("Which Split person or expense should I delete?")
            }
        } catch {
            assistant.assistantSay("I couldn't update Split: \(error.localizedDescription)")
        }

        return true
    }

    private static func handleTalk(intent: Intent, text: String, assistant: AIAssistantManager) async -> Bool {
        guard intent == .delete else { return false }

        do {
            let uid = try AIAuth.requireUID()
            let repo = CommsRepository()
            let cards = try await repo.fetchCards(for: uid)
            guard let card = match(
                in: cards,
                text: text,
                assistant: assistant,
                emptyMessage: "I don't see any Talk cards to delete.",
                noMatchMessage: "Which Talk card should I delete?",
                ambiguousPrefix: "I found more than one matching Talk card",
                candidate: { card in
                    MatchCandidate(label: card.title, searchText: "\(card.title) \(card.phrase)", amount: nil)
                }
            ) else { return true }

            try await repo.deleteCard(card)
            assistant.assistantSay("Deleted \(card.title).")
            assistant.pendingActionsToken = UUID()
        } catch {
            assistant.assistantSay("I couldn't update Talk: \(error.localizedDescription)")
        }

        return true
    }

    private static func matchSplitPerson(
        _ people: [SplitPersonRecord],
        text: String,
        assistant: AIAssistantManager
    ) -> SplitPersonRecord? {
        match(
            in: people,
            text: text,
            assistant: assistant,
            emptyMessage: "I don't see any people in Split.",
            noMatchMessage: "Which person should I delete?",
            ambiguousPrefix: "I found more than one matching person",
            candidate: { MatchCandidate(label: $0.name, searchText: $0.name, amount: nil) }
        )
    }

    private static func matchSplitExpense(
        _ expenses: [SplitExpenseRecord],
        text: String,
        assistant: AIAssistantManager
    ) -> SplitExpenseRecord? {
        match(
            in: expenses,
            text: text,
            assistant: assistant,
            emptyMessage: "I don't see any Split expenses.",
            noMatchMessage: "Which expense should I delete?",
            ambiguousPrefix: "I found more than one matching expense",
            candidate: { MatchCandidate(label: $0.title, searchText: $0.title, amount: $0.amount) }
        )
    }

    private static func match<T>(
        in items: [T],
        text: String,
        assistant: AIAssistantManager,
        emptyMessage: String,
        noMatchMessage: String,
        ambiguousPrefix: String,
        candidate: (T) -> MatchCandidate
    ) -> T? {
        guard !items.isEmpty else {
            assistant.assistantSay(emptyMessage)
            return nil
        }

        let results = rankedMatches(in: items, text: text, candidate: candidate)
        guard let first = results.first, first.score > 0 else {
            assistant.assistantSay(noMatchMessage)
            return nil
        }

        if results.count > 1, abs(first.score - results[1].score) < 0.2 {
            let options = results.prefix(3).map { candidate($0.item).label }.joined(separator: ", ")
            assistant.assistantSay("\(ambiguousPrefix): \(options). Say the exact name.")
            return nil
        }

        return first.item
    }

    private static func bestMatch<T>(
        in items: [T],
        text: String,
        candidate: (T) -> MatchCandidate
    ) -> (item: T, score: Double)? {
        rankedMatches(in: items, text: text, candidate: candidate).first
    }

    private static func rankedMatches<T>(
        in items: [T],
        text: String,
        candidate: (T) -> MatchCandidate
    ) -> [(item: T, score: Double)] {
        let query = normalizedTarget(from: text)
        let amount = parseAmount(from: text)
        let queryTokens = tokens(in: query)

        return items
            .map { item -> (item: T, score: Double) in
                let candidate = candidate(item)
                let searchable = normalized(candidate.searchText)
                var score = 0.0

                if !query.isEmpty {
                    if searchable == query {
                        score += 4
                    } else if searchable.contains(query) {
                        score += 2.5
                    }

                    let searchableTokens = Set(tokens(in: searchable))
                    let tokenHits = queryTokens.filter { searchableTokens.contains($0) }.count
                    if !queryTokens.isEmpty {
                        score += Double(tokenHits) / Double(queryTokens.count)
                    }
                }

                if let amount, let candidateAmount = candidate.amount, abs(candidateAmount - amount) < 0.01 {
                    score += 2
                }

                return (item, score)
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in lhs.score > rhs.score }
    }

    private static func intent(for text: String) -> Intent? {
        let lowered = text.lowercased()

        if containsAny(lowered, ["delete", "remove", "erase"]) {
            return .delete
        }

        if containsAny(lowered, ["mark unpaid", "mark un-paid", "mark upcoming", "set upcoming", "reopen", "undo complete", "not done"]) {
            return .reopen
        }

        if containsAny(lowered, ["mark paid", "set paid", "paid off", "i paid", "paid "]) {
            return .markPaid
        }

        if containsAny(lowered, ["complete", "mark done", "finished", "finish ", "done with"]) {
            return .complete
        }

        return nil
    }

    private static func normalizedTarget(from text: String) -> String {
        var value = normalized(text)
        let removablePatterns = [
            #"\b(delete|remove|erase|complete|completed|finish|finished|mark|set|as|done|paid|unpaid|upcoming|reopen|undo|with)\b"#,
            #"\b(transaction|entry|finance|task|todo|to do|bill|income|flow|expense|split|person|people|talk|card)\b"#,
            #"\b(the|a|an|my|this|that|please|can|you|i)\b"#,
            #"\$?\b\d+(?:\.\d{1,2})?\b"#
        ]

        for pattern in removablePatterns {
            value = value.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        return value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9.\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(in text: String) -> [String] {
        normalized(text)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 }
    }

    private static func parseAmount(from text: String) -> Double? {
        let pattern = #"\$?\b(\d+(?:\.\d{1,2})?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let amountRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Double(text[amountRange])
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func splitPersonNames(from text: String) -> [String]? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = value.lowercased()
        guard parseAmount(from: value) == nil else { return nil }
        guard lowered.hasPrefix("add ") || lowered.hasPrefix("create ") else { return nil }
        guard lowered.contains("person") || lowered.contains("people") || lowered.contains(",") || lowered.contains(" and ") else {
            return nil
        }

        value = value.replacingOccurrences(
            of: #"(?i)^(add|create)\s+(?:(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+)?(?:person|people|persons)\s*|^(add|create)\s+"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(of: #"(?i)\b(to|in)\s+split\b"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)\bpeople\b|\bpersons\b|\bperson\b"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)\band\b"#, with: ",", options: .regularExpression)

        let names = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .filter { !$0.isEmpty }

        return names.isEmpty ? nil : names
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
