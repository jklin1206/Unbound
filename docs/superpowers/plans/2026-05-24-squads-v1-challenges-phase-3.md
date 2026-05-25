# Squads v1 — Phase 3: Challenges (Open + Co-op Pair)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`docs/superpowers/specs/2026-05-24-squads-v1-redesign-design.md`](../specs/2026-05-24-squads-v1-redesign-design.md). Phases 1–2 must be landed: this phase posts challenge state changes into `SquadMessage` as `.challengeEvent` cards.

**Goal:** Ship the two challenge types — Open (post-join-submit-score, honor system) and Co-op Pair (invite-accept-progress-clear/miss) — with full lifecycle, in-chat rendering as rich cards, and XP awards on completion.

**Architecture:** Two separate model + service families because the lifecycles and UIs differ enough that a generic "Challenge" would be a wrong abstraction in v1. They share the side-effect surface: every state transition emits a `SquadMessage(.challengeEvent)` via `SquadMessageStore`, and the Phase 2 stub `ChallengeEventBubble` is now replaced with a real rich renderer dispatched on the underlying challenge id + state.

**Tech stack:** Swift, SwiftUI, Supabase Postgrest, XCTest.

---

## Scope

In:
- `OpenChallenge` model + service + backend + create UI + score submission + scoreboard
- `CoopPairChallenge` model + service + backend + invite/accept UI + progress + clear/miss logic
- Replace stub `ChallengeEventBubble` with real renderer for each (sub)state
- `[+ New Challenge]` entry from `SquadChallengesSection`
- XP awards: +10 Open join, +25 Open win, +50 Co-op pair clear
- Auto-tracking: Co-op pair "session count" progress derives from logged workouts within window (no manual increment)
- Notifications: new invite, invite accepted, challenge cleared/missed, score submitted

