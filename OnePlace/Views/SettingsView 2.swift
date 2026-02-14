import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingRequests: [UNNotificationRequest] = []
    @State private var isRefreshing = false

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
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .refreshable {
                await refreshStatus()
            }
            .task {
                await refreshStatus()
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            HStack {
                Text("User")
                Spacer()
                Text(userIdText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if case .signedIn(let user) = authManager.authState {
                HStack {
                    Text("Provider")
                    Spacer()
                    Text(user.provider.capitalized)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        }
    }
    private var userIdText: String {
        switch authManager.authState {
        case .signedIn(let user):
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
            }

            if authorizationStatus == .denied {
                Text("Notifications are disabled. Open iOS Settings and allow notifications for Oneplace.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scheduledRemindersSection: some View {
        Section("Scheduled Reminders") {
            if pendingRequests.isEmpty {
                Text("No scheduled reminders.")
                    .foregroundStyle(.secondary)
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
        .modelContainer(SampleData.makeContainer())
        .environmentObject(AuthManager())
}
