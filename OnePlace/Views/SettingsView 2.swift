import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingRequests: [UNNotificationRequest] = []
    @State private var isRefreshing = false
    @State private var isUpdatingLiveActivity = false
    @State private var isLiveActivityEnabled = true
    @State private var isLiveActivityRunning = false
    @State private var isDeletingAccount = false
    @State private var showDeleteAccountConfirmation = false
    @State private var deleteAccountErrorMessage: String?
    @State private var searchText = ""
    @State private var settingsAIResponse: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OnePlaceAISearchBar(
                        text: $searchText,
                        placeholder: "Search or ask OnePlace",
                        isProcessing: isRefreshing,
                        onSubmit: handleSearchSubmit
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
                }

                profileSection
                notificationStatusSection
                liveActivitySection
                scheduledRemindersSection
                #if DEBUG
                debugSection
                #endif
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.backgroundGradient.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: DesignSystem.tabBarContentInset)
            }
            .navigationTitle("Settings")
            .refreshable {
                await refreshStatus()
            }
            .task {
                await refreshStatus()
            }
            .onChange(of: authManager.authState) { _, _ in
                Task { await refreshStatus() }
            }
            .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await handleDeleteAccount() }
                }
            } message: {
                Text("This action is permanent and cannot be undone. All your data will be deleted.")
            }
            .alert("Unable to Delete Account", isPresented: deleteAccountErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteAccountErrorMessage ?? "Please try again.")
            }
            .alert("OnePlace AI", isPresented: settingsAIResponseBinding) {
                Button("OK", role: .cancel) { settingsAIResponse = nil }
            } message: {
                Text(settingsAIResponse ?? "")
            }
        }
    }

    // MARK: - Account Section

    private var profileSection: some View {
        Section {
            AppCard {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.accentSoft)
                            .frame(width: 52, height: 52)
                        Text(avatarInitials)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(DesignSystem.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(userDisplayText)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if case .signedIn(let user) = authManager.authState {
                            Text("via \(user.provider.capitalized)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
            .disabled(isDeletingAccount)
            .listRowBackground(Color.clear)

            Button {
                showDeleteAccountConfirmation = true
            } label: {
                HStack {
                    Text("Delete Account")
                        .foregroundStyle(DesignSystem.oweColor)
                    if isDeletingAccount {
                        Spacer()
                        ProgressView()
                            .tint(DesignSystem.oweColor)
                    }
                }
            }
            .disabled(isDeletingAccount || !isUserSignedIn)
            .listRowBackground(Color.clear)
        } header: {
            Text("Account")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
    }

    private var notificationStatusSection: some View {
        Section {
            HStack {
                Label("Permission", systemImage: "bell")
                Spacer()
                Text(statusLabel)
                    .foregroundStyle(
                        authorizationStatus == .authorized
                            ? DesignSystem.gainColor
                            : authorizationStatus == .denied
                                ? DesignSystem.oweColor
                                : .secondary
                    )
                    .font(.subheadline.weight(.medium))
            }
            .listRowBackground(Color.clear)

            if authorizationStatus != .authorized {
                Button {
                    Task {
                        do {
                            _ = try await UNUserNotificationCenter.current()
                                .requestAuthorization(options: [.alert, .sound, .badge])
                        } catch {
                            return
                        }
                        await refreshStatus()
                    }
                } label: {
                    Label("Enable Notifications", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.accentColor)
                .listRowBackground(Color.clear)
            }

            if authorizationStatus == .denied {
                Label(
                    "Open iOS Settings to re-enable notifications for OnePlace.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Notifications")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
    }

    private var scheduledRemindersSection: some View {
        Section {
            if pendingRequests.isEmpty {
                Label("No scheduled reminders.", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(pendingRequests, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.content.title)
                            .font(.subheadline.weight(.medium))
                        Text(request.content.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let nextDate = nextTriggerDate(for: request) {
                            Text(nextDate, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions {
                        Button(role: .destructive) {
                            UNUserNotificationCenter.current()
                                .removePendingNotificationRequests(withIdentifiers: [request.identifier])
                            Task { await refreshStatus() }
                        } label: {
                            Label("Cancel", systemImage: "bell.slash")
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Scheduled Reminders")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }

    private var liveActivitySection: some View {
        Section {
            Toggle(isOn: liveActivityToggleBinding) {
                Label("Lock Screen Tasks", systemImage: "rectangle.on.rectangle")
            }
            .disabled(!isUserSignedIn || isUpdatingLiveActivity)
            .listRowBackground(Color.clear)

            HStack {
                Label("Status", systemImage: liveActivityStatusSymbol)
                Spacer()
                Text(liveActivityStatusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isLiveActivityRunning ? DesignSystem.gainColor : .secondary)
            }
            .listRowBackground(Color.clear)

            if isUpdatingLiveActivity {
                HStack {
                    ProgressView()
                    Text("Updating")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Live Activity")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            Button("Test notification in 10 seconds") {
                Task {
                    let testDate = Date().addingTimeInterval(10)
                    await scheduleReminder(
                        id: currentUserID.map { "task-reminder-\($0)-debug-test-notification" } ?? "debug-test-notification",
                        title: "OnePlace Test",
                        body: "This is a test reminder from Settings.",
                        date: testDate,
                        repeats: false,
                        calendarComponents: nil
                    )
                    await refreshStatus()
                }
            }
            .listRowBackground(Color.clear)
        }
    }
    #endif

    // MARK: - Helpers

    private var isUserSignedIn: Bool {
        if case .signedIn = authManager.authState { return true }
        return false
    }

    private var currentUserID: String? {
        if case .signedIn(let user) = authManager.authState {
            return user.uid
        }

        return nil
    }

    private var avatarInitials: String {
        switch authManager.authState {
        case .signedIn(let user):
            let name = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let parts = name.split(separator: " ")
            if parts.count >= 2,
               let f = parts[0].first, let l = parts[1].first {
                return "\(f)\(l)".uppercased()
            }
            return String(name.prefix(2)).uppercased().ifEmpty("OP")
        default:
            return "OP"
        }
    }

    private var deleteAccountErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteAccountErrorMessage != nil },
            set: { if !$0 { deleteAccountErrorMessage = nil } }
        )
    }

    private var settingsAIResponseBinding: Binding<Bool> {
        Binding(
            get: { settingsAIResponse != nil },
            set: { if !$0 { settingsAIResponse = nil } }
        )
    }

    private var liveActivityToggleBinding: Binding<Bool> {
        Binding(
            get: { isLiveActivityEnabled },
            set: { newValue in
                isLiveActivityEnabled = newValue
                Task { await setLiveActivityEnabled(newValue) }
            }
        )
    }

    private var liveActivityStatusText: String {
        if isLiveActivityRunning { return "Active" }
        if isLiveActivityEnabled { return "On" }
        return "Off"
    }

    private var liveActivityStatusSymbol: String {
        if isLiveActivityRunning { return "checkmark.circle.fill" }
        if isLiveActivityEnabled { return "clock.badge.checkmark" }
        return "power.circle"
    }

    private func handleDeleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        deleteAccountErrorMessage = nil

        do {
            try await authManager.deleteAccount()
        } catch {
            if authManager.isUserCanceledAuth(error) {
                isDeletingAccount = false
                return
            }
            deleteAccountErrorMessage = authManager.errorMessage?.nilIfEmpty ?? error.localizedDescription
        }

        isDeletingAccount = false
    }

    private func handleSearchSubmit() {
        let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let lowered = prompt.lowercased()
        if lowered.contains("notification") || lowered.contains("reminder") {
            settingsAIResponse = "Notifications are \(statusLabel.lowercased()). You have \(pendingRequests.count) scheduled reminder\(pendingRequests.count == 1 ? "" : "s")."
        } else if lowered.contains("account") || lowered.contains("user") || lowered.contains("email") {
            settingsAIResponse = "You are signed in as \(userDisplayText)."
        } else if lowered.contains("delete") || lowered.contains("sign out") {
            settingsAIResponse = "For safety, use the visible buttons below to sign out or delete your account."
        } else {
            settingsAIResponse = "I can answer account, notification, and reminder questions from Settings."
        }

        searchText = ""
    }

    private var userDisplayText: String {
        switch authManager.authState {
        case .signedIn(let user):
            if let name = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
            if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty { return email }
            return user.uid
        case .loading:
            return "Loading…"
        case .signedOut:
            return "Not signed in"
        }
    }

    private var statusLabel: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "Granted"
        case .denied:                                return "Denied"
        case .notDetermined:                         return "Not set"
        @unknown default:                            return "Unknown"
        }
    }

    private func refreshStatus() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let center = UNUserNotificationCenter.current()
        let settings = await notificationSettings(from: center)
        authorizationStatus = settings.authorizationStatus
        pendingRequests = await pendingNotificationRequests(from: center)
            .filter { isCurrentUserReminder($0) }
        isLiveActivityEnabled = OnePlaceLiveActivityController.shared.isUserEnabled
        isLiveActivityRunning = OnePlaceLiveActivityController.shared.isRunning
        isRefreshing = false
    }

    private func setLiveActivityEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            await startLiveActivity()
        } else {
            await stopLiveActivity()
        }
    }

    private func startLiveActivity() async {
        guard let currentUserID else {
            isLiveActivityEnabled = OnePlaceLiveActivityController.shared.isUserEnabled
            return
        }

        isUpdatingLiveActivity = true
        defer { isUpdatingLiveActivity = false }

        do {
            let tasks = try await OnePlaceTaskSyncCoordinator.syncTasks(
                ownerUserId: currentUserID,
                preferOnePlaceChanges: true
            )
            let started = await OnePlaceLiveActivityController.shared.startOrUpdateAndWait(with: tasks)
            isLiveActivityEnabled = OnePlaceLiveActivityController.shared.isUserEnabled
            isLiveActivityRunning = OnePlaceLiveActivityController.shared.isRunning
            if !started {
                settingsAIResponse = OnePlaceLiveActivityController.shared.lastStatus
            }
        } catch {
            settingsAIResponse = "I couldn't start the Live Activity: \(error.localizedDescription)"
        }
    }

    private func stopLiveActivity() async {
        isUpdatingLiveActivity = true
        defer { isUpdatingLiveActivity = false }

        await OnePlaceLiveActivityController.shared.turnOff()
        isLiveActivityEnabled = OnePlaceLiveActivityController.shared.isUserEnabled
        isLiveActivityRunning = OnePlaceLiveActivityController.shared.isRunning
    }

    private func isCurrentUserReminder(_ request: UNNotificationRequest) -> Bool {
        guard let currentUserID else { return false }
        return request.identifier.hasPrefix("task-reminder-\(currentUserID)-")
    }

    private func nextTriggerDate(for request: UNNotificationRequest) -> Date? {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
    }

    private func notificationSettings(from center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { continuation.resume(returning: $0) }
        }
    }

    private func pendingNotificationRequests(from center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { continuation.resume(returning: $0) }
        }
    }

    private func scheduleReminder(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool,
        calendarComponents: DateComponents?
    ) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = calendarComponents
            ?? Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try? await center.add(request)
    }
}

// MARK: - String Helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
}
