# Onboarding-Driven Notifications

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** Turn `NotificationService` from a 126-line workout-reminder shell into a real notification engine that fires: (1) daily train-time reminders (anchored to a time the user picks in onboarding), (2) retention nudges when the user lapses, (3) milestone celebrations (PRs, vow seals, badge tiers), and (4) squad activity pushes. All four categories toggleable per-user in Settings.

**Architecture:** Onboarding captures `preferredTrainingTime` (a `Date` representing time-of-day) into `UserDefaults`. `NotificationService` exposes four scheduler families (`TrainTimeScheduler`, `RetentionNudgeScheduler`, `MilestoneNotifier`, `SquadNotifier`), each respecting a per-user toggle in `NotificationPreferences`. Local notifications for train-time + retention; APNs for milestone + squad (latter routed through the existing Supabase push pipeline used in Squads v1 P2).

**Tech stack:** Swift, UserNotifications, Supabase Edge Functions (for server-driven pushes), APNs.

---

## Scope

In:
- New onboarding step: "When do you usually train?" (time picker, defaults to 7am)
- `NotificationPreferences` model + storage
- 4 scheduler families
- Settings → Notifications screen with 4 toggles + master toggle
- Onboarding permission request (right after the time-picker step)
- Re-schedule on app open if preferences changed

Out:
- Rich notifications (images, action buttons)
- Quiet hours per-user
- Smart-time learning (defer; we use the user-stated time)
- Cross-device dedup (defer; APNs handles roughly)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/NotificationPreferences.swift` | **Create** | `trainTime`, `trainTimeReminderOn`, `retentionNudgeOn`, `milestoneOn`, `squadActivityOn`, `masterOn` |
| `UNBOUND/Services/Notifications/NotificationPreferencesStore.swift` | **Create** | UserDefaults-backed |
| `UNBOUND/Services/Notifications/TrainTimeScheduler.swift` | **Create** | Schedules a daily UNCalendarNotificationTrigger 30 min before train time |
| `UNBOUND/Services/Notifications/RetentionNudgeScheduler.swift` | **Create** | Schedules day-2 / day-5 / day-10 lapse pushes; cancels on workout |
| `UNBOUND/Services/Notifications/MilestoneNotifier.swift` | **Create** | Observes `.prAwarded` / `.vowSealed` / `.accountabilityTierEarned` / `.crewStreakTierEarned` → posts local notification |
| `UNBOUND/Services/Notifications/SquadActivityNotifier.swift` | **Create** | Receives APNs payloads from Supabase Edge Function (Squads v1 P2 already plans this — this is the client receiver) |
| `UNBOUND/Services/NotificationService.swift` | **Modify** | Becomes a coordinator that owns the 4 scheduler instances |
| `UNBOUND/Views/Onboarding/OnboardingTrainTimeStep.swift` | **Create** | New onboarding step with DatePicker (.hourAndMinute) |
| `UNBOUND/Views/Onboarding/OnboardingNotificationsStep.swift` | **Create** | Asks for notification permission with rationale copy |
| `UNBOUND/Views/Settings/NotificationsSettingsView.swift` | **Create** | 5 toggles + train-time picker |
| `UNBOUND/Views/Settings/SettingsView.swift` | **Modify** | Add NavigationLink to NotificationsSettingsView |
| `supabase/functions/push-squad-activity/index.ts` | **Create** | Server-side push for squad events (replies, challenge invites, crew streak risk) |
| `db/migrations/20260525_user_push_tokens.sql` | **Create** | Table to store user APNs tokens for server-driven pushes |
| `UNBOUND/UNBOUNDTests/Services/TrainTimeSchedulerTests.swift` | **Create** | — |
| `UNBOUND/UNBOUNDTests/Services/RetentionNudgeSchedulerTests.swift` | **Create** | — |
| `UNBOUND/UNBOUNDTests/Services/NotificationPreferencesStoreTests.swift` | **Create** | — |

---

## Tasks

### Task 1 — `NotificationPreferences` + store

```swift
struct NotificationPreferences: Codable, Equatable {
    var trainTime: DateComponents       // hour + minute only
    var trainTimeReminderOn: Bool
    var retentionNudgeOn: Bool
    var milestoneOn: Bool
    var squadActivityOn: Bool
    var masterOn: Bool                  // hard kill-switch for all

