import SwiftUI
import UserNotifications

struct SettingsView: View {
@EnvironmentObject private var authManager: AuthManager

@State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
@State private var pendingRequests: [UNNotificationRequest] = []
@State private var isRefreshing = false
@State private var isDeletingAccount = false
@State private var showDeleteAccountConfirmation = false
@State private var deleteAccountErrorMessage: String?

var body: some View {
    NavigationStack {
        List {
            accountSection
            notificationStatusSection
            scheduledRemindersSection
            #if DEBUG
            debugSection
            #endif
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Settings")
        .refreshable {
            await refreshStatus()
        }
        .task {
            await refreshStatus()
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await handleDeleteAccount()
                }
            }
        } message: {
            Text("This action is permanent and cannot be undone. All your data will be deleted.")
        }
        .alert("Unable to Delete Account", isPresented: deleteAccountErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountErrorMessage ?? "Please try again.")
        }
    }
}

private var accountSection: some View {
    Section("Account") {
        HStack {
            Text("User")
            Spacer()
            Text(userDisplayText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .listRowBackground(Color.clear)

        if case .signedIn(let user) = authManager.authState {
            HStack {
                Text("Provider")
                Spacer()
                Text(user.provider.capitalized)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }

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
    }
}

private var isUserSignedIn: Bool {
    if case .signedIn = authManager.authState { return true }
    return false
}

private var deleteAccountErrorBinding: Binding<Bool> {
    Binding(
        get: { deleteAccountErrorMessage != nil },
        set: { isPresented in
            if !isPresented {
                deleteAccountErrorMessage = nil
            }
        }
    )
}

private func handleDeleteAccount() async {
    guard !isDeletingAccount else { return }
    isDeletingAccount = true
    deleteAccountErrorMessage = nil

    do {
        try await authManager.deleteAccount()
    } catch {
        if authManager.isUserCanceledAuth(error) {
            deleteAccountErrorMessage = nil
            isDeletingAccount = false
            return
        }

        if let errorMessage = authManager.errorMessage, !errorMessage.isEmpty {
            deleteAccountErrorMessage = errorMessage
        } else {
            deleteAccountErrorMessage = error.localizedDescription
        }
    }

    isDeletingAccount = false
}

private var userDisplayText: String {
    switch authManager.authState {
    case .signedIn(let user):
        let fullName = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fullName, !fullName.isEmpty { return fullName }

        let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, !email.isEmpty { return email }

        return user.uid

    case .loading:
        return "Loading…"
    case .signedOut:
        return "Not signed in"
    }
}

private var notificationStatusSection: some View {
    Section("Notifications") {
        HStack {
            Text("Permission")
            Spacer()
            Text(statusLabel)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)

        if authorizationStatus != .authorized {
            Button("Enable Notifications") {
                Task {
                    do {
                        _ = try await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound, .badge])
                    } catch {
                        return
                    }
                    await refreshStatus()
                }
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
        }

        if authorizationStatus == .denied {
            Text("Notifications are disabled. Open iOS Settings and allow notifications for Oneplace.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }
}

private var scheduledRemindersSection: some View {
    Section("Scheduled Reminders") {
        if pendingRequests.isEmpty {
            Text("No scheduled reminders.")
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        } else {
            ForEach(pendingRequests, id: \.identifier) { request in
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.content.title)
                        .font(.subheadline)
                    Text(request.content.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let nextDate = nextTriggerDate(for: request) {
                        Text(nextDate, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
    }
}

#if DEBUG
private var debugSection: some View {
    Section("Debug") {
        Button("Test notification in 10 seconds") {
            Task {
                let testDate = Date().addingTimeInterval(10)
                await scheduleReminder(
                    id: "debug-test-notification",
                    title: "Oneplace Test",
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

private var statusLabel: String {
    switch authorizationStatus {
    case .authorized, .provisional, .ephemeral:
        return "Granted"
    case .denied:
        return "Denied"
    case .notDetermined:
        return "Not set"
    @unknown default:
        return "Unknown"
    }
}

private func refreshStatus() async {
    if isRefreshing { return }
    isRefreshing = true
    let center = UNUserNotificationCenter.current()
    let settings = await notificationSettings(from: center)
    authorizationStatus = settings.authorizationStatus
    pendingRequests = await pendingNotificationRequests(from: center)
    isRefreshing = false
}

private func nextTriggerDate(for request: UNNotificationRequest) -> Date? {
    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
        return trigger.nextTriggerDate()
    }
    return nil
}

private func notificationSettings(from center: UNUserNotificationCenter) async -> UNNotificationSettings {
    await withCheckedContinuation { continuation in
        center.getNotificationSettings { settings in
            continuation.resume(returning: settings)
        }
    }
}

private func pendingNotificationRequests(from center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
    await withCheckedContinuation { continuation in
        center.getPendingNotificationRequests { requests in
            continuation.resume(returning: requests)
        }
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
    do {
        try await center.add(request)
    } catch {
        return
    }
}

}

#Preview {
SettingsView()
.environmentObject(AuthManager())
}
