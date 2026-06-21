# Services/Notifications

Schedules, fires, and manages all local push notifications for UNBOUND: workout reminders, milestone celebrations (rank-up, badge, skill tier, title), and retention nudges. `NotificationCoordinator` is the single entry point; `NotificationService` is a thin compatibility facade over it for older call sites.

| File | Purpose |
|------|---------|
| `NotificationCoordinator.swift` | Singleton orchestrator that owns scheduling and cancellation of all notification types; holds `TrainTimeNotificationScheduler` and `MilestoneNotificationNotifier` and exposes the public API consumed by settings screens |
| `NotificationService.swift` | Static compatibility facade that forwards calls to `NotificationCoordinator.shared`; exists so older call sites do not need migration |
| `NotificationPreferencesStore.swift` | Persists `NotificationPreferences` to `UserDefaults`; provides load/save/update/reset operations with ISO-8601 JSON encoding |
| `NotificationScheduleDescriptor.swift` | Value types `LocalNotificationRequestDescriptor` and `NotificationSchedulePlan`; bridges the app's schedule model to `UNNotificationRequest` via `makeRequest()` |
| `NotificationSchedulers.swift` | `TrainTimeNotificationScheduler` builds per-weekday recurring workout-reminder requests; `RetentionNudgeScheduler` builds a one-shot rescan reminder on an anchor-date offset |
| `MilestoneNotificationNotifier.swift` | Observes `NotificationCenter` for in-app milestone events (badge, rank, skill tier, progression, title, attribute rank-up) and fires a local notification via `MilestoneNotificationPlanner` |
| `ContentNotificationCatalog.swift` | Curated static library of lock-screen notification copy used for marketing screenshots; organized by category (streak, rankUp, hexShift, identity, callBack, session) |

## Where to find X

| Task | File |
|------|------|
| Schedule or cancel workout reminders | `NotificationCoordinator.swift` |
| Add a new milestone notification trigger | `MilestoneNotificationNotifier.swift` |
| Change notification copy for a milestone event | `MilestoneNotificationNotifier.swift` (inside `MilestoneNotificationPlanner`) |
| Load/save user notification preferences | `NotificationPreferencesStore.swift` |
| Add lock-screen marketing notification presets | `ContentNotificationCatalog.swift` |