    static let `default` = NotificationPreferences(
        trainTime: DateComponents(hour: 7, minute: 0),
        trainTimeReminderOn: true,
        retentionNudgeOn: true,
        milestoneOn: true,
        squadActivityOn: true,
        masterOn: true
    )
}
```

Store: UserDefaults JSON round-trip.

**Acceptance:** Round-trip test. Defaults applied on first load.

**Commit:** `feat(notifications): preferences model + store`

### Task 2 — `TrainTimeScheduler`

**File:** Create `TrainTimeScheduler.swift`.

```swift
@MainActor
final class TrainTimeScheduler {
    private let prefs: NotificationPreferencesStore
    private let center = UNUserNotificationCenter.current()

    func reschedule() async {
        await center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        guard prefs.value.masterOn, prefs.value.trainTimeReminderOn else { return }

        var fireComponents = prefs.value.trainTime
        // Fire 30 min before train time
        let fireTime = Calendar.current.date(from: fireComponents)!.addingTimeInterval(-30 * 60)
        fireComponents = Calendar.current.dateComponents([.hour, .minute], from: fireTime)

        let content = UNMutableNotificationContent()
        content.title = "Time to train"
        content.body = pickCopy()        // rotate from a small array
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
    }

    static let identifier = "unbound.notif.trainTime.daily"
}
```

Rotate copy from a tiny library so users don't see the same string daily.

**Acceptance:** `TrainTimeSchedulerTests` — after `reschedule`, `pendingNotificationRequests` includes one with the expected daily-repeat trigger at `(trainTime - 30 min)`.

**Commit:** `feat(notifications): TrainTimeScheduler`

### Task 3 — `RetentionNudgeScheduler`

**File:** Create `RetentionNudgeScheduler.swift`.

Track `lastWorkoutDate` (UserDefaults). On app launch + on workout completion → compute days-since-last-workout.

Schedule notifications:
- Day 2 (48h since last workout): "Your crew misses you." Or "Coming back today?"
- Day 5: "It's been 5 days — even a 10-min session counts."
- Day 10: "Pause your program? Or just check in?"

Identifiers: `unbound.notif.retention.d2|d5|d10`. On every workout, remove all three pending.

**Acceptance:** `RetentionNudgeSchedulerTests` — workout today → reschedule wipes pending. Last workout 3 days ago → only d5 + d10 remain pending; d2 was already past.

**Commit:** `feat(notifications): RetentionNudgeScheduler`

### Task 4 — `MilestoneNotifier`

**File:** Create `MilestoneNotifier.swift`.

Observe these `Notification.Name`s:
- `.prAwarded` → "🔥 PR: \(exerciseName) +\(summary)"
- `.vowSealed` → "✨ Sealed: \(vowName)"
- `.accountabilityTierEarned` → "🏷️ Accountability \(tier) unlocked"
- `.crewStreakTierEarned` → "🔥 Crew Streak \(tier) — \(weeks) weeks together"

For each, fire a local notification immediately (`UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)`). Respects `prefs.value.milestoneOn`.

**Acceptance:** Post each notification name in a test → local notification queued.

**Commit:** `feat(notifications): MilestoneNotifier`

### Task 5 — Squad activity pushes (client receiver + server)

**Files:** Create `SquadActivityNotifier.swift`, `supabase/functions/push-squad-activity/index.ts`, `db/migrations/20260525_user_push_tokens.sql`.

```sql
create table if not exists public.user_push_token (
  user_id uuid primary key references auth.users(id) on delete cascade,
  apns_token text not null,
  updated_at timestamptz not null default now()
);
```

Client: register APNs token on auth → upsert into `user_push_token`.

Server function `push-squad-activity` is triggered by Postgres triggers on `squad_message` inserts (for replies) and `coop_pair_challenge` inserts (for invites). Sends APNs payload `{kind: "squad_reply" | "challenge_invite" | "crew_streak_risk", payload: {...}}`.

`SquadActivityNotifier` parses APNs payload kind → constructs local notification (or routes the in-app deep link if app is foreground). Respects `prefs.value.squadActivityOn`.

**Acceptance:** Send a test push from Supabase function → device receives → notification matches expected copy.

**Commit:** `feat(notifications): squad activity push pipeline`

### Task 6 — Onboarding steps

**Files:** Create `OnboardingTrainTimeStep.swift`, `OnboardingNotificationsStep.swift`.

Train-time step:
- DatePicker with `.compactHourAndMinute` style, default 7:00am
- Headline: "When do you usually train?"
- Sub: "We'll send a reminder 30 min before."
- Continue button → saves to `NotificationPreferencesStore`

Permissions step (runs immediately after train-time):
- Headline: "Want a nudge?"
- Sub: "We'll only ping you for things you ask us to. Toggleable later."
- "Enable notifications" button → `UNUserNotificationCenter.requestAuthorization(options: [.alert, .badge, .sound])`
- "Not now" button → continues without permission; settings can re-request

**Acceptance:** Both steps render and persist their inputs.

**Commit:** `feat(onboarding): train-time + notifications permission steps`

### Task 7 — `NotificationsSettingsView`

**File:** Create `UNBOUND/Views/Settings/NotificationsSettingsView.swift`.

```
NOTIFICATIONS
  Notifications on             [toggle — master]

  WHEN MASTER IS ON
  Daily train-time reminder    [toggle]
  Train at:                    [time picker]
  Retention nudges             [toggle]
  Milestones (PRs, badges)     [toggle]
  Squad activity               [toggle]

  System notification settings →   (deeplinks to iOS Settings)
