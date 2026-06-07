import AVFoundation
import AppIntents
import BackgroundTasks
import SwiftUI
import FirebaseAuth
import FirebaseCore
import SwiftData
import Speech
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()
        OnePlaceRemindersChangeObserver.shared.start()
        registerTaskBackgroundRefresh()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        OnePlaceTaskSyncCoordinator.scheduleBackgroundRefresh()
    }

    private func registerTaskBackgroundRefresh() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: OnePlaceTaskSyncCoordinator.backgroundRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                self.handleTaskBackgroundRefresh(refreshTask)
            }
        }
    }

    @MainActor
    private func handleTaskBackgroundRefresh(_ task: BGAppRefreshTask) {
        OnePlaceTaskSyncCoordinator.scheduleBackgroundRefresh()

        let syncTask = Task {
            do {
                try await OnePlaceTaskSyncCoordinator.syncCurrentUserTasks()
                task.setTaskCompleted(success: true)
            } catch {
                print("OnePlace task background refresh failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            syncTask.cancel()
        }
    }
}

@main
struct OnePlaceApp: App {
    // ✅ register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var dataController: AppDataController
    @StateObject private var authManager: AuthManager
    @State private var didRestoreSession = false

    init() {
        let controller = AppDataController()
        _dataController = StateObject(wrappedValue: controller)

        _authManager = StateObject(wrappedValue: AuthManager())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.authState {
                case .signedIn(let user):
                    RootTabView(ownerUserId: user.uid)
                case .loading:
                    ProgressView("Loading…")
                case .signedOut:
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .tint(DesignSystem.accentColor)
            .onOpenURL { url in
                if let tabRawValue = OnePlaceDeepLink.tabRawValue(for: url) {
                    UserDefaults.standard.set(tabRawValue, forKey: "root.selectedTab")
                }
            }
            .task {
                guard !didRestoreSession else { return }
                didRestoreSession = true
                await authManager.restoreSessionFromProvider()
                await AppPermissionBootstrap.requestInitialPermissionsIfNeeded()
                OnePlaceTaskSyncCoordinator.scheduleBackgroundRefresh()
            }
        }
        .modelContainer(dataController.container)
    }
}

private enum AppPermissionBootstrap {
    private static let didRequestKey = "app.permissions.didRequestInitial.v1"

    @MainActor
    static func requestInitialPermissionsIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: didRequestKey) else { return }
        UserDefaults.standard.set(true, forKey: didRequestKey)

        await requestNotificationsIfNeeded()
        await requestSpeechRecognitionIfNeeded()
        await requestMicrophoneIfNeeded()
    }

    private static func requestNotificationsIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await notificationSettings(from: center)
        guard settings.authorizationStatus == .notDetermined else { return }

        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func requestSpeechRecognitionIfNeeded() async {
        guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else { return }

        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { _ in
                continuation.resume()
            }
        }
    }

    private static func requestMicrophoneIfNeeded() async {
        let permission = AVAudioApplication.shared.recordPermission
        guard permission == .undetermined else { return }

        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { _ in
                continuation.resume()
            }
        }
    }

    private static func notificationSettings(from center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}

enum OnePlaceSiriArea: String, AppEnum {
    case finance
    case flow
    case organizer
    case split
    case talk

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "OnePlace Area"

    static var caseDisplayRepresentations: [OnePlaceSiriArea: DisplayRepresentation] = [
        .finance: "Finance",
        .flow: "Flow",
        .organizer: "Organizer",
        .split: "Split",
        .talk: "Talk"
    ]
}

struct AskOnePlaceIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask OnePlace"
    static var description = IntentDescription("Ask OnePlace to add a transaction, bill, task, split expense, person, or talk card.")

    @Parameter(title: "Request", description: "What should OnePlace do?")
    var request: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask OnePlace \(\.$request)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.handle(request)
        return .result(dialog: "\(message)")
    }
}

struct AddFinanceSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Finance Transaction"
    static var description = IntentDescription("Add an income or expense to Finance using natural language.")

    @Parameter(title: "Transaction", description: "For example, My mom owes me $200 for Macy's shopping.")
    var transaction: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$transaction) to Finance")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.addFinance(transaction)
        return .result(dialog: "\(message)")
    }
}

struct AddFlowSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Flow Item"
    static var description = IntentDescription("Add a bill, recurring income, due date, or reminder to Flow.")

    @Parameter(title: "Flow Item", description: "For example, monthly bill for my credit card for $300 reminder on the 24th.")
    var item: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$item) to Flow")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.addFlow(item)
        return .result(dialog: "\(message)")
    }
}

