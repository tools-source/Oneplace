import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingRequests: [UNNotificationRequest] = []
    @State private var isRefreshing = false
    @State private var anonymousId: String = "—"
    @State private var showKeychainAlert = false
    @State private var keychainAlertMessage = ""
    #if DEBUG
    @State private var proUnlocked = false
    @State private var earlyUser = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                notificationStatusSection
                scheduledRemindersSection
                keychainTestSection
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
                refreshAnonymousId()
                #if DEBUG
                loadDebugInfo()
                #endif
            }
            .alert("Keychain Test", isPresented: $showKeychainAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(keychainAlertMessage)
            }
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
                        _ = await NotificationManager.shared.requestAuthorization()
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
                            NotificationManager.shared.cancelReminder(id: request.identifier)
                            Task { await refreshStatus() }
                        } label: {
                            Label("Cancel", systemImage: "bell.slash")
                        }
                    }
                }
            }
        }
    }

    private var keychainTestSection: some View {
        Section("Keychain Test") {
            LabeledContent("Anonymous ID", value: anonymousId)
                .textSelection(.enabled)

            Button("Regenerate ID") {
                anonymousId = IdentityManager.shared.regenerateAnonymousId()
                keychainAlertMessage = "Anonymous ID regenerated."
                showKeychainAlert = true
            }

            Button("Clear ID", role: .destructive) {
                IdentityManager.shared.clearAnonymousId()
                anonymousId = "—"
                keychainAlertMessage = "Anonymous ID cleared."
                showKeychainAlert = true
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            Button("Test notification in 10 seconds") {
                Task {
                    let testDate = Date().addingTimeInterval(10)
                    await NotificationManager.shared.scheduleReminder(
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

            LabeledContent("Pro unlocked", value: proUnlocked ? "Yes" : "No")
            LabeledContent("Early user", value: earlyUser ? "Yes" : "No")
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
        let settings = await NotificationManager.shared.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        pendingRequests = await NotificationManager.shared.listPendingReminders()
        isRefreshing = false
    }

    #if DEBUG
    private func loadDebugInfo() {
        proUnlocked = IdentityManager.shared.isProUnlocked()
        earlyUser = IdentityManager.shared.isEarlyUser()
    }
    #endif

    private func refreshAnonymousId() {
        if let storedId = IdentityManager.shared.getAnonymousId() {
            anonymousId = storedId
        } else {
            anonymousId = "—"
        }
    }

    private func nextTriggerDate(for request: UNNotificationRequest) -> Date? {
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        return nil
    }
}

#Preview {
    SettingsView()
}
