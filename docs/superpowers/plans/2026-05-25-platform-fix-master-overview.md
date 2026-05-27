# Platform Fix Master Overview

> **Goal:** Land all six 2026-05-25 platform plans as one coordinated push: subscription gating, Supabase migration completion, PostHog analytics, onboarding-driven notifications, CardioLog integration, and the test coverage sweep.

## Canonical Plans

| Order | Plan | Purpose | Dependency Notes |
|---:|---|---|---|
| 1 | [`2026-05-25-supabase-migration-completion.md`](2026-05-25-supabase-migration-completion.md) | Preserve pre-Supabase user logs, weights, and skill progress after sign-in. | Foundation for auth-backed user state. Run before heavy retention or analytics work. |
| 2 | [`2026-05-25-hard-paywall-subscription.md`](2026-05-25-hard-paywall-subscription.md) | Make subscription required after onboarding. | Foundation for subscription-state analytics and hard-launch behavior. |
| 3 | [`2026-05-25-analytics-posthog.md`](2026-05-25-analytics-posthog.md) | Replace OSLog-only analytics with PostHog plus 20 critical events. | Depends on auth identity and benefits from `isSubscribed` from the paywall plan. |
| 4 | [`2026-05-25-onboarding-driven-notifications.md`](2026-05-25-onboarding-driven-notifications.md) | Add train-time, retention, milestone, and squad activity notifications. | Depends on onboarding flow shape; APNs squad pushes depend on Squads v1 P2 pipeline. |
| 5 | [`2026-05-25-cardiolog-integration.md`](2026-05-25-cardiolog-integration.md) | Make logged cardio affect weekly volume, plateau detection, recovery, and squad chat. | Run after Program Canvas Agent D and Squads v1 Phase 2 are landed. |
| Parallel | [`2026-05-25-test-coverage-sweep.md`](2026-05-25-test-coverage-sweep.md) | Backfill high-value tests across Squads, Coach, Ranking, and Trials. | Can run in parallel, but each tree should wait until the services it tests exist. |

## Suggested Run Order

1. **Data safety first:** complete Supabase migration tables and one-shot local migrators.
2. **Monetization gate:** wire `SubscriptionGate`, `LockedView`, restore purchases, and Settings subscription state.
3. **Instrumentation:** add PostHog, identify/reset on auth, register subscription super-properties, and wire the 20 events.
4. **Lifecycle nudges:** add onboarding train-time capture, notification preferences, local schedulers, and squad push receiver/server pieces.
5. **Cardio read paths:** integrate CardioLog into weekly volume, plateau/recovery, and squad auto-posting after Program D and Squads P2 are present.
6. **Coverage sweep:** run continuously in parallel by service tree, then finish with coverage reporting once the moving parts stabilize.

## Parallelization

- **Worker A:** Supabase migration completion.
- **Worker B:** Hard paywall subscription.
- **Worker C:** Test coverage sweep for any already-existing service trees.
- **Worker D after A+B:** PostHog analytics, especially auth/subscription events.
- **Worker E after onboarding shape is stable:** Onboarding-driven notifications.
- **Worker F after Program D + Squads P2:** CardioLog integration.

## Cross-Dependencies To Watch

- `AuthService.swift` is touched by Supabase migration, PostHog identify/reset, APNs token registration, and possibly subscription handoff. Coordinate edits carefully.
- `SettingsView.swift` is touched by subscription management, analytics opt-out, and notification settings entry.
- `SubscriptionService.swift` is touched by paywall gating and analytics super-properties.
- Onboarding completion is shared by the hard paywall and notification time/permission steps.
- `SquadMessageAutoPoster.swift` is shared by Squads v1, notifications, analytics events, and CardioLog auto-posting.
- `CheckpointValidator.swift` is only safe for CardioLog integration after Program Canvas Agent D has landed.

## Definition Of Done

- All six plan files have their task checkboxes completed or explicitly marked deferred with a reason.
- The app launches from a clean install, completes onboarding, presents the paywall, unlocks on subscription, and keeps migrated user data intact.
- PostHog receives the 20 critical events with Supabase user IDs and subscription state attached.
- Notification preferences round-trip, local reminders schedule correctly, and squad push plumbing has a verified test path.
- Cardio sessions affect weekly volume, plateau/recovery logic, and squad chat.
- The targeted XCTest slices pass, and CI reports coverage for Squads, Coach, Ranking, and Trials.
