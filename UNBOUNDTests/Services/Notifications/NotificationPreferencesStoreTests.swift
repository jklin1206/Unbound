import XCTest
@testable import UNBOUND

final class NotificationPreferencesStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "notification-preferences-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveRoundTripsJSONAcrossStoreInstances() {
        let key = "prefs"
        let store = NotificationPreferencesStore(defaults: defaults, key: key)
        let preferences = NotificationPreferences(
            workoutReminders: WorkoutReminderNotificationPreferences(
                isEnabled: true,
                workoutTime: .evening,
                trainingDays: [.monday, .thursday],
                minute: 15
            ),
            retentionNudges: RetentionNudgeNotificationPreferences(
                isEnabled: true,
                anchorDate: Date(timeIntervalSince1970: 1_800_000_000),
                daysAfterAnchor: 21,
                hour: 10,
                minute: 30
            ),
            milestones: MilestoneNotificationPreferences(isEnabled: false),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )

        store.save(preferences)

        let reloaded = NotificationPreferencesStore(defaults: defaults, key: key)
        XCTAssertEqual(reloaded.load(), preferences)
    }

    func testLoadFallsBackToDefaultsWhenJSONIsMissingOrInvalid() {
        let key = "prefs"
        let store = NotificationPreferencesStore(defaults: defaults, key: key)

        XCTAssertFalse(store.load().workoutReminders.isEnabled)
        XCTAssertTrue(store.load().retentionNudges.isEnabled)
        XCTAssertTrue(store.load().milestones.isEnabled)

        defaults.set(Data("not-json".utf8), forKey: key)

        let fallback = store.load()
        XCTAssertFalse(fallback.workoutReminders.isEnabled)
        XCTAssertTrue(fallback.retentionNudges.isEnabled)
        XCTAssertTrue(fallback.milestones.isEnabled)
    }

    func testUpdateMutatesAndPersistsPreferences() {
        let store = NotificationPreferencesStore(defaults: defaults, key: "prefs")

        let updated = store.update { preferences in
            preferences.workoutReminders.isEnabled = true
            preferences.workoutReminders.workoutTime = .morning
            preferences.workoutReminders.trainingDays = [.tuesday]
        }

        XCTAssertTrue(updated.workoutReminders.isEnabled)
        XCTAssertEqual(updated.workoutReminders.workoutTime, .morning)
        XCTAssertEqual(updated.workoutReminders.trainingDays, [.tuesday])
        XCTAssertEqual(store.load().workoutReminders.trainingDays, [.tuesday])
    }
}
