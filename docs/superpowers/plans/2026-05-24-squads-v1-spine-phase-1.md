# Squads v1 — Phase 1: Spine + Data Migration

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`docs/superpowers/specs/2026-05-24-squads-v1-redesign-design.md`](../specs/2026-05-24-squads-v1-redesign-design.md). All scope decisions there are binding.

**Goal:** Replace the 11-section `SquadDetailView` with the 5-slab dashboard, introduce the new `SquadMessage` model that will power Phase 2's chat surface, and cleanly remove the cut features (`SquadMission`, `WeeklyHonor`, `SquadTitle`, `AggregateBuildHex`, `Affinity`, legacy `FriendChallenge`). No chat UI, no challenges, no badges yet — pure spine + data work.

**Architecture:** New `SquadMessage` is a polymorphic Codable struct backed by a `squad_message` Supabase table (follows the exact `SquadActivityBackend` pattern). Cut services are deleted outright; their `Notification.Name` listeners are removed from views to prevent dead-listener leaks. Existing squads survive the migration; their old activity history is *not* migrated (clean slate per spec).

**Tech stack:** Swift, SwiftUI, Supabase Postgrest, XCTest. No new infra.

---

## Scope

In:
- New `SquadMessage` Codable model + `SquadMessageBackend` (real + mock) + `SquadMessageStore`
- Supabase migration: create `squad_message` and `squad_message_reaction` tables (DDL only; reactions wired in Phase 2)
- Redesigned `SquadDetailView` (5 slabs)
- Deletion of cut features (`SquadMission*`, `SquadHonors*`, `SquadTitle*`, `WeeklyHonors*`, `FriendChallenge*`, `AffinityPickerSheet`, Aggregate Build hex section)
- Migration notice posted to existing squads on first launch after upgrade
- Hard cap enforcement (6 members) — grandfather rule for squads already over

