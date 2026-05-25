# Analytics — PostHog Integration + 20 Critical Events

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** Replace the OSLog-only `AnalyticsService` with a PostHog-backed implementation that ships events to a real backend. Wire 20 high-leverage events covering onboarding funnel, subscription, retention, and core feature usage so product decisions stop being guesswork.

**Architecture:** Drop in `PostHog` Swift SDK, route the existing `AnalyticsService` protocol through it (the protocol stays the same — only the implementation swaps). Existing call sites that already fire events keep working. Add 20 new event call sites in the highest-leverage spots. PostHog identifies users by Supabase auth UUID so events join cleanly to backend data later.

**Tech stack:** Swift, PostHog Swift SDK, existing `AnalyticsEvent.swift` taxonomy.

---

## Scope

In:
- PostHog SDK integration via SPM
- Replace `AnalyticsService` OSLog backend with PostHog backend
- Identify on auth, reset on sign-out
- 20 new event call sites (full list in Task 4)
- Super-properties: app version, build, OS version, subscription state, squad membership
- Debug toggle (`AnalyticsService.shared.enableDebugLogging`) for sim builds
- Privacy: opt-out toggle in Settings (App Store privacy requirement)

Out:
- Custom dashboards (do those in PostHog UI after data lands)
- Session replay (PostHog has it; skip for v1)
- Feature flags via PostHog (defer)
- A/B test framework (defer)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `Package.swift` or Xcode SPM panel | **Modify** | Add `https://github.com/PostHog/posthog-ios` |
| `UNBOUND/Services/Analytics/PostHogAnalyticsBackend.swift` | **Create** | Wraps the PostHog SDK; implements the existing AnalyticsBackend protocol pattern |
| `UNBOUND/Services/Analytics/AnalyticsService.swift` | **Modify** | Replace OSLog backend with PostHog backend in production path; keep OSLog as fallback for DEBUG-only mirror |
| `UNBOUND/Services/Analytics/AnalyticsEvent.swift` | **Modify** | Add the 20 new event cases (Task 4 lists them) |
| `UNBOUND/Services/Auth/AuthService.swift` | **Modify** | On sign-in → `analytics.identify(userId, traits)`. On sign-out → `analytics.reset()` |
| `UNBOUND/Services/Subscription/SubscriptionService.swift` | **Modify** | Update PostHog super-property `isSubscribed` whenever entitlement changes |
| `UNBOUND/Views/Settings/SettingsView.swift` | **Modify** | Add "Share usage data" toggle (default ON; off → `posthog.optOut()`) |
| `UNBOUND/App/AniBodyApp.swift` | **Modify** | Init PostHog at app launch with project key from `Secrets.plist` (or env-injected at build time) |
| `Secrets.plist` (gitignored) | **Modify** | Add `POSTHOG_API_KEY` and `POSTHOG_HOST` (default `https://us.i.posthog.com`) |
| `UNBOUND/UNBOUNDTests/Services/AnalyticsServiceTests.swift` | **Create** | Identify/reset/track go through to mock backend |

---

## Tasks

### Task 1 — Add PostHog SDK

**File:** Xcode → File → Add Package Dependencies → `https://github.com/PostHog/posthog-ios` (latest 3.x).

**Acceptance:** `import PostHog` compiles.

**Commit:** `chore(deps): add PostHog Swift SDK`

### Task 2 — `PostHogAnalyticsBackend`

**File:** Create `UNBOUND/Services/Analytics/PostHogAnalyticsBackend.swift`.

```swift
import PostHog

final class PostHogAnalyticsBackend: AnalyticsBackendProtocol {
    init(apiKey: String, host: String) {
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.captureApplicationLifecycleEvents = true
        config.flushAt = 20            // batch
        config.flushIntervalSeconds = 30
        PostHogSDK.shared.setup(config)
    }

    func track(_ name: String, properties: [String: Any]?) {
        PostHogSDK.shared.capture(name, properties: properties)
    }

    func identify(_ userId: String, traits: [String: Any]?) {
        PostHogSDK.shared.identify(userId, userProperties: traits)
    }

    func registerSuper(_ properties: [String: Any]) {
        PostHogSDK.shared.register(properties)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }

    func optOut() { PostHogSDK.shared.optOut() }
    func optIn() { PostHogSDK.shared.optIn() }
}
```

If `AnalyticsBackendProtocol` doesn't exist, extract one from the current OSLog implementation first (it does the same operations).

**Acceptance:** Wired into `ServiceContainer` production path; mock path keeps an in-memory backend for tests.

**Commit:** `feat(analytics): PostHog backend implementation`

### Task 3 — Identify on auth + super-properties

**Files:** Modify `AuthService.swift`, `SubscriptionService.swift`, app root.