```

Toggle changes → save to store → call `notificationService.rescheduleAll()`.

**Acceptance:** Changing time → reminder reschedules. Master off → all notifications cancel.

**Commit:** `feat(settings): NotificationsSettingsView`

### Task 8 — `NotificationService` coordinator

**File:** Modify `UNBOUND/Services/NotificationService.swift`.

```swift
@MainActor
final class NotificationService {
    let trainTime: TrainTimeScheduler
    let retention: RetentionNudgeScheduler
    let milestone: MilestoneNotifier
    let squadActivity: SquadActivityNotifier

    init(prefs: NotificationPreferencesStore) {
        trainTime = TrainTimeScheduler(prefs: prefs)
        retention = RetentionNudgeScheduler(prefs: prefs)
        milestone = MilestoneNotifier(prefs: prefs)
        squadActivity = SquadActivityNotifier(prefs: prefs)
    }

    func start() {
        Task { await trainTime.reschedule(); await retention.reschedule() }
        milestone.start()
        squadActivity.start()
    }

    func rescheduleAll() async {
        await trainTime.reschedule()
        await retention.reschedule()
    }
}
```

Remove the legacy workout-reminder logic from the old service (it's superseded by `TrainTimeScheduler`).

**Acceptance:** App launches without crash; pending notifications reflect current prefs.

**Commit:** `feat(notifications): NotificationService coordinator`

---

## Verification

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/NotificationPreferencesStoreTests \
  -only-testing:UNBOUNDTests/Services/TrainTimeSchedulerTests \
  -only-testing:UNBOUNDTests/Services/RetentionNudgeSchedulerTests
```

Manual sanity:
1. Fresh install → onboarding → train-time picker visible → pick 8am → permissions step accepts → app launches with pending 7:30am notification.
2. Toggle off "Daily train-time" in Settings → pending notification cancels.
3. Wait 48h without training → day-2 nudge fires.
4. Subscribe to test squad → another user replies → push received.