struct AddOrganizerSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Organizer Task"
    static var description = IntentDescription("Add a task or reminder to Organizer.")

    @Parameter(title: "Task", description: "For example, remind me to call the bank tomorrow.")
    var task: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$task) to Organizer")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.addOrganizer(task)
        return .result(dialog: "\(message)")
    }
}

struct StartTasksLiveActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Tasks Live Activity"
    static var description = IntentDescription("Start or refresh the OnePlace Organizer tasks Live Activity.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.startTasksLiveActivity()
        return .result(dialog: "\(message)")
    }
}

struct SyncOrganizerRemindersIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Organizer Reminders"
    static var description = IntentDescription("Sync OnePlace Organizer tasks with the OnePlace Tasks list in Apple Reminders.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.syncOrganizerReminders()
        return .result(dialog: "\(message)")
    }
}

struct AddSplitSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Split Item"
    static var description = IntentDescription("Add a person or shared expense to Split.")

    @Parameter(title: "Split Request", description: "For example, add dinner $80 paid by Yahya split with Majdi.")
    var splitRequest: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$splitRequest) to Split")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.addSplit(splitRequest)
        return .result(dialog: "\(message)")
    }
}

struct AddTalkSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Talk Card"
    static var description = IntentDescription("Create a text Talk card from a spoken phrase.")

    @Parameter(title: "Card Phrase", description: "For example, create a card that says I need water.")
    var phrase: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create Talk card \(\.$phrase)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await OnePlaceSiriWriter.addTalk(phrase)
        return .result(dialog: "\(message)")
    }
}

struct OpenOnePlaceTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Open OnePlace Tab"
    static var description = IntentDescription("Open OnePlace and continue in a specific area.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Area")
    var area: OnePlaceSiriArea

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$area) in OnePlace")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening \(area.rawValue.capitalized) in OnePlace.")
    }
}

struct OnePlaceAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddOrganizerSiriIntent(),
            phrases: [
                "Add organizer task in \(.applicationName)",
                "Add task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: StartTasksLiveActivityIntent(),
            phrases: [
                "Start tasks live activity in \(.applicationName)",
                "Show my tasks on the lock screen in \(.applicationName)"
            ],
            shortTitle: "Start Live",
            systemImageName: "rectangle.on.rectangle"
        )

        AppShortcut(
            intent: SyncOrganizerRemindersIntent(),
            phrases: [
                "Sync reminders in \(.applicationName)",
                "Sync organizer reminders in \(.applicationName)"
            ],
            shortTitle: "Sync Reminders",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}

@MainActor
private enum OnePlaceSiriWriter {
    static func handle(_ request: String) async -> String {
        let prompt = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            return "Tell OnePlace what you want to add."
        }

        let lowered = prompt.lowercased()

        if isSplitPrompt(lowered) {
            return await addSplit(prompt)
        }

        if isTalkPrompt(lowered) {
            return await addTalk(prompt)
        }

        if isOrganizerPrompt(lowered) {
            return await addOrganizer(prompt)
        }

        if isFlowPrompt(lowered) {
            return await addFlow(prompt)
        }

        if lowered.range(of: #"\$?\d+(?:\.\d{1,2})?\b"#, options: .regularExpression) != nil ||
            lowered.contains("owes me") ||
            lowered.contains("i owe") {
            return await addFinance(prompt)
        }

        return "I could not tell where to add that. Try saying finance, flow, task, split, or talk card."
    }

    static func addFinance(_ request: String) async -> String {
        do {
            let uid = try signedInUserId()
            let result = await FinanceAIInterpreter().interpret(
                prompt: request,
                fallbackCategory: "Other Expense",
                now: .now,
                timeZone: .autoupdatingCurrent
            )

            let interpretation: FinancePromptInterpretation
            switch result {
            case .success(let value):
                interpretation = value
            case .failure:
                guard let fallback = FinancePromptInterpreter.interpret(request, fallbackCategory: "Other Expense", now: .now) else {
                    return "I could not understand that finance transaction."
                }
                interpretation = fallback
            }

            guard interpretation.draft.amount > 0 else {
                return "I need an amount before I can add that finance transaction."
            }

            let record = try await FinanceRepository().createEntry(for: uid, draft: interpretation.draft)
            return "Added \(record.entryDescription) for \(StatCard.currencyString(for: record.amount)) to Finance."
        } catch {
            return failureMessage(for: error)
        }
    }

