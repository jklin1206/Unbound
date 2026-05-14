# Squads — Small Invite-Only Crews with Linked Workouts Design

**Status:** Brainstormed 2026-05-13. Awaiting user review before plan-writing.

**Goal:** Ship a small-group social layer where 3–8 real friends form a "crew," see each other's progression, train in linked workouts (overlapping time blocks with shared XP bonus), and develop emergent collective identity through a monthly affinity + squad-level Titles. Cooperative, intimate, never social-media-shaped.

**Sub-project:** #6 of the UNBOUND product redesign.

**Approach:** Full backend scope from the start (Approach A). Real Supabase tables for squads/members/presence/activity, real-time presence channel, push-notification integration for linked sessions, full UI (squad tab + roster + affinity picker + member detail + activity feed). Client-side `SquadService` + `SquadPresenceService` + `SquadActivityService` + `SquadStore`. Server-side Edge Functions for linked-session detection + nightly squad-streak evaluation + push fan-out.

**Spec dependencies:** Builds on BuildIdentity (sub-project #1), attribute system, Titles (sub-project #5), SessionXPService (sub-project #4), Supabase auth + database (existing). The first sub-project to require Supabase Realtime + Edge Functions; the schema lays the foundation.

---

## Product directive (governing principles)

These come from the user 2026-05-13 and govern every implementation decision below:

1. **Small invite-only crews (3–8 people).** Real friends. Not MMO guilds, not public feeds, not influencer optimization. "My crew" energy.
2. **The individual still owns their arc.** Core fantasy is "my evolution" (singular). Squad must AMPLIFY individual progression, never compete with it. No mandatory shared trials, no forced grind.
3. **Linked workouts are the killer mechanic.** Members training in overlapping time blocks become "linked" — shared XP bonus, subtle in-app toast, push notification. The emotional feeling is "we're training together," not "we're posting content."
4. **Cooperative atmosphere, not social media.** Shared affinity, squad titles, squad streaks, squad capstone celebrations, linked sessions, crew identity. NEVER infinite feeds, likes, comments, algorithmic discovery, public leaderboards.
5. **Privacy by default.** Squads are invite-only via deep-link share. No public discovery. No contact-graph scraping. RLS policies on every Supabase table — members see members; non-members see nothing.
6. **Quiet broadcast.** Trial completions, title unlocks, and member joins appear quietly on the squad activity feed — no push notifications. The only Squad-related push is the linked-session detection.

Memory anchors: [[project_unbound_squads_linked_workouts]], [[project_unbound_create_your_own_arc]], [[project_unbound_trials_emphasis_not_workload]], [[feedback_unbound_buildidentity_vs_titles]].

---

## Architecture

### Backend schema (Supabase)

Five tables. All scoped to authenticated user via Row Level Security (RLS).

```sql
-- squads: one row per crew
create table squads (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  captain_id      uuid not null references auth.users(id),
  affinity_axis   text,                          -- nullable: AttributeKey rawValue or null
  affinity_set_at timestamp with time zone,
  invite_code     text not null unique,          -- 6-char A-Z0-9
  max_size        int not null default 8,
  squad_streak_weeks int not null default 0,     -- updated by nightly evaluator
  created_at      timestamp with time zone default now()
);

-- squad_members: many-to-one to squads
create table squad_members (
  id           uuid primary key default gen_random_uuid(),
  squad_id     uuid not null references squads(id) on delete cascade,
  user_id      uuid not null references auth.users(id),
  joined_at    timestamp with time zone default now(),
  unique(squad_id, user_id)
);

-- squad_presence: ephemeral 'in workout' state, written by client
create table squad_presence (
  user_id            uuid primary key references auth.users(id),
  squad_id           uuid not null references squads(id) on delete cascade,
  workout_started_at timestamp with time zone not null,
  expires_at         timestamp with time zone not null  -- presence auto-expires 3h after start
);

-- squad_activity: feed entries
create table squad_activity (
  id           uuid primary key default gen_random_uuid(),
  squad_id     uuid not null references squads(id) on delete cascade,
  user_id      uuid not null references auth.users(id),
  kind         text not null,                  -- enum strings: see SquadActivityEntry.Kind
  payload      jsonb not null,
  created_at   timestamp with time zone default now()
);

-- linked_sessions: pairs (or groups) of overlapping workouts
create table linked_sessions (
  id           uuid primary key default gen_random_uuid(),
  squad_id     uuid not null references squads(id) on delete cascade,
  user_ids     uuid[] not null,                -- 2+ user ids whose sessions linked
  started_at   timestamp with time zone not null,
  ended_at     timestamp with time zone not null,
  created_at   timestamp with time zone default now()
);
```

**RLS policies:**
- `squads` — readable by members of that squad; insertable by any authenticated user (creator becomes captain via trigger); updatable only by captain.
- `squad_members` — readable by members of that squad; insertable when a valid invite code is consumed (Edge Function validates code before insert).
- `squad_presence` — readable by members of the same squad; writable only by the row's user_id.
- `squad_activity` — readable by members of that squad; insertable when `user_id` matches `auth.uid()` and user is a member of `squad_id`.
- `linked_sessions` — readable by squad members; insertable only by service-role (the Edge Function).

**Real-time channel:** Supabase Realtime subscription on `squad_presence` filtered by `squad_id` drives the live "in workout" UI.

**Edge Functions (server-side):**
- `join_squad` — validates invite code, checks squad isn't full, inserts `squad_members` row, posts `memberJoined` activity, returns squad row to caller.
- `detect_linked_sessions` — triggered on every `workout_logs` insert (via Supabase webhook). Scans for overlapping sessions across the squad with 5-minute slack window. On detection: inserts `linked_sessions` row, posts `linkedSession` activity, sends APNs push to participants.
- `evaluate_squad_streak` — nightly cron at 03:00 UTC. For each squad, checks if every member logged ≥1 session in the prior ISO week. Updates `squad_streak_weeks` and posts `squadStreakExtended` activity on increment.
- `transfer_captain` — invoked when captain leaves. Picks the longest-tenured remaining member as new captain. If no remaining members, deletes the squad row (cascade clears the rest).

### Client-side types

```swift
struct Squad: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let captainId: UUID
    let affinityAxis: AttributeKey?
    let affinitySetAt: Date?
    let inviteCode: String
    let maxSize: Int
    let squadStreakWeeks: Int
    let createdAt: Date
}

struct SquadMember: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let userId: UUID
    let joinedAt: Date
    // Joined fields, populated on roster fetch
    var displayName: String
    var equippedTitle: TitleID?
    var buildIdentity: BuildIdentity?
}

struct SquadPresence: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    let squadId: UUID
    let workoutStartedAt: Date
    let expiresAt: Date
    var id: UUID { userId }
    var isActive: Bool { Date.now < expiresAt }
}

struct SquadActivityEntry: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case trialCompleted
        case titleUnlocked
        case linkedSession
        case memberJoined
        case affinityChanged
        case squadStreakExtended
    }
    let id: UUID
    let squadId: UUID
    let userId: UUID
    let kind: Kind
    let payload: SquadActivityPayload
    let createdAt: Date
}

enum SquadActivityPayload: Codable, Equatable, Sendable {
    case trialCompleted(trialName: String, theme: TrialTheme)
    case titleUnlocked(titleId: TitleID)
    case linkedSession(participantUserIds: [UUID], durationMinutes: Int)
    case memberJoined(memberDisplayName: String)
    case affinityChanged(newAxis: AttributeKey?, byDisplayName: String)
    case squadStreakExtended(weeks: Int)
}

struct SquadState: Codable, Equatable, Sendable {
    var currentSquad: Squad?
    var roster: [SquadMember]
    var activeRosterPresence: [SquadPresence]
    var recentActivity: [SquadActivityEntry]  // capped at 50
    var unlockedSquadTitles: [SquadTitleID]
    static let empty = SquadState(
        currentSquad: nil,
        roster: [],
        activeRosterPresence: [],
        recentActivity: [],
        unlockedSquadTitles: []
    )
}

struct SquadTitleID: Codable, Hashable, Sendable {
    enum Category: String, Codable, Sendable {
        case linkedSessions      // "The Pact"
        case squadStreak         // "The Streak"
        case collectiveAxis      // "The {Axis} Crew"
        case affinityTenure      // "{Axis} Pact"
    }
    let category: Category
    let axis: AttributeKey?     // only set for .collectiveAxis and .affinityTenure
    let tier: Int               // 1, 2, 3
}
```

### Squad Title catalog (spec-locked)

- **The Pact** (`linkedSessions`): 10 / 50 / 200 linked sessions → tier 1/2/3
- **The Streak** (`squadStreak`): 4 / 12 / 52 weeks → tier 1/2/3
- **The {Axis} Crew** (`collectiveAxis`): collective squad rank-ups on that axis hit 25 / 100 / 300 → tier 1/2/3. Named per axis in `SquadTitleCatalog`:
  - Power: "The Iron Crew"
  - Agility: "The Quick Crew"
  - Control: "The Focused Crew"
  - Endurance: "The Long Haul Crew"
  - Mobility: "The Loose Crew"
  - Explosiveness: "The Storm Crew"
- **{Axis} Pact** (`affinityTenure`): consecutive months with the same axis affinity → 2 / 4 / 12 months → tier 1/2/3. Named "Power Pact" / "Mobility Pact" / etc.

### Services

```swift
@MainActor
protocol SquadServiceProtocol: AnyObject {
    func loadCurrentSquad(userId: String) async
    @discardableResult
    func createSquad(name: String, userId: String) async throws -> Squad
    @discardableResult
    func joinSquad(inviteCode: String, userId: String) async throws -> Squad
    func leaveSquad(userId: String) async throws
    func setAffinity(_ axis: AttributeKey?, userId: String) async throws
    func state(userId: String) -> SquadState
    func aggregateBuildHexValues(userId: String) -> [AttributeKey: Double]
}

@MainActor
protocol SquadPresenceServiceProtocol: AnyObject {
    func markInWorkout(userId: String, squadId: UUID) async
    func clearPresence(userId: String) async
    func subscribeToSquadPresence(squadId: UUID) async
    func unsubscribeFromSquadPresence() async
}

@MainActor
protocol SquadActivityServiceProtocol: AnyObject {
    func record(kind: SquadActivityEntry.Kind, payload: SquadActivityPayload, userId: String) async
    func fetchRecent(userId: String) async throws -> [SquadActivityEntry]
}

final class SquadStore {
    static let shared = SquadStore()
    func load(userId: String) -> SquadState
    func save(_ state: SquadState, userId: String)
}
```

### Notifications

```swift
extension Notification.Name {
    static let squadStateChanged     = Notification.Name("unbound.squadStateChanged")
    static let squadPresenceChanged  = Notification.Name("unbound.squadPresenceChanged")
    static let squadActivityRecorded = Notification.Name("unbound.squadActivityRecorded")
    static let linkedSessionDetected = Notification.Name("unbound.linkedSessionDetected")
    static let squadStreakExtended   = Notification.Name("unbound.squadStreakExtended")
    static let squadTitleUnlocked    = Notification.Name("unbound.squadTitleUnlocked")
}
```

### Cross-service wiring

- `WorkoutLogService.recordSession(start:)` → calls `SquadPresenceService.markInWorkout(userId:squadId:)` if user is in a squad. (New method added to WorkoutLogService for session-start hook.)
- `WorkoutLogService.recompute(after:)` — existing hook — adds a call to `SquadPresenceService.clearPresence(userId:)` after the existing Trials hook.
- `TrialsService.completeCapstone` (existing notification post) — `SquadActivityService` listens for `.trialCompleted` and records a `trialCompleted` entry to the feed.
- `TrialsService` Title unlock (existing notification post `.titleUnlocked`) — `SquadActivityService` listens and records a `titleUnlocked` entry.
- `SquadActivityService.record(kind: .affinityChanged, ...)` fires when captain changes affinity (called inside `SquadService.setAffinity`).
- `SessionXPService.recordSession(userId:at:)` — modify to read the user's squad affinity (if any) and the dominant axis of the just-logged session. The +10% bonus applies only when ALL of: (a) user is in a squad, (b) squad has an `affinityAxis` set this month, AND (c) the session's dominant axis matches that affinity axis. Linked-session +20% supersedes affinity +10% (no double-stacking — if a session is both linked AND affinity-aligned, the user gets +20% only).

### Linked-session evaluator

Server-side Edge Function `detect_linked_sessions`:

1. Triggered on every `workout_logs` insert (Supabase webhook).
2. For the inserted session's `user_id`, look up the squad via `squad_members`.
3. Find other squad members' sessions whose `[started_at, ended_at]` window overlaps with the new session's window by 5+ minutes (configurable `LINKED_SLACK_MINUTES` constant).
4. If any overlap exists: insert one `linked_sessions` row containing the participants (deduped), insert one `squad_activity` row of kind `linkedSession`, and trigger APNs push to all participants via the existing push pipeline.

Client receives the push → opens the app → on `.linkedSessionDetected` notification, `LinkedSessionEvaluator.applyLinkedXPBonus(sessionId:userId:)` adds the +20% XP bonus to `SessionXPService`. In-app toast shows: "Linked with {names} · +20% XP."

### Squad streak evaluator

Nightly cron Edge Function `evaluate_squad_streak` (03:00 UTC):

1. For each squad, query the prior ISO week (Mon 00:00 → Sun 23:59 UTC — or each squad's captain timezone, locked at squad creation).
2. Check whether every member logged ≥1 session in that window.
3. If yes: increment `squad_streak_weeks` on the squad row + insert `squadStreakExtended` activity entry. Check Squad Title thresholds (4, 12, 52) and emit `squadTitleUnlocked` notification via Realtime.
4. If no: reset `squad_streak_weeks` to 0. Do NOT emit activity (broken streaks stay quiet — no shame energy).

### Squad streak title detection

Mirrors `TitleThresholdEvaluator` from sub-project #5 but for `SquadTitleID`. Implemented as `SquadTitleThresholdEvaluator` in `UNBOUND/Services/Squads/`. Triggered from the Edge Function and from client-side `SquadActivityService.record` (for `collectiveAxis` and `affinityTenure` categories — these can cross threshold on activity events the client knows about, so client-side detection is fine).

---

## UI surfaces

### Squad tab — empty state (`SquadEmptyView`)

- Hero copy: "Train with your crew."
- Two primary CTAs: `Create Squad` and `Join Squad`.
- Create flow → sheet with single text field (squad name, 30 char max) → on submit, `SquadService.createSquad` → lands on squad detail.
- Join flow → sheet with 6-char invite code input → on submit, `SquadService.joinSquad` → error toast if invalid/full/already-in-squad.
- Below CTAs: small "How squads work" explainer card (2–3 sentences on linked workouts + monthly affinity).

### Squad tab — populated state (`SquadDetailView`)

Top-to-bottom layout:

1. **Header card** — squad name + member count chip + "Invite" button.
   - Invite button → iOS share sheet with deep link `https://unboundapp.com/squad/<inviteCode>`.
2. **Aggregate Build hex** — `AttributeHex` rendering the squad's average per-axis values. Identity sub-label.
3. **Affinity card** — current axis affinity, axis-colored glow, "Set by Marcus · May 1" sub-line, affinity-tenure progress bar. Captain + day-1-7-of-month: shows "Edit affinity" button.
4. **Squad streak row** — "Squad streak · 12 weeks" with streak icon. Tap → expanded view.
5. **Roster grid** — `SquadMemberCard` per member. Live presence chip when `SquadPresence.isActive`.
6. **Activity feed** — vertical scroll of recent 50 entries. Per-kind rendering (see Section 4).
7. **Squad Titles row** — horizontal scroll of unlocked `SquadTitleBadge` pills (distinct visual from individual `TitleBadge` — wider, small crew icon).
8. **Footer settings** — "Leave squad" link. Captain only: "Rename squad" + "Edit affinity."

### `SquadMemberDetailView`

Pushed when a member is tapped. Renders read-only progression: BuildIdentity hex + displayName, equipped Title, ascendant skills, recent member activity (last 20 entries), rank-ups counter. No messaging, no comments — strictly read-only.

### Linked workout cinematic

When `.linkedSessionDetected` fires while app is open: subtle toast slides up from bottom — "Linked with {names} · +20% session XP" (accent color, 3s auto-dismiss). No fullScreenCover, no chain-shatter.

### Captain affinity picker

Sheet from "Edit affinity" button. 6 axis cards similar to Trial card visual but smaller. Tap → confirm → `setAffinity` → `affinityChanged` activity entry written.

### Push notification surface

Only linked-session pushes. Tap → opens Squad tab, activity feed scrolled to the new linked-session entry. Permission piggybacks the existing Trials request from sub-project #5.

### Empty activity feed

"Train and your crew will see it here." No fake tutorial entries.

---

## Cross-service integration

| Event | Source | Squad effect |
|---|---|---|
| Workout starts | `WorkoutLogService.recordSession(start:)` | `SquadPresenceService.markInWorkout` |
| Workout ends (`recompute(after:)`) | `WorkoutLogService` | `SquadPresenceService.clearPresence` + Edge Function `detect_linked_sessions` |
| Trial completed | `TrialsService` `.trialCompleted` notification | `SquadActivityService.record(.trialCompleted)` |
| Individual title unlocked | `TrialsService` `.titleUnlocked` notification | `SquadActivityService.record(.titleUnlocked)` |
| Affinity changed | `SquadService.setAffinity` | `SquadActivityService.record(.affinityChanged)` |
| Linked session detected | Server-side Edge Function | `linkedSession` activity entry + push + client +20% XP bonus |
| Squad streak extended | Nightly Edge Function | `squadStreakExtended` activity entry + possible `squadTitleUnlocked` |
| XP bonus (affinity-aligned) | `SessionXPService.recordSession` | +10% if session dominant axis matches squad affinity (no stack with linked) |

---

## Testing strategy

### Pure-type tests
- `SquadTests`, `SquadMemberTests`, `SquadPresenceTests`, `SquadActivityEntryTests`, `SquadActivityPayloadTests` — Codable roundtrip + equality.
- `SquadTitleIDTests` — Codable + 4-category coverage.

### Persistence
- `SquadStoreTests` — save/load roundtrip per user; multi-user isolation; empty state on missing user.

### Service tests
- `SquadServiceTests` — uses `MockDatabaseService` + `MockSquadRealtimeChannel`:
  - `createSquad`: captain assignment, unique 6-char invite code, immediate join as captain
  - `joinSquad`: happy path, full-squad rejection, already-in-squad rejection, invalid-code rejection
  - `leaveSquad`: captain transfer to longest-tenured, squad-deletion when last member leaves
  - `setAffinity`: captain-only enforcement, posts `affinityChanged` activity
  - `aggregateBuildHexValues`: per-axis average; single-member edge case
- `SquadActivityServiceTests` — record/fetch roundtrip; payload variants serialize correctly; feed capped at 50 entries.
- `LinkedSessionEvaluatorTests` — 5-min slack window boundary tests; +20% XP application; no stacking with affinity.
- `SquadStreakEvaluatorTests` — every-member-trained logic; reset on any member miss; threshold crossings.
- `SessionXPAffinityBonusTests` — +10% only on match; no bonus without squad/affinity; +20% linked supersedes +10% affinity.

### Snapshot tests
- `SquadEmptyViewSnapshotTests`
- `SquadDetailViewSnapshotTests`
- `SquadMemberDetailViewSnapshotTests`
- `LinkedSessionToastSnapshotTests`
- `SquadTitleBadgeSnapshotTests` (4 categories × 3 tiers)

### Backend tests
- RLS unit tests via `psql` fixtures: non-members can't read squad rows; only captain can update affinity; presence rows filtered by membership.
- Edge Function tests: linked-session detection, nightly streak evaluator, captain-transfer-on-leave.

---

## Migration — pure greenfield

No existing Squad data. On first launch:
- `SquadState` is `.empty`
- Squad tab renders the empty state
- No data migration

APNs permission piggybacks the Trials sub-project's permission request. If denied, linked-session pushes silently no-op — in-app toast still fires when app is open.

**Universal Links setup (one-time DevOps):**
- Add `applinks:unboundapp.com` to app entitlements
- Publish AASA file at `https://unboundapp.com/.well-known/apple-app-site-association` with path pattern `/squad/*`
- Handle `userActivity` in `AniBodyApp` — extract invite code, route to `SquadJoinView` with code pre-filled

---

## Implementation order (informs the plan, not binding)

The writing-plans skill will lay out exact phases. Suggested order:

1. Supabase migration: schema + RLS policies. Apply via Supabase CLI.
2. Core types: `Squad`, `SquadMember`, `SquadPresence`, `SquadActivityEntry`, `SquadActivityPayload`, `SquadState`, `SquadTitleID`.
3. `SquadTitleCatalog` + `SquadTitleThresholdEvaluator`.
4. `SquadStore` (UserDefaults JSON cache).
5. `SquadServiceProtocol` + `SquadService` (createSquad, joinSquad, leaveSquad, setAffinity, state, aggregateBuildHexValues).
6. `SquadActivityServiceProtocol` + `SquadActivityService` (record + fetch).
7. Wire `SquadActivityService` into existing notification posts (`.trialCompleted`, `.titleUnlocked`).
8. `SquadPresenceServiceProtocol` + `SquadPresenceService` (Realtime channel, markInWorkout, clearPresence).
9. Wire `SquadPresenceService` into `WorkoutLogService` (session start + end hooks).
10. Edge Function: `join_squad`.
11. Edge Function: `detect_linked_sessions` + APNs push fan-out.
12. Edge Function: `evaluate_squad_streak` (nightly cron).
13. Client-side `LinkedSessionEvaluator` (applies +20% XP bonus on push receipt).
14. `SessionXPService` affinity bonus integration (+10% when aligned).
15. `SquadTitleBadge` view.
16. `SquadMemberCard` view.
17. `SquadEmptyView`.
18. `SquadDetailView` (with all sub-components).
19. `SquadMemberDetailView`.
20. `LinkedSessionToast` view + presentation.
21. Squad tab integration into main tab bar.
22. Universal Links setup: entitlement + AASA + `userActivity` handler.
23. Final regression + simulator smoke.

---

## Out of scope (deferred)

- Public squad discovery / squad directory.
- Comments, likes, reactions on activity feed entries.
- Squad chat / messaging.
- Squad challenges across squads (e.g., squad-vs-squad competitions).
- Squad name editing post-creation (captain-only edit flow can ship in a later sub-project if needed).
- Member kick / mute features.
- Multi-squad membership (one squad per user for v1).
- Squad profile photos / avatars (initial-based avatars for v1).
- Activity feed pagination beyond the most recent 50 entries.
- Captain-rotation mechanics — captaincy stays with the creator unless they leave (then transfers to longest-tenured).
- Web companion for Squad.
- Apple Watch presence integration.