Out (later phases):
- Chat view, compose, reactions, auto-post pipeline → Phase 2
- Challenges → Phase 3
- Badges, share saved workout, lightweight profile → Phase 4

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/SquadMessage.swift` | **Create** | Polymorphic message: `id, squadId, authorUserId?, kind, payload, createdAt`. Kind enum + payload enum follow `SquadActivityEntry` pattern. |
| `UNBOUND/Models/SquadMessageKind.swift` | **Create** | Enum: `.text, .workout, .pr, .vowSeal, .challengeEvent, .savedWorkoutShare, .system` |
| `UNBOUND/Models/SquadMessagePayload.swift` | **Create** | Associated-value enum mirroring `SquadMessageKind`. `system` carries plain-text reason for migration notice. |
| `UNBOUND/Services/Squads/SquadMessageBackendProtocol.swift` | **Create** | `insert`, `fetchRecent(squadId:limit:beforeId:)`, `subscribe(squadId:)` (returns AsyncStream) |
| `UNBOUND/Services/Squads/SquadMessageBackend.swift` | **Create** | Production impl using Supabase (clone `SquadActivityBackend` structure). |
| `UNBOUND/Services/Squads/MockSquadMessageBackend.swift` | **Create** | In-memory store for tests; mimics realtime via internal continuation. |
| `UNBOUND/Services/Squads/SquadMessageStore.swift` | **Create** | Caches recent messages per squad, subscribes to backend, exposes `@Published` array via Combine. |
| `UNBOUND/Services/ServiceContainer.swift` | **Modify** | Add `squadMessages: SquadMessageStore` slot. Remove `squadMission`, `squadHonors`, `friendChallenge`. |
| `UNBOUND/Views/Squads/SquadDetailView.swift` | **Rewrite** | New 5-slab layout (Header, CrewStreakBadgeSlot stub, Crew, ChallengesSection stub, Recent). Stubs are real Views that render empty/placeholder; Phase 3/4 fill them. |
| `UNBOUND/Views/Squads/SquadHeaderCard.swift` | **Create** | Crest placeholder, name, member count, streak indicator, `[💬 Open Chat]` button (disabled in P1 with "Coming soon" toast), `[+ Invite]` ShareLink. |
| `UNBOUND/Views/Squads/SquadCrewGrid.swift` | **Create** | 2-column grid, each tile = avatar + presence dot + this-week count + equipped title. Tap → existing `SquadMemberDetailView` (refactored later in P4). |
| `UNBOUND/Views/Squads/SquadCrewStreakBadgeSlot.swift` | **Create (stub)** | Renders "No crew streak yet" or current `squadStreakWeeks` count — full badge UI lands in P4. |
| `UNBOUND/Views/Squads/SquadChallengesSection.swift` | **Create (stub)** | Renders "No active challenges" — Phase 3 fills it. |
| `UNBOUND/Views/Squads/SquadRecentStrip.swift` | **Create (stub)** | Renders "Recent activity appears here" — Phase 2 fills it from `SquadMessageStore`. |
| `UNBOUND/Models/Squad.swift` | **Modify** | Remove `affinityAxis: AttributeKey?` and `affinitySetAt: Date?`. Update `Codable` keys. |
| `UNBOUND/Models/SquadActivityEntry.swift` | **Delete** | Replaced by `SquadMessage`. |
| `UNBOUND/Models/SquadActivityPayload.swift` | **Delete (if separate file)** | — |
| `UNBOUND/Models/SquadMission.swift` | **Delete** | Cut. |
| `UNBOUND/Models/SquadTitleID.swift` | **Delete** | Cut. |
| `UNBOUND/Models/SquadHonors*` (if present) | **Delete** | Cut. |
| `UNBOUND/Models/FriendChallenge.swift` | **Delete** | Replaced in Phase 3. |
| `UNBOUND/Services/Squads/SquadMissionService.swift` | **Delete** | Cut. |
| `UNBOUND/Services/Squads/SquadMissionCatalog.swift` | **Delete** | Cut. |
| `UNBOUND/Services/Squads/SquadHonorsService.swift` | **Delete** | Cut. |
| `UNBOUND/Services/Squads/SquadTitleCatalog.swift` | **Delete** | Cut. |
| `UNBOUND/Services/Squads/SquadTitleThresholdEvaluator.swift` | **Delete** | Cut. |
| `UNBOUND/Services/Squads/SquadActivityBackend.swift` | **Delete** | Replaced by `SquadMessageBackend`. |
| `UNBOUND/Services/Squads/SquadActivityService.swift` | **Delete** | Replaced. |
| `UNBOUND/Services/Squads/MockSquadActivityBackend.swift` | **Delete** | Replaced. |
| `UNBOUND/Services/Squads/SquadActivityBackendProtocol.swift` | **Delete** | Replaced. |
| `UNBOUND/Services/Squads/SquadActivityServiceProtocol.swift` | **Delete** | Replaced. |
| `UNBOUND/Services/Squads/FriendChallengeService.swift` | **Delete** | Replaced in Phase 3. |
| `UNBOUND/Views/Squads/FriendChallengeCard.swift` | **Delete** | Replaced in Phase 3. |
| `UNBOUND/Views/Squads/FriendChallengeCreateSheet.swift` | **Delete** | Replaced in Phase 3. |
| `UNBOUND/Views/Squads/FriendChallengeOutcomeToast.swift` | **Delete** | Replaced in Phase 3. |
| `UNBOUND/Views/Squads/SquadMissionCard.swift` | **Delete** | Cut. |
| `UNBOUND/Views/Squads/AffinityPickerSheet.swift` (if present) | **Delete** | Cut. |
| `UNBOUND/Views/Components/Unbound/SquadTitleBadge.swift` | **Delete** | Cut. |
| `UNBOUND/Services/Squads/SquadService.swift` | **Modify** | Drop `setAffinity`, `aggregateBuildHexValues`. Add 6-member cap check in `joinSquad`. Add migration helper `postMigrationNoticeIfNeeded(squadId:)` that posts a `.system` SquadMessage once per squad. |
| `UNBOUND/Services/Squads/SquadServiceProtocol.swift` | **Modify** | Drop the cut methods from the protocol. |
| `db/migrations/20260524_squad_message.sql` | **Create** | DDL for `squad_message` + `squad_message_reaction` + `drop table squad_activity` + drop `squad_mission`, `weekly_honor`, `squad_title_unlock`, `friend_challenge`. Idempotent. |
| `UNBOUND/UNBOUNDTests/Models/SquadMessageTests.swift` | **Create** | Codable round-trip for every payload kind. |
| `UNBOUND/UNBOUNDTests/Services/SquadMessageBackendTests.swift` | **Create** | Mock backend: insert + fetch + subscribe round-trip. |
| `UNBOUND/UNBOUNDTests/Services/SquadServiceCapEnforcementTests.swift` | **Create** | Joining a full squad (6 members) throws `.squadFull`; grandfathered squad >6 cannot accept new joins. |
| `UNBOUND/UNBOUNDTests/Services/SquadMigrationNoticeTests.swift` | **Create** | First load of a pre-existing squad posts exactly one `.system` message; second load posts none. |

---

## Tasks

### Task P1.0 — Run the Supabase migration

**File:** Create `db/migrations/20260524_squad_message.sql`.

DDL (in this order, single transaction):

```sql
create table if not exists public.squad_message (
  id uuid primary key,
  squad_id uuid not null references public.squad(id) on delete cascade,
  author_user_id uuid references auth.users(id) on delete set null,
  kind text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_squad_message_squad_created
  on public.squad_message (squad_id, created_at desc);

create table if not exists public.squad_message_reaction (
  id uuid primary key,
  message_id uuid not null references public.squad_message(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (message_id, user_id, emoji)
);
create index if not exists idx_squad_message_reaction_message
  on public.squad_message_reaction (message_id);

-- Realtime
alter publication supabase_realtime add table public.squad_message;
alter publication supabase_realtime add table public.squad_message_reaction;

-- Drop cut tables (idempotent)
drop table if exists public.squad_mission cascade;
drop table if exists public.weekly_honor cascade;
drop table if exists public.squad_title_unlock cascade;
drop table if exists public.friend_challenge cascade;
drop table if exists public.squad_activity cascade;

-- Drop cut columns
alter table public.squad drop column if exists affinity_axis;
alter table public.squad drop column if exists affinity_set_at;
```

**Acceptance:** Migration runs cleanly on a snapshot of the production schema in a Supabase branch. No FKs leave dangling references.

**Commit:** `db(squads-v1): drop cut tables, add squad_message + reactions`

### Task P1.1 — `SquadMessage` model + payload

**Files:** Create `SquadMessage.swift`, `SquadMessageKind.swift`, `SquadMessagePayload.swift`.

```swift
// SquadMessageKind.swift
enum SquadMessageKind: String, Codable, Sendable, CaseIterable {
    case text
    case workout
    case pr
    case vowSeal
    case challengeEvent
    case savedWorkoutShare
    case system
}

// SquadMessagePayload.swift — payloads for non-text kinds; `text` carries only the body string on the parent
enum SquadMessagePayload: Codable, Equatable, Sendable {
    case text(body: String)
    case workout(workoutId: UUID, title: String, durationMin: Int, rpe: Int?)
    case pr(workoutId: UUID, exerciseName: String, summary: String) // e.g. "Front Lever +2s"
    case vowSeal(vowName: String)
    case challengeEvent(challengeId: UUID, kind: String, body: String) // Phase 3 fills `kind`
    case savedWorkoutShare(savedWorkoutId: UUID, title: String)
    case system(body: String)
}

// SquadMessage.swift
struct SquadMessage: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let authorUserId: UUID?    // nil for system + auto-generated
    let kind: SquadMessageKind
    let payload: SquadMessagePayload
    let createdAt: Date
}
```

**Acceptance:** Codable round-trip for every payload kind (one test case per kind in `SquadMessageTests.swift`). `text(body:)` body equals what was encoded.

**Commit:** `feat(squads-v1): SquadMessage polymorphic model`

### Task P1.2 — `SquadMessageBackendProtocol` + Mock

**Files:** Create `SquadMessageBackendProtocol.swift`, `MockSquadMessageBackend.swift`.

```swift
protocol SquadMessageBackendProtocol: Sendable {
    func insert(_ message: SquadMessage) async throws
    func fetchRecent(squadId: UUID, limit: Int, beforeId: UUID?) async throws -> [SquadMessage]
    func subscribe(squadId: UUID) -> AsyncStream<SquadMessage>
}
```

Mock: in-memory `[UUID: [SquadMessage]]` per squadId, plus per-squad `AsyncStream.Continuation` for live updates. `insert` appends and emits to all open continuations for that squadId.

**Acceptance:** `SquadMessageBackendTests` verifies: insert → fetchRecent returns it; insert → subscribe stream emits it; fetchRecent with `beforeId` paginates correctly.

**Commit:** `feat(squads-v1): SquadMessageBackend protocol + mock`

### Task P1.3 — Production `SquadMessageBackend`

**File:** Create `SquadMessageBackend.swift`. Clone the structure of `SquadActivityBackend` (before its deletion in Task P1.13).

Use Supabase Realtime channels for `subscribe(squadId:)`. Each call creates a fresh channel filtered by `squad_id`, subscribes, maps `RealtimePostgresInsert` events to `SquadMessage`, yields to AsyncStream. On stream cancellation, unsubscribe the channel.

Encoding: store `kind` as string, `payload` as JSONB blob (one column). Use a flat `MessageInsertRow` Encodable struct similar to `SquadActivityBackend.ActivityInsertRow`.

**Acceptance:** Manual smoke against the Supabase dev project — insert from one device, see it on another via subscribe. Errors logged via `LoggingService.shared`.

**Commit:** `feat(squads-v1): production SquadMessageBackend with Realtime`

### Task P1.4 — `SquadMessageStore`

**File:** Create `SquadMessageStore.swift`.

```swift
@MainActor
final class SquadMessageStore: ObservableObject {
    @Published private(set) var messagesBySquad: [UUID: [SquadMessage]] = [:]
    private let backend: SquadMessageBackendProtocol
    private var subscriptions: [UUID: Task<Void, Never>] = [:]

    init(backend: SquadMessageBackendProtocol) { self.backend = backend }

    func load(squadId: UUID, limit: Int = 50) async { ... }
    func subscribe(squadId: UUID) { ... } // idempotent
    func unsubscribe(squadId: UUID) { ... }
    func send(_ message: SquadMessage) async throws { ... } // insert via backend; local optimistic append
    func messages(for squadId: UUID) -> [SquadMessage] { messagesBySquad[squadId] ?? [] }
}
```

**Acceptance:** Unit test (with mock backend) verifies: load fills the published array; subscribe is idempotent; send appends optimistically and survives a duplicate echo from the backend (dedupe by `id`).

**Commit:** `feat(squads-v1): SquadMessageStore with realtime subscribe`

### Task P1.5 — Wire `SquadMessageStore` into `ServiceContainer`

**File:** Modify `ServiceContainer.swift`.

- Add `let squadMessages: SquadMessageStore`
- Initialize with `SquadMessageBackend.shared` in the production path, `MockSquadMessageBackend()` in `.mock`.
- Remove the `squadMission`, `squadHonors`, `friendChallenge` slots and any initializers that reference them.

**Acceptance:** App compiles. `ServiceContainer.mock` still constructs.

**Commit:** `chore(services): wire SquadMessageStore; drop cut squad services`

### Task P1.6 — Delete cut models

Delete the following files:
- `SquadActivityEntry.swift` (and any separate `SquadActivityPayload.swift`)
- `SquadMission.swift`
- `SquadTitleID.swift`
- `FriendChallenge.swift`
- Any `WeeklyHonor*.swift`

Then `grep -rn` for each of these symbols in `UNBOUND/` and remove every reference (often in views like `SquadDetailView.swift`, `SquadMemberDetailView.swift`, `ProgramOverviewView.swift`). Compile until clean.

**Acceptance:** `xcodebuild build -scheme UNBOUND` succeeds. No references remain to the deleted symbols.

**Commit:** `feat(squads-v1): delete cut models (mission, title, honor, friend-challenge)`

### Task P1.7 — Delete cut services + views

Delete:
- `SquadMissionService.swift`, `SquadMissionCatalog.swift`
- `SquadHonorsService.swift`
- `SquadTitleCatalog.swift`, `SquadTitleThresholdEvaluator.swift`
- `SquadActivityBackend.swift`, `SquadActivityService.swift`, `MockSquadActivityBackend.swift`, `SquadActivityBackendProtocol.swift`, `SquadActivityServiceProtocol.swift`
- `FriendChallengeService.swift`, `FriendChallengeCard.swift`, `FriendChallengeCreateSheet.swift`, `FriendChallengeOutcomeToast.swift`
- `SquadMissionCard.swift`
- `AffinityPickerSheet.swift` (if exists)
- `SquadTitleBadge.swift`

Remove all corresponding `.onReceive(NotificationCenter…)` listeners in `SquadDetailView`, `SquadTabView`, etc. — the `Notification.Name`s themselves can stay (they're declared in `AttributeRankUpEvent.swift`), they just won't be posted anymore. Cleanup the unused `Notification.Name` extensions in a follow-up.

**Acceptance:** Build still green. `grep -rn FriendChallenge UNBOUND/` returns zero hits.

**Commit:** `feat(squads-v1): delete cut services + views`

### Task P1.8 — `Squad` model: drop Affinity fields + cap-aware members

**File:** Modify `Squad.swift`.

- Remove `affinityAxis: AttributeKey?` and `affinitySetAt: Date?` properties.
- Update any `init` and `CodingKeys`.
- Add a constant `static let maxMembers = 6`.

`SquadService.joinSquad` already enforces `squad.maxSize`. Update it to use `Squad.maxMembers` (cap = 6 hard). If `roster.count >= 6`, throw `SquadError.squadFull`.

For grandfathered squads (existing data with >6 members), do nothing on read; new joins are blocked. Add a test in `SquadServiceCapEnforcementTests`.

**Acceptance:** `SquadServiceCapEnforcementTests` passes: 6-member squad → join throws `.squadFull`. 7-member grandfathered squad → join also throws.

**Commit:** `feat(squads-v1): drop affinity fields + enforce 6-member cap`

### Task P1.9 — Migration notice helper

**File:** Modify `SquadService.swift`.

```swift
// Posts one .system SquadMessage to each squad once, on first load after upgrade.
// Idempotency: writes a UserDefaults key per squad id ("squad.migrationNoticePosted.<uuid>").
func postMigrationNoticeIfNeeded(squadId: UUID) async {
    let key = "squad.migrationNoticePosted.\(squadId.uuidString)"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    let msg = SquadMessage(
        id: UUID(),
        squadId: squadId,
        authorUserId: nil,
        kind: .system,
        payload: .system(body: "Squads got an update. Mission, Honors, and Titles are gone. Challenges, badges, and chat coming over the next few weeks."),
        createdAt: Date()
    )
    try? await services.squadMessages.send(msg)  // through the store
    UserDefaults.standard.set(true, forKey: key)
}
```

Call `postMigrationNoticeIfNeeded` from `SquadDetailView.task` after `loadAll()`.

**Acceptance:** `SquadMigrationNoticeTests` — first load posts one `.system` message; second load posts none.

**Commit:** `feat(squads-v1): one-time migration notice per squad`

### Task P1.10 — `SquadHeaderCard`

**File:** Create `SquadHeaderCard.swift`.

```swift
struct SquadHeaderCard: View {
    let squad: Squad
    let memberCount: Int
    let openChat: () -> Void   // P1: shows "Coming soon" toast; P2 wires it
    let inviteURL: URL?
}
```

Visual: crest placeholder (rounded rect, accent gradient, first 2 letters of squad name), name, `🔥 N-week streak`, `[💬 Open Chat]` button (disabled visual state in P1 — but tappable to show toast `"Chat opens in the next update"`), `[+ Invite]` ShareLink.

**Acceptance:** SwiftUI preview shows expected layout. Tapping Open Chat in P1 shows the toast.

**Commit:** `feat(squads-v1): SquadHeaderCard`

### Task P1.11 — `SquadCrewGrid`

**File:** Create `SquadCrewGrid.swift`.

2-column grid using `LazyVGrid`. Each tile:
- 34pt circular avatar (placeholder gradient by user id hash for now; real avatar in P4 if available)
- Green dot overlay if `SquadPresence.isActive` for this user
- Member name
- "training now" / "N sessions this week" subline
- Tap → opens `SquadMemberDetailView` (existing — leave untouched in P1, polish in P4)

**Acceptance:** Preview renders 4 members; presence dot only on the one marked active.

**Commit:** `feat(squads-v1): SquadCrewGrid with presence`

### Task P1.12 — Stub slots for later phases

**Files:** Create `SquadCrewStreakBadgeSlot.swift`, `SquadChallengesSection.swift`, `SquadRecentStrip.swift`.

Each renders a minimal placeholder. Examples:

```swift
// SquadCrewStreakBadgeSlot.swift
struct SquadCrewStreakBadgeSlot: View {
    let squadStreakWeeks: Int
    var body: some View {
        HStack {
            Image(systemName: "flame.fill").foregroundStyle(Color.unbound.warnOrange)
            VStack(alignment: .leading) {
                Text("CREW STREAK").unboundLabel()
                Text(squadStreakWeeks == 0 ? "No streak yet" : "\(squadStreakWeeks) wk\(squadStreakWeeks == 1 ? "" : "s")")
                    .font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.unbound.surface))
    }
}
```

Stubs for `SquadChallengesSection` (empty state: "No active challenges. Phase 3 adds the create flow.") and `SquadRecentStrip` ("Recent activity will land here once chat ships.") are similar.

**Acceptance:** Each stub previews. Tests not required.

**Commit:** `feat(squads-v1): stub slots for crew-streak / challenges / recent`

### Task P1.13 — Rewrite `SquadDetailView`

**File:** Rewrite `SquadDetailView.swift`.

New body — single `ScrollView` containing, in order: `SquadHeaderCard`, `SquadCrewStreakBadgeSlot`, `SquadCrewGrid`, `SquadChallengesSection`, `SquadRecentStrip`, `footerSection` (Leave button).

Strip all `.onReceive` listeners for `.squadMissionCompleted`, `.weeklyHonorReceived`, `.friendChallengeExpired`. Keep `.squadStateChanged` and `.squadPresenceChanged`.

On `.task`, call `services.squads.loadCurrentSquad` then `services.squads.postMigrationNoticeIfNeeded(squadId:)`.

`[💬 Open Chat]` callback in P1 shows a transient toast: `"Chat ships in the next update."` — wire to real navigation in P2.

**Acceptance:** Build green. UI shows the new 5-slab layout in the simulator. Existing squads load without crash. Migration notice appears once.

**Commit:** `feat(squads-v1): rewrite SquadDetailView with 5-slab spine`

### Task P1.14 — Cleanup `SquadServiceProtocol`

**File:** Modify `SquadServiceProtocol.swift`.

- Remove `setAffinity(_:userId:)`
- Remove `aggregateBuildHexValues(userId:)`
- Remove their implementations in `SquadService.swift` and `MockSquadService.swift` (if it exists)

**Acceptance:** Compile + all squad tests green.

**Commit:** `refactor(squads-v1): drop setAffinity + aggregateBuildHexValues from protocol`

---

## Verification (end of phase)

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Models/SquadMessageTests \
  -only-testing:UNBOUNDTests/Services/SquadMessageBackendTests \
  -only-testing:UNBOUNDTests/Services/SquadServiceCapEnforcementTests \
  -only-testing:UNBOUNDTests/Services/SquadMigrationNoticeTests
```

All green = Phase 1 done. Hand off to Phase 2 (Chat).

Manual sanity check on a real device:
1. Launch with an existing squad → 5-slab layout renders, migration notice card appears in the (placeholder) recent strip.
2. Tap `Open Chat` → toast appears, no navigation.
3. Try to join a 6-member squad → blocked with friendly error.