    static func addFlow(_ request: String) async -> String {
        do {
            _ = try signedInUserId()
            guard let draft = FlowPromptInterpreter.interpret(request), draft.amount > 0 else {
                return "I need a bill or income amount before I can add that to Flow."
            }

            let viewModel = FlowViewModel()
            await viewModel.addItem(draft: draft)
            if let errorMessage = viewModel.errorMessage {
                return errorMessage
            }

            return "Added \(draft.frequency.rawValue) \(draft.title) for \(StatCard.currencyString(for: draft.amount)) to Flow."
        } catch {
            return failureMessage(for: error)
        }
    }

    static func addOrganizer(_ request: String) async -> String {
        do {
            let uid = try signedInUserId()
            let draft = OrganizerPromptInterpreter.interpret(request)
            try await TaskRepository().createTask(for: uid, draft: draft)
            try await OnePlaceTaskSyncCoordinator.syncTasks(ownerUserId: uid, preferOnePlaceChanges: true)
            return "Added \(draft.title) to Organizer."
        } catch {
            return failureMessage(for: error)
        }
    }

    static func startTasksLiveActivity() async -> String {
        do {
            _ = try signedInUserId()
            try await OnePlaceTaskSyncCoordinator.syncCurrentUserTasks()
            return "Started the Organizer tasks Live Activity."
        } catch {
            return failureMessage(for: error)
        }
    }

    static func syncOrganizerReminders() async -> String {
        do {
            _ = try signedInUserId()
            try await OnePlaceTaskSyncCoordinator.syncCurrentUserTasks()
            return "Synced Organizer with Apple Reminders."
        } catch {
            return failureMessage(for: error)
        }
    }

    static func addSplit(_ request: String) async -> String {
        do {
            let uid = try signedInUserId()
            let repository = SplitRepository()

            if let personName = SplitPromptInterpreter.personName(from: request) {
                _ = try await repository.createPerson(for: uid, name: personName)
                return "Added \(personName) to Split."
            }

            let people = try await repository.fetchPeople(for: uid)
            guard let draft = SplitPromptInterpreter.expenseDraft(from: request, people: people), draft.amount > 0 else {
                return people.isEmpty
                    ? "Add people to Split first, then I can add expenses."
                    : "I need an amount and split details before I can add that expense."
            }

            _ = try await repository.createExpense(for: uid, draft: draft)
            return "Added \(draft.title) for \(StatCard.currencyString(for: draft.amount)) to Split."
        } catch {
            return failureMessage(for: error)
        }
    }

    static func addTalk(_ request: String) async -> String {
        do {
            let uid = try signedInUserId()
            let draft = TalkPromptInterpreter.interpret(request)
            try await CommsRepository().createCard(for: uid, draft: draft)
            return "Created the Talk card \(draft.title)."
        } catch {
            return failureMessage(for: error)
        }
    }

    private static func signedInUserId() throws -> String {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw OnePlaceSiriError.notSignedIn
        }

        return uid
    }

    private static func failureMessage(for error: Error) -> String {
        if let siriError = error as? OnePlaceSiriError {
            return siriError.errorDescription ?? "OnePlace could not complete that."
        }

        return "OnePlace could not complete that: \(error.localizedDescription)"
    }

    private static func isFlowPrompt(_ prompt: String) -> Bool {
        [
            "flow", "bill", "bowl", "monthly", "weekly", "biweekly", "quarterly",
            "yearly", "annual", "due", "reminder", "remind", "subscription",
            "credit card", "rent", "electric", "water", "income"
        ].contains(where: prompt.contains)
    }

    private static func isOrganizerPrompt(_ prompt: String) -> Bool {
        [
            "organizer", "task", "todo", "to do", "remind me to", "deadline"
        ].contains(where: prompt.contains)
    }

    private static func isSplitPrompt(_ prompt: String) -> Bool {
        [
            "split", "paid by", "shared", "add person", "owe each other", "settle"
        ].contains(where: prompt.contains)
    }

    private static func isTalkPrompt(_ prompt: String) -> Bool {
        [
            "talk card", "card that says", "create a card", "communication card"
        ].contains(where: prompt.contains)
    }
}

private enum OnePlaceSiriError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Open OnePlace and sign in before using Siri shortcuts."
        }
    }
}
