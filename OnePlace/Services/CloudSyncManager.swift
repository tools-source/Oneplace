import CloudKit
import Network
import SwiftData
import SwiftUI

@MainActor
final class CloudSyncManager: ObservableObject {
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var isNetworkAvailable: Bool = true
    @Published private(set) var lastSyncAttempt: Date?
    @Published var errorMessage: String?

    private let container: CKContainer
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "CloudSyncMonitor")

    init(containerIdentifier: String) {
        container = CKContainer(identifier: containerIdentifier)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        pathMonitor.start(queue: pathQueue)
        Task { await refreshStatus() }
    }

    deinit {
        pathMonitor.cancel()
    }

    var isICloudAvailable: Bool {
        accountStatus == .available && isICloudDriveEnabled
    }

    var statusMessage: String? {
        switch accountStatus {
        case .available:
            if !isNetworkAvailable {
                return "Network unavailable. Connect to the internet to sync."
            }
            if !isICloudDriveEnabled {
                return "iCloud Drive is disabled. Enable it in Settings to sync."
            }
            return nil
        case .noAccount:
            return "Not signed into iCloud."
        case .restricted:
            return "iCloud access is restricted on this device."
        case .couldNotDetermine:
            return "Unable to determine iCloud status."
        @unknown default:
            return "Unknown iCloud status."
        }
    }

    func refreshStatus() async {
        lastSyncAttempt = Date()
        do {
            accountStatus = try await container.accountStatus()
        } catch {
            errorMessage = "Unable to check iCloud status."
        }
    }

    func forceSync(modelContext: ModelContext) async {
        lastSyncAttempt = Date()
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Unable to save changes for sync."
        }
        await refreshStatus()
    }

    func clearError() {
        errorMessage = nil
    }

    private var isICloudDriveEnabled: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