On `AuthService.signInSucceeded`:
```swift
services.analytics.identify(userId: user.id.uuidString, traits: [
    "email": user.email ?? "",
    "createdAt": user.createdAt.iso8601String,
])
```

On sign-out: `services.analytics.reset()`.

On `SubscriptionService.isSubscribed` change:
```swift
services.analytics.registerSuper(["isSubscribed": newValue])
```

At app launch, register baseline super-properties:
```swift
services.analytics.registerSuper([
    "appVersion": Bundle.main.shortVersion,
    "build": Bundle.main.build,
    "osVersion": UIDevice.current.systemVersion,
])
```

**Acceptance:** Sign in / sign out / subscribe in sim → events in PostHog show the right user + properties.

**Commit:** `feat(analytics): identify, reset, super-properties`

### Task 4 — Wire the 20 critical events

**Files:** Various call sites — locate via grep.

| # | Event | Where to fire |
|---|---|---|
| 1 | `onboarding_started` | First onboarding view's `.onAppear` |
| 2 | `onboarding_step_completed` | Each step "Continue" tap (`step` property = step name) |
| 3 | `onboarding_completed` | Final onboarding step's success path |
| 4 | `paywall_viewed` | `LockedView.onAppear` |
| 5 | `paywall_dismissed` | LockedView × dismiss (note: with hard paywall, only via sign-out) |
| 6 | `subscription_started` | `SubscriptionService.isSubscribed` flips false → true |
| 7 | `subscription_canceled` | Detected via `customerInfo.entitlements.active.isEmpty` after being subscribed |
| 8 | `workout_started` | `RoutinePlayerView.onAppear` or `WorkoutSession.start` |
| 9 | `workout_completed` | Existing workout completion call site |
| 10 | `workout_abandoned` | Workout session ended without completion |
| 11 | `pr_awarded` | Wherever PRs are detected/written |
| 12 | `skill_tier_crossed` | `SkillProgressService` tier crossing |
| 13 | `vow_sealed` | Binding Vow seal completion |
| 14 | `program_generated` | After `ArcGenerator` runs |
| 15 | `squad_created` | `SquadService.createSquad` success |
| 16 | `squad_joined` | `SquadService.joinSquad` success |
| 17 | `challenge_created` | Both Open + Co-op create paths |
| 18 | `challenge_cleared` | Both Open win + Co-op clear |
| 19 | `app_opened` | App did become active (debounce 5 min so quick switches aren't counted) |
| 20 | `tab_selected` | Tab bar selection (`tab` property = tab name) |

For each, add a one-liner:
```swift
services.analytics.track("workout_completed", properties: [
    "workoutId": workout.id.uuidString,
    "durationMin": workout.durationMinutes,
    "rpe": workout.rpe ?? -1,
])
```

Use `AnalyticsEvent` enum for type safety if it's already structured that way; otherwise add string-keyed calls.

**Acceptance:** Trigger each in sim → event lands in PostHog within 30s (flush interval).

**Commit:** `feat(analytics): wire 20 critical events`

### Task 5 — Settings opt-out toggle

**File:** Modify `SettingsView.swift`.

```
PRIVACY
  Share usage data    [toggle]   default: on
```

On toggle change → `analytics.optOut()` or `analytics.optIn()`. Persist to `UserDefaults` so the choice survives launches; apply on startup.

**Acceptance:** Toggle off → PostHog SDK stops sending; toggle on → resumes.

**Commit:** `feat(analytics): privacy opt-out toggle`

### Task 6 — `AnalyticsServiceTests`

**File:** Create `UNBOUND/UNBOUNDTests/Services/AnalyticsServiceTests.swift`.

Tests:
- `track` calls backend.track with correct name + properties
- `identify` calls backend.identify
- `reset` clears the identifier
- `optOut` halts subsequent `track` calls (assert via mock backend)
- Super-properties merge into event properties

**Acceptance:** All green.

**Commit:** `test(analytics): protocol + opt-out behavior`

---

## App Store privacy requirements

- Update Info.plist `NSUserTrackingUsageDescription` if you ever want to enable cross-app tracking (NOT needed for first-party PostHog).
- Update App Store Connect → App Privacy section: declare PostHog data collection (Identifiers — User ID, Usage Data — Product Interaction, Crash Data).
- Privacy Policy must mention PostHog.

---

## Verification (end of plan)

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/AnalyticsServiceTests
```

Manual sanity:
1. Fresh launch → see `app_opened` in PostHog Live Events within 30s.
2. Complete a workout → `workout_completed` lands with correct properties.
3. Toggle off privacy → no further events fire.
4. Sign out + sign in as different user → identify shows new userId.