Out:
- Named badges (Phase 4 owns Accountability badge counter that fires on challenge clear)
- Competitive pair, Binding Vow seal, routine head-to-head, crew quest (all YAGNI per spec)
- Witness-confirm on Open submissions

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/OpenChallenge.swift` | **Create** | `id, squadId, creatorUserId, title, dueAt?, createdAt, status`. Status: `.open, .closed, .canceled`. |
| `UNBOUND/Models/OpenChallengeJoiner.swift` | **Create** | `id, challengeId, userId, joinedAt, score?, submittedAt?` |
| `UNBOUND/Models/CoopPairChallenge.swift` | **Create** | `id, squadId, creatorUserId, partnerUserId, targetSessions, windowStart, windowEnd, status, creatorProgress, partnerProgress`. Status: `.pending, .active, .cleared, .missed, .declined, .canceled`. |
| `UNBOUND/Services/Squads/OpenChallengeBackendProtocol.swift` | **Create** | CRUD + subscribe |
| `UNBOUND/Services/Squads/OpenChallengeBackend.swift` | **Create** | Supabase impl |
| `UNBOUND/Services/Squads/MockOpenChallengeBackend.swift` | **Create** | — |
| `UNBOUND/Services/Squads/OpenChallengeService.swift` | **Create** | Business logic: create, join, submitScore, closeIfDue, declareWinner. Emits `.challengeEvent` messages on state changes. |
| `UNBOUND/Services/Squads/CoopPairChallengeBackendProtocol.swift` | **Create** | CRUD + subscribe |
| `UNBOUND/Services/Squads/CoopPairChallengeBackend.swift` | **Create** | Supabase impl |
| `UNBOUND/Services/Squads/MockCoopPairChallengeBackend.swift` | **Create** | — |
| `UNBOUND/Services/Squads/CoopPairChallengeService.swift` | **Create** | Business logic: invite, accept, decline, recomputeProgress (called on workoutCompleted), finalizeIfWindowClosed |
| `UNBOUND/Services/Squads/ChallengeXPAwarder.swift` | **Create** | Single place that posts XP credits to the existing XP system (see Phase 4 for the XP wallet; for P3 just call the existing `XPService.shared.award(userId:, amount:, reason:)` or its equivalent — locate via grep `XP` in `UNBOUND/Services/`). |
| `UNBOUND/Services/ServiceContainer.swift` | **Modify** | Wire the two new services. |
| `UNBOUND/Views/Squads/SquadChallengesSection.swift` | **Modify (no longer stub)** | List active CoopPair + Open challenges for current user. `[+ New Challenge]` button → opens `NewChallengeSheet`. |
| `UNBOUND/Views/Squads/Challenges/NewChallengeSheet.swift` | **Create** | First step picks type (Open vs Co-op Pair), then routes to the appropriate creator. |
| `UNBOUND/Views/Squads/Challenges/CreateOpenChallengeView.swift` | **Create** | Title field + optional due date picker + Post button. |
| `UNBOUND/Views/Squads/Challenges/CreateCoopPairChallengeView.swift` | **Create** | Pick partner from roster + target sessions stepper (range 1–14) + window selector (default Mon–Sun this week). |
| `UNBOUND/Views/Squads/Challenges/OpenChallengeCard.swift` | **Create** | Rich card for chat: title, joiners with scores, winner highlight when closed. |
| `UNBOUND/Views/Squads/Challenges/CoopPairChallengeCard.swift` | **Create** | Rich card for chat: per-person progress bars, status badge, action buttons (Accept/Decline when pending). |
| `UNBOUND/Views/Squads/Challenges/SubmitScoreSheet.swift` | **Create** | One numeric field + Submit. |
| `UNBOUND/Views/Squads/Chat/ChallengeEventBubble.swift` | **Modify (replace stub)** | Renders `OpenChallengeCard` or `CoopPairChallengeCard` depending on which challenge id resolves. |
| `UNBOUND/Models/SquadMessagePayload.swift` | **Modify** | Tighten `.challengeEvent` to `case challengeEvent(challengeKind: ChallengeKind, challengeId: UUID, eventKind: ChallengeEventKind, body: String)`. `ChallengeKind: .open | .coopPair`. `ChallengeEventKind: .created, .joined, .scored, .closed, .invited, .accepted, .declined, .progressUpdate, .cleared, .missed`. |
| `UNBOUND/Services/Squads/SquadMessageAutoPoster.swift` | **Modify** | Add observers for the new `Notification.Name`s posted by the two challenge services (e.g. `.openChallengeCreated`, `.coopPairChallengeCleared`). For each, post a corresponding `.challengeEvent` SquadMessage. |
| `db/migrations/20260601_squad_challenges.sql` | **Create** | `open_challenge`, `open_challenge_joiner`, `coop_pair_challenge` tables + indexes. |
| `UNBOUND/UNBOUNDTests/Services/OpenChallengeServiceTests.swift` | **Create** | Create, join, submit, close on due, winner declared by highest score, ties handled |
| `UNBOUND/UNBOUNDTests/Services/CoopPairChallengeServiceTests.swift` | **Create** | Invite, accept, decline, progress auto-recompute on workoutCompleted, clear when both hit, miss when window closes |
| `UNBOUND/UNBOUNDTests/Services/ChallengeXPAwarderTests.swift` | **Create** | Cleared challenge awards correct XP to both crewmates |
| `UNBOUND/UNBOUNDUITests/ChallengeWalkthroughTests.swift` | **Create** | End-to-end: create co-op pair → both train 4 sessions → cleared card appears → both got XP |

---

## Tasks

### Task P3.1 — DDL for challenges

**File:** `db/migrations/20260601_squad_challenges.sql`.

```sql
create table if not exists public.open_challenge (
  id uuid primary key,
  squad_id uuid not null references public.squad(id) on delete cascade,
  creator_user_id uuid not null references auth.users(id),
  title text not null,
  due_at timestamptz,
  created_at timestamptz not null default now(),
  status text not null default 'open'   -- 'open', 'closed', 'canceled'
);

create table if not exists public.open_challenge_joiner (
  id uuid primary key,
  challenge_id uuid not null references public.open_challenge(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  score numeric,
  submitted_at timestamptz,
  unique (challenge_id, user_id)
);

create table if not exists public.coop_pair_challenge (
  id uuid primary key,
  squad_id uuid not null references public.squad(id) on delete cascade,
  creator_user_id uuid not null references auth.users(id),
  partner_user_id uuid not null references auth.users(id),
  target_sessions int not null check (target_sessions between 1 and 14),
  window_start timestamptz not null,
  window_end timestamptz not null,
  status text not null default 'pending',  -- 'pending','active','cleared','missed','declined','canceled'
  creator_progress int not null default 0,
  partner_progress int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_coop_pair_squad on public.coop_pair_challenge(squad_id, status);

-- Realtime
alter publication supabase_realtime add table public.open_challenge;
alter publication supabase_realtime add table public.open_challenge_joiner;
alter publication supabase_realtime add table public.coop_pair_challenge;
```

**Acceptance:** Migration runs cleanly. Realtime publications confirmed.

**Commit:** `db(squads-v1): challenge tables`

### Task P3.2 — `OpenChallenge` + `OpenChallengeJoiner` models

**Files:** `OpenChallenge.swift`, `OpenChallengeJoiner.swift`.

```swift
struct OpenChallenge: Codable, Identifiable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case open, closed, canceled }
    let id: UUID
    let squadId: UUID
    let creatorUserId: UUID
    let title: String
    let dueAt: Date?
    let createdAt: Date
    var status: Status
}

