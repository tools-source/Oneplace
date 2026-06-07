import Foundation

enum OnePlaceTaskCache {
    static let appGroupID = "group.com.one-place.app.shared"

    private static let toggleTimestampKey = "oneplace.lockScreenToggle.timestamp"
    private static let tasksFilename = "tasks.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(tasksFilename)
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ tasks: [OnePlaceLiveTask]) {
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(tasks) else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }

    static func load() -> [OnePlaceLiveTask] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let tasks = try? JSONDecoder().decode([OnePlaceLiveTask].self, from: data) else {
            return []
        }

        return tasks
    }

    static func markLockScreenToggle() {
        defaults?.set(Date().timeIntervalSince1970, forKey: toggleTimestampKey)
    }

    static func hasRecentLockScreenToggle(seconds: TimeInterval = 45) -> Bool {
        let timestamp = defaults?.double(forKey: toggleTimestampKey) ?? 0
        guard timestamp > 0 else { return false }
        return Date().timeIntervalSince1970 - timestamp <= seconds
    }

    static func clearLockScreenToggle() {
        defaults?.removeObject(forKey: toggleTimestampKey)
    }
}

