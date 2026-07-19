# Squads

Everything social: squad membership/state, the activity feed, presence, weekly missions, friend challenges, squad titles/honors, messaging, and the linked-session XP bonus loop. Squad data lives in Supabase tables (not the local file-backed `DatabaseService`); each concern has a `*Backend` Supabase wrapper, a `Mock*` for tests, and a `@MainActor` service on top.

## Files

| File | Purpose |
| --- | --- |
| `FriendChallengeProgressPolicy.swift` | Pure policy: how much a `WorkoutLog` advances each `FriendChallenge.Kind` (sessions, early-riser hour window, etc.). |
| `FriendChallengeService.swift` | `FriendChallengeServiceProtocol` + live service: create/accept challenges, record progress from logs, stats per squad/season, expiry evaluation that settles duels (pays the winner duelWinArcs, ledger-idempotent) and buffers outcomes for the toast. |
| `LinkedSessionEvaluator.swift` | Applies the +20% XP linked-session bonus (non-stacking with the +10% affinity bonus) when a partner's session overlaps the user's. |
| `LocalSquadDirectory.swift` | UserDefaults-backed local squad+members record (debug/local-only squad support). |
| `MockSquadActivityBackend.swift` | In-memory `SquadActivityBackendProtocol` for tests. |
| `MockSquadBackend.swift` | In-memory `SquadBackendProtocol` for tests. |
| `PendingSquadInvite.swift` | Persists a tapped `/squad/<code>` universal link (UserDefaults, global key, 7-day TTL) so it survives cold-launch through onboarding/auth; plus `SquadInviteLink`, the pure host/segment-tolerant URL parser. Consumed by `HomeTabView`. |
| `SquadActivityBackend.swift` | Production backend for the `squad_activity` Supabase table. |
| `SquadActivityBackendProtocol.swift` | Protocol isolating activity-feed persistence. |
| `SquadActivityService.swift` | Records squad activity events (trial completions, title unlocks, linked sessions, joins...); installs NotificationCenter observers on init. |
| `SquadActivityServiceProtocol.swift` | `@MainActor` protocol for the activity service. |
| `SquadBackend.swift` | Production Supabase wrapper for all squad-table operations (`UnboundSupabase.client`). |
| `SquadBackendProtocol.swift` | Protocol for squad-table operations; also defines `LinkedSession`. |
| `SquadFlairService.swift` | Publishes the user's `SquadMemberFlair` to `squad_member_flair` and reads squadmates' flair via the gated `squad_member_flair_for_squad` RPC. |
| `SquadHonorsService.swift` | Weekly honors: `currentHonors(squadId:)` / `recordHonor(_:)` over the squad backend. |
| `SquadLoopReconciler.swift` | Closes the loops with no production trigger: consumes `linked_sessions` rows (once each, persisted dedup) to drive the +20% bonus and advance squadStreak/linkedSessions title counters. |
| `SquadLoopStore.swift` | UserDefaults persistence for the reconciler's dedup set + counter state (one entry-group per userId). |
| `SquadMessageBackend.swift` | Supabase backend for squad messages, reactions, and routine drops (+ storage coder / row types). |
| `SquadMessageService.swift` | `SquadMessageService` and `SquadRoutineDropService` actors: fetch/send squad chat with a local in-memory layer. |
| `SquadMissionCatalog.swift` | Deterministic catalog of weekly mission templates; `generate(for:weekIso:)` seeds by squad id + week. |
| `SquadMissionService.swift` | Weekly co-op mission lifecycle: generate this week's mission, record progress from logs, evaluate completion. |
| `SquadPresenceService.swift` | Live "in workout" presence: mark/refresh/read member presence rows. |
| `SquadPresenceServiceProtocol.swift` | `@MainActor` protocol for presence. |
| `SquadService.swift` | The core `@MainActor` service owning all squad mutation logic (create/join/leave, state hydration) over store + backend + auth. |
| `SquadServiceProtocol.swift` | Protocol + `SquadError`. |
| `SquadStore.swift` | UserDefaults-backed `SquadState` persistence, one entry per userId (mirrors TrialsStore pattern). |
| `SquadTitleCatalog.swift` | SquadTitleID → display name: 4 categories × per-axis × 3 tiers. |
| `SquadTitleService.swift` | Wires the threshold evaluator into persisted state; appends new `unlockedSquadTitles` and posts `.squadTitleUnlocked` (distinct from individual `.titleUnlocked`). |
| `SquadTitleThresholdEvaluator.swift` | Pure helper: prior + current counter snapshots → newly crossed `SquadTitleID`s. |
| `SquadUserIdentity.swift` | userId string → UUID mapping (deterministic debug UUIDs, local-only squad gating in DEBUG). |

## Where to find X

- **Join/create/leave a squad, squad state** → `SquadService.swift` (+ `SquadStore.swift` cache, `SquadBackend.swift` Supabase).
- **Invite deep link (`/squad/<code>`) parsing + survival across cold-launch** → `PendingSquadInvite.swift` (`SquadInviteLink` parser + `PendingSquadInvite` store); parsed/persisted in `UnboundApp.onContinueUserActivity`, consumed by `HomeTabView`.
- **Activity feed entries** → `SquadActivityService.swift` / `SquadActivityBackend.swift`.
- **Linked-session +20% XP bonus** → `LinkedSessionEvaluator.swift` (the bonus math) and `SquadLoopReconciler.swift` (the production trigger + dedup).
- **Weekly missions** → `SquadMissionService.swift` + `SquadMissionCatalog.swift`.
- **1v1 friend challenges** → `FriendChallengeService.swift` + `FriendChallengeProgressPolicy.swift`.
- **Squad titles/badges** → `SquadTitleThresholdEvaluator.swift` → `SquadTitleService.swift` → names in `SquadTitleCatalog.swift`.
- **Squad chat / routine drops** → `SquadMessageService.swift` + `SquadMessageBackend.swift`.
