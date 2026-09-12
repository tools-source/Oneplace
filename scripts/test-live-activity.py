#!/usr/bin/env python3
"""Exercise the production controller with deterministic ActivityKit stand-ins.

Run: python3 scripts/test-live-activity.py
This checks app lifecycle decisions; actual iOS expiry still needs device testing.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
models = (root / 'OnePlace/Shared/OnePlaceActivityAttributes.swift').read_text().replace('import ActivityKit', '')
controller = (root / 'OnePlace/Services/LiveActivity/OnePlaceLiveActivityController.swift').read_text()
controller = controller.split('\nextension TaskItemRecord')[0].replace('import ActivityKit', '').replace('import UIKit', '')
mocks = r'''
import Foundation
protocol ActivityAttributes {}
struct ActivityContent<State> { let state: State; let staleDate: Date? }
enum ActivityState { case active, stale, ended, dismissed }
enum DismissalPolicy { case immediate }
@MainActor final class UserDefaults {
    static let standard = UserDefaults()
    var values: [String: Any] = [:]
    func string(forKey key: String) -> String? { values[key] as? String }
    func object(forKey key: String) -> Any? { values[key] }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func set(_ value: Any, forKey key: String) { values[key] = value }
}
@MainActor final class UIApplication {
    enum State { case active, background }
    static let shared = UIApplication()
    var applicationState = State.active
}
@MainActor struct ActivityAuthorizationInfo {
    static var enabled = true
    var areActivitiesEnabled: Bool { Self.enabled }
}
typealias Activity<Attributes> = TestActivity
@MainActor final class TestActivity {
    static var activities: [TestActivity] = []
    static var requestCount = 0
    static var failRequests = false
    var activityState: ActivityState
    var updates = 0
    var content: ActivityContent<OnePlaceActivityAttributes.ContentState>?
    init(_ state: ActivityState) { activityState = state }
    func update(_ content: ActivityContent<OnePlaceActivityAttributes.ContentState>) async {
        updates += 1
        self.content = content
    }
    func end(_ content: ActivityContent<OnePlaceActivityAttributes.ContentState>?, dismissalPolicy: DismissalPolicy) async {
        activityState = .dismissed
    }
    static func request(attributes: OnePlaceActivityAttributes, content: ActivityContent<OnePlaceActivityAttributes.ContentState>, pushType: String?) throws -> TestActivity {
        if failRequests { throw NSError(domain: "Test", code: 1) }
        requestCount += 1
        let activity = TestActivity(.active)
        activity.content = content
        activities.append(activity)
        return activity
    }
}
struct TaskItemRecord { let liveActivityTask: OnePlaceLiveTask }
@MainActor enum OnePlaceTaskCache {
    static var tasks: [OnePlaceLiveTask] = []
    static func save(_ value: [OnePlaceLiveTask]) { tasks = value }
    static func load() -> [OnePlaceLiveTask] { tasks }
    static func hasRecentLockScreenToggle() -> Bool { false }
}
'''
tests = r'''
@main struct ControllerTests {
    @MainActor static func main() async {
        let controller = OnePlaceLiveActivityController.shared
        let tasks = [TaskItemRecord(liveActivityTask: OnePlaceLiveTask(id: "1", title: "Plan today", isCompleted: false))]
        func reset(_ state: ActivityState? = nil) {
            TestActivity.activities = state.map { [TestActivity($0)] } ?? []
            TestActivity.requestCount = 0
            TestActivity.failRequests = false
            ActivityAuthorizationInfo.enabled = true
            UIApplication.shared.applicationState = .active
            controller.setUserEnabled(true)
        }
        for state in [ActivityState.active, .stale] {
            reset(state)
            let result = await controller.startOrUpdateAndWait(with: tasks)
            precondition(result && controller.isRunning)
            precondition(TestActivity.requestCount == 0 && TestActivity.activities[0].updates == 1)
        }
        for state in [ActivityState.ended, .dismissed] {
            reset(state)
            precondition(!controller.isRunning)
            let result = await controller.startOrUpdateAndWait(with: tasks)
            precondition(result && TestActivity.requestCount == 1)
            precondition(TestActivity.activities.last?.content?.state.totalOpenCount == 1)
        }
        reset(.ended)
        UIApplication.shared.applicationState = .background
        let backgroundResult = await controller.startOrUpdateAndWait(with: tasks)
        precondition(!backgroundResult && TestActivity.requestCount == 0)
        UIApplication.shared.applicationState = .active
        await controller.restoreFromCacheIfEnabled()
        precondition(TestActivity.requestCount == 1)

        reset()
        controller.setUserEnabled(false)
        await controller.restoreFromCacheIfEnabled()
        precondition(TestActivity.requestCount == 0 && !controller.isUserEnabled)

        reset()
        ActivityAuthorizationInfo.enabled = false
        let disabledResult = await controller.startOrUpdateAndWait(with: tasks)
        precondition(!disabledResult && TestActivity.requestCount == 0)

        reset()
        TestActivity.failRequests = true
        let failedResult = await controller.startOrUpdateAndWait(with: tasks)
        precondition(!failedResult && !controller.isRunning)

        reset()
        controller.startOrUpdate(with: tasks)
        await controller.turnOff()
        for _ in 0..<10 { await Task.yield() }
        precondition(!controller.isUserEnabled && !controller.isRunning, "Cancelled start must not re-enable the preference")
        print("PASS: active/stale updates, ended/dismissed recovery, foreground-only starts, cached recovery, disabled preference, authorization, request failure, cancelled start")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='oneplace-live-tests-') as directory:
    source = Path(directory) / 'ControllerTests.swift'
    binary = Path(directory) / 'ControllerTests'
    source.write_text(mocks + models + controller + tests)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    subprocess.run(['xcrun', 'swiftc', '-sdk', sdk, '-parse-as-library', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