struct OpenChallengeJoiner: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let challengeId: UUID
    let userId: UUID
    let joinedAt: Date
    var score: Double?
    var submittedAt: Date?
}
```

**Acceptance:** Codable round-trip test.

**Commit:** `feat(squads-v1): OpenChallenge models`

### Task P3.3 — `OpenChallengeService` + mocks

**Files:** `OpenChallengeBackendProtocol.swift`, `OpenChallengeBackend.swift`, `MockOpenChallengeBackend.swift`, `OpenChallengeService.swift`.

Service API:
```swift
@MainActor
final class OpenChallengeService {
    func create(squadId: UUID, title: String, dueAt: Date?) async throws -> OpenChallenge
    func join(challengeId: UUID, userId: UUID) async throws
    func submitScore(challengeId: UUID, userId: UUID, score: Double) async throws
    func cancel(challengeId: UUID) async throws            // creator only
    func closeIfDue(challengeId: UUID) async throws         // idempotent; declares winner
    func activeInSquad(squadId: UUID) async throws -> [OpenChallenge]
    func joiners(challengeId: UUID) async throws -> [OpenChallengeJoiner]
}
```

State transitions and side effects (each posts a `.challengeEvent` `SquadMessage` via `SquadMessageStore.send`):
- `create` → `.created` event card; status = `.open`
- `join` → `.joined` event card; appends a joiner row
- `submitScore` → `.scored` event card; updates joiner; if all joiners have submitted OR `dueAt < now`, calls `closeIfDue`
- `closeIfDue` → finds highest-scoring joiner (ties: first submitted wins), sets status `.closed`, posts `.closed` card with winner. Awards XP via `ChallengeXPAwarder.openWon(userId:)` (+25) and `.openJoined(userId:)` (+10) for each joiner who didn't win (winners already credited 10 + 25 = 35).
- `cancel` → status `.canceled`; no XP

For dueAt enforcement when no one submits: also schedule a system-side `closeIfDue` task (a Postgres function trigger that fires daily would be ideal; for v1 fallback, check on every app cold-start across the user's active challenges).

**Acceptance:** `OpenChallengeServiceTests`:
- Create / join / submit / close round-trip
- Highest score wins
- Tied scores → earliest submitter wins
- Cancel before any submissions → no XP, no winner posted
- Reopen attempt fails (status `.closed` is terminal)

**Commit:** `feat(squads-v1): OpenChallengeService with honor-system scoreboard`

### Task P3.4 — `CoopPairChallenge` model + service + mocks

**Files:** `CoopPairChallenge.swift`, `CoopPairChallengeBackendProtocol.swift`, `CoopPairChallengeBackend.swift`, `MockCoopPairChallengeBackend.swift`, `CoopPairChallengeService.swift`.

```swift
struct CoopPairChallenge: Codable, Identifiable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending, active, cleared, missed, declined, canceled
    }
    let id: UUID
    let squadId: UUID
    let creatorUserId: UUID
    let partnerUserId: UUID
    let targetSessions: Int
    let windowStart: Date
    let windowEnd: Date
    var status: Status
    var creatorProgress: Int
    var partnerProgress: Int
}
```

Service API:
```swift
@MainActor
final class CoopPairChallengeService {
    func invite(squadId: UUID, creatorId: UUID, partnerId: UUID,
                targetSessions: Int, windowStart: Date, windowEnd: Date) async throws -> CoopPairChallenge
    func accept(challengeId: UUID, partnerId: UUID) async throws
    func decline(challengeId: UUID, partnerId: UUID) async throws
    func cancel(challengeId: UUID) async throws           // creator only, only while pending
    func recomputeProgress(workoutCompletedAt date: Date, userId: UUID) async  // called by auto-poster
    func finalizeIfWindowClosed(challengeId: UUID) async throws  // idempotent; sets cleared or missed
    func activeForUser(userId: UUID) async throws -> [CoopPairChallenge]
}
```

State transitions:
- `invite` → status `.pending`, posts `.invited` card with `[Accept] [Decline]` buttons
- `accept` → status `.active`, posts `.accepted` card
- `decline` → status `.declined`, posts `.declined` card; no XP
- `cancel` → status `.canceled` (only if pending), no XP
- `recomputeProgress` (called on every `.workoutCompleted` notification): for any active challenges where userId == creator or partner AND windowStart ≤ date ≤ windowEnd, increment that side's progress by 1. If both `creatorProgress >= targetSessions` AND `partnerProgress >= targetSessions`, transition to `.cleared` and call `ChallengeXPAwarder.coopPairCleared(creator:, partner:)` (+50 each); post `.cleared` card.
- `finalizeIfWindowClosed`: at `windowEnd`, if not `.cleared`, set `.missed`, post `.missed` card with Rematch CTA.

Idempotency: every transition first re-reads status and short-circuits if already terminal.

Wire `recomputeProgress` into `SquadMessageAutoPoster` (or a dedicated listener) — when `.workoutCompleted` fires, call `services.coopPair.recomputeProgress(...)` BEFORE posting the workout `SquadMessage` so the resulting `.progressUpdate` lands after the workout card in chat.

**Acceptance:** `CoopPairChallengeServiceTests`:
- Invite → accept → 4 workouts on each side → cleared card + XP awarded
- Invite → decline → status declined, no XP
- Invite → accept → window closes with 4/3 → missed card; rematch CTA fires `invite` with same params
- Re-accept a declined challenge throws
- Workout outside window does not increment progress

**Commit:** `feat(squads-v1): CoopPairChallengeService with auto-progress`

### Task P3.5 — `ChallengeXPAwarder`

**File:** `ChallengeXPAwarder.swift`.

Find the existing XP system in the codebase (grep for `XPService`, `Experience`, `awardXP`). If none exists, write a minimal `XPWallet` service backed by `UserDefaults` (this is fine — Phase 4 may upgrade it). The awarder is a thin pass-through:

```swift
@MainActor
struct ChallengeXPAwarder {
    private let wallet: XPWalletProtocol
    func openJoined(userId: UUID) { wallet.award(userId: userId, amount: 10, reason: "Open challenge join") }
    func openWon(userId: UUID)    { wallet.award(userId: userId, amount: 25, reason: "Open challenge win") }
    func coopPairCleared(creator: UUID, partner: UUID) {
        wallet.award(userId: creator, amount: 50, reason: "Co-op pair challenge cleared")
        wallet.award(userId: partner, amount: 50, reason: "Co-op pair challenge cleared")
    }
}
```

**Acceptance:** `ChallengeXPAwarderTests` — both members' wallets increment by 50 on co-op clear; both don't increment on miss/decline.

**Commit:** `feat(squads-v1): ChallengeXPAwarder`

### Task P3.6 — `NewChallengeSheet` + `CreateOpenChallengeView` + `CreateCoopPairChallengeView`

**Files:** `NewChallengeSheet.swift`, `CreateOpenChallengeView.swift`, `CreateCoopPairChallengeView.swift`.

`NewChallengeSheet`: two large buttons — "Open Challenge" / "Co-op Pair" — each pushes the corresponding creator.

`CreateOpenChallengeView`:
- Title text field (3–60 chars)
- Optional due date picker (default: end of week Sunday 11:59pm)
- "Post to crew" button → calls `OpenChallengeService.create` then dismisses

`CreateCoopPairChallengeView`:
- Partner picker — list of squad roster (excludes current user)
- Target sessions stepper (1–14, default 4)
- Window selector with two presets ("This week Mon–Sun" / "Custom") — Custom shows two date pickers
- "Send invite" button → calls `CoopPairChallengeService.invite` then dismisses

**Acceptance:** SwiftUI preview + simulator interaction. Validation: empty title disabled; target < 1 disabled.

**Commit:** `feat(squads-v1): challenge create flows`

### Task P3.7 — `OpenChallengeCard` + `SubmitScoreSheet`

**Files:** `OpenChallengeCard.swift`, `SubmitScoreSheet.swift`.

`OpenChallengeCard` (props: `OpenChallenge`, `[OpenChallengeJoiner]`, `currentUserId`):
- Title, "by {creator}", optional due date
- Joiner list:
  - If submitted → name + score, highlight if winner (status `.closed`)
  - If joined but not submitted → name + "—"
  - If not joined → omit
- Action: if status `.open` AND current user is in the squad:
  - If not joined → `[Join]` button → calls `OpenChallengeService.join`
  - If joined but no score → `[Submit Score]` → opens `SubmitScoreSheet`
  - If joined with score → "Submitted ✓"
- Winner banner if status `.closed`

`SubmitScoreSheet`:
- One numeric field
- "Submit" → calls `submitScore`, dismisses

**Acceptance:** Preview each state (open + me-not-joined, open + me-joined-no-score, open + me-submitted, closed-with-winner). Simulator interaction works.

**Commit:** `feat(squads-v1): OpenChallengeCard + score submission UI`

### Task P3.8 — `CoopPairChallengeCard`

**File:** `CoopPairChallengeCard.swift`.

Props: `CoopPairChallenge`, `creatorMember: SquadMember`, `partnerMember: SquadMember`, `currentUserId: UUID`.

States:
- `.pending` + current user == partner: card with `[Accept] [Decline]` buttons
- `.pending` + current user == creator: "Waiting on {partnerName}" + Cancel
- `.active`: two progress bars (creator + partner), `N/target each`, days remaining
- `.cleared`: green border, "Cleared!" badge, XP line "+50 each"
- `.missed`: gray, "Window closed — N/target each", Rematch CTA → opens `CreateCoopPairChallengeView` pre-filled with same params
- `.declined` / `.canceled`: minimal "Declined" / "Canceled" line

**Acceptance:** Preview each state. Tapping Accept transitions in simulator.

**Commit:** `feat(squads-v1): CoopPairChallengeCard with full state coverage`

### Task P3.9 — Replace `ChallengeEventBubble` stub

**File:** Modify `UNBOUND/Views/Squads/Chat/ChallengeEventBubble.swift`.

Now: read `payload.challengeKind` + `payload.challengeId`, look up the underlying challenge from the appropriate service (use a lightweight `ChallengeLookupStore` that caches by id), and render `OpenChallengeCard` or `CoopPairChallengeCard` accordingly. Fallback to plain `body` text if the challenge can't be found.

**Acceptance:** Open chat with active challenges → cards render in full fidelity.

**Commit:** `feat(chat): rich challenge cards in chat`

### Task P3.10 — Populate `SquadChallengesSection`

**File:** Modify `UNBOUND/Views/Squads/SquadChallengesSection.swift`.

Replace stub with:
- Fetch active CoopPair + Open challenges for current user via the two services
- Render a compact 1-line summary per challenge (title + state badge + tap → opens chat scrolled to that card)
- `[+ New]` button → opens `NewChallengeSheet`

**Acceptance:** Active challenges show on squad page; tapping one opens chat at the right card.

**Commit:** `feat(squads-v1): SquadChallengesSection with active challenges + create entry`

### Task P3.11 — Hook progress recompute into auto-poster

**File:** Modify `SquadMessageAutoPoster.swift`.

In the `.workoutCompleted` handler, BEFORE posting the workout message, call `services.coopPair.recomputeProgress(workoutCompletedAt:, userId:)`. The service emits its own `.progressUpdate` or `.cleared` event card if status changes — those auto-emit via the service's own listener path.

For Open challenges, no progress recompute needed (score is manual).

**Acceptance:** Workout completed → both workout card AND any triggered progress/clear card appear in chat in order.

**Commit:** `feat(squads-v1): recompute coop-pair progress on workout completion`

### Task P3.12 — UI walkthrough test

**File:** `ChallengeWalkthroughTests.swift` (UITests).

Scenario A — Co-op pair:
1. User A invites User B to "4 sessions this week" via simulator on two seeded accounts.
2. B accepts.
3. A logs 4 workouts via seed helper.
4. B logs 4 workouts.
5. Open chat → `.cleared` card visible.
6. Verify A's XP wallet incremented by 50.

Scenario B — Open challenge:
1. A creates "Most pushups in 60s" with due 5 min from now.
2. B joins, submits 32. A submits 28.
3. Wait for due, trigger `closeIfDue`.
4. Closed card lists B as winner. B has +35 XP, A has +10 XP.

**Acceptance:** Both scenarios green.

**Commit:** `test(challenges): co-op pair + open challenge walkthroughs`

---

## Verification (end of phase)

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/OpenChallengeServiceTests \
  -only-testing:UNBOUNDTests/Services/CoopPairChallengeServiceTests \
  -only-testing:UNBOUNDTests/Services/ChallengeXPAwarderTests \
  -only-testing:UNBOUNDUITests/ChallengeWalkthroughTests
```

All green = Phase 3 done. Hand off to Phase 4 (Badges + Share + Profile).
