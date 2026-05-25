# Squads v1 — Phase 2: Chat Surface + Reactions + Auto-Post

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`docs/superpowers/specs/2026-05-24-squads-v1-redesign-design.md`](../specs/2026-05-24-squads-v1-redesign-design.md). Phase 1 ([`2026-05-24-squads-v1-spine-phase-1.md`](2026-05-24-squads-v1-spine-phase-1.md)) must be landed first — this phase depends on `SquadMessage`, `SquadMessageStore`, and the new `SquadDetailView`.

**Goal:** Ship the full-screen chat surface (`SquadChatView`), the reaction system, and the auto-post pipeline that turns logged workouts / PRs / vow seals into `SquadMessage` rows. After this phase, opening a squad's chat shows a live, polymorphic thread that updates in real time, and members can react / reply.

**Architecture:** `SquadChatView` is presented modally (full-screen cover) from `SquadHeaderCard`. It subscribes to `SquadMessageStore` for live updates. Message rendering is dispatched by `SquadMessagePayload` kind — text gets a bubble, workout/PR/vowSeal/savedWorkoutShare get card-style bubbles. The auto-post pipeline is a single `SquadMessageAutoPoster` service that observes existing app events (workout completion, PR awarded, vow seal) and converts them into `SquadMessage` inserts via the store. Block + report = local block list (UserDefaults) + report endpoint (Supabase function) — Apple-compliant minimal surface.

**Tech stack:** SwiftUI, Combine, Supabase Realtime, APNs (existing push setup). XCTest.

---

## Scope

In:
- `SquadChatView` (full-screen cover with compose bar)
- Message bubble renderers per payload kind: text, workout, PR, vow seal, system
  *(challengeEvent + savedWorkoutShare renderers stub for now — Phase 3 and 4 fill them)*
- Reaction system: `SquadMessageReaction` model + store, tap-to-react UI (fixed 5-emoji set: 🔥 💪 👏 ❤️ 👀)
- Auto-post pipeline (`SquadMessageAutoPoster`) wiring to existing workout-completion / PR / vow-seal events
- Block + report: long-press menu, local block list, report → Supabase function
- Push notifications for: replies to your message, your auto-posted card got 3+ reactions
- Wire `[💬 Open Chat]` from Phase 1 to actually navigate

Out:
- Challenge cards (rendered in Phase 3)
- Saved Workout share card (rendered in Phase 4)
- Edit/delete messages, media uploads, mentions, typing indicators, read receipts (explicit YAGNI in spec)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/SquadMessageReaction.swift` | **Create** | `id, messageId, userId, emoji, createdAt`. Codable. |
| `UNBOUND/Services/Squads/SquadReactionBackendProtocol.swift` | **Create** | `toggle(messageId, userId, emoji)`, `fetchFor(messageIds:)`, `subscribe(squadId:)` |
| `UNBOUND/Services/Squads/SquadReactionBackend.swift` | **Create** | Production Supabase impl. Toggle = insert-or-delete by `(message_id, user_id, emoji)`. |
| `UNBOUND/Services/Squads/MockSquadReactionBackend.swift` | **Create** | In-memory toggle store. |
| `UNBOUND/Services/Squads/SquadReactionStore.swift` | **Create** | `@Published reactionsByMessage: [UUID: [SquadMessageReaction]]`. Subscribes per squad. |
| `UNBOUND/Services/Squads/SquadMessageAutoPoster.swift` | **Create** | Listens to existing `Notification.Name`s (workoutCompleted, prAwarded, vowSealed) → posts `SquadMessage` for the user's current squad. |
| `UNBOUND/Services/Squads/SquadBlockListStore.swift` | **Create** | UserDefaults-backed `Set<UUID>` of blocked-user IDs per logged-in user. |
| `UNBOUND/Services/Squads/SquadReportClient.swift` | **Create** | POSTs `{messageId, reason, reporterId}` to Supabase Edge Function `report-squad-message`. |
| `UNBOUND/Views/Squads/SquadChatView.swift` | **Create** | Full-screen cover. ScrollView of bubbles, compose bar at bottom, kept scrolled to last on send. |
| `UNBOUND/Views/Squads/Chat/MessageBubble.swift` | **Create** | Dispatches to per-kind subviews. |
| `UNBOUND/Views/Squads/Chat/TextBubble.swift` | **Create** | Text bubble with avatar + name + body + reaction row. |
| `UNBOUND/Views/Squads/Chat/WorkoutBubble.swift` | **Create** | Card-style bubble: title + duration + RPE. Tap → opens read-only `WorkoutDetailView`. |
| `UNBOUND/Views/Squads/Chat/PRBubble.swift` | **Create** | Card with yellow left-border + sparkle icon + summary. |
| `UNBOUND/Views/Squads/Chat/VowSealBubble.swift` | **Create** | Card with accent border + vow name. |
| `UNBOUND/Views/Squads/Chat/SystemBubble.swift` | **Create** | Centered, low-contrast: "🧰 Squads got an update…". |
| `UNBOUND/Views/Squads/Chat/ChallengeEventBubble.swift` | **Create (stub)** | Renders `body` plain — Phase 3 replaces with rich card. |
| `UNBOUND/Views/Squads/Chat/SavedWorkoutShareBubble.swift` | **Create (stub)** | Renders title + "Add to library" disabled — Phase 4 enables. |
| `UNBOUND/Views/Squads/Chat/ReactionRow.swift` | **Create** | Shows aggregated counts (`🔥 3 · 💪 2`). Tap a reaction → toggle. Tap "+" → emoji picker (popover of the fixed 5). |
| `UNBOUND/Views/Squads/Chat/ComposeBar.swift` | **Create** | TextField + send button. 280-char limit. Send creates a `.text` `SquadMessage`. |
| `UNBOUND/Views/Squads/Chat/MessageContextMenu.swift` | **Create** | Long-press menu: Copy, Report, Block sender (only if not the user's own message). |
| `UNBOUND/Views/Squads/SquadHeaderCard.swift` | **Modify** | Wire `[💬 Open Chat]` to present `SquadChatView` as `.fullScreenCover`. |
| `UNBOUND/Views/Squads/SquadRecentStrip.swift` | **Modify** | Replace stub with last 3 message titles, "See all →" opens chat. |
| `UNBOUND/Services/ServiceContainer.swift` | **Modify** | Add `squadReactions: SquadReactionStore`, `squadBlockList: SquadBlockListStore`, `squadAutoPoster: SquadMessageAutoPoster`. Start auto-poster in app launch. |
| `UNBOUND/App/AniBodyApp.swift` (or equivalent root) | **Modify** | Call `services.squadAutoPoster.start()` once at launch. Register push notification handlers for the two new notification kinds. |
| `db/migrations/20260524_squad_message.sql` | **(already created in P1)** | Reactions table already exists; nothing to add. |
| `supabase/functions/report-squad-message/index.ts` | **Create** | Edge function: validates auth, inserts into `squad_message_report` table for moderator review. |
| `db/migrations/20260524_squad_message_report.sql` | **Create** | `squad_message_report (id, message_id, reporter_user_id, reason, created_at)`. |
| `UNBOUND/UNBOUNDTests/Services/SquadReactionStoreTests.swift` | **Create** | Toggle on / off; idempotency; subscribe emits |
| `UNBOUND/UNBOUNDTests/Services/SquadMessageAutoPosterTests.swift` | **Create** | Workout completed → message posted; PR awarded → message posted; not in a squad → no-op |
| `UNBOUND/UNBOUNDTests/Services/SquadBlockListStoreTests.swift` | **Create** | Block adds id; isBlocked filters subsequent messages |
| `UNBOUND/UNBOUNDUITests/SquadChatWalkthroughTests.swift` | **Create** | Open chat → send text → message appears → tap reaction → count increments |

---

## Tasks

### Task P2.1 — `SquadMessageReaction` model + backend protocol + mock

**Files:** `SquadMessageReaction.swift`, `SquadReactionBackendProtocol.swift`, `MockSquadReactionBackend.swift`.

```swift
struct SquadMessageReaction: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let messageId: UUID
    let userId: UUID
    let emoji: String      // one of: "🔥", "💪", "👏", "❤️", "👀"
    let createdAt: Date
}

protocol SquadReactionBackendProtocol: Sendable {
    /// Returns true if a reaction was added, false if it was removed.
    func toggle(messageId: UUID, userId: UUID, emoji: String) async throws -> Bool
    func fetchFor(messageIds: [UUID]) async throws -> [SquadMessageReaction]
    func subscribe(squadId: UUID) -> AsyncStream<SquadMessageReaction>
}

enum SquadReactionEmoji {
    static let allowed: [String] = ["🔥", "💪", "👏", "❤️", "👀"]
}
```

Mock: in-memory `Set<Hashable triple>`; toggle inserts or removes; subscribe wired same as `MockSquadMessageBackend`.

**Acceptance:** `SquadReactionStoreTests` covers toggle round-trip with the mock.

**Commit:** `feat(squads-v1): SquadMessageReaction model + mock backend`

### Task P2.2 — Production `SquadReactionBackend`

**File:** Create `SquadReactionBackend.swift`.

Toggle implementation: `SELECT` by composite key → if exists, `DELETE` → return false. If not, `INSERT` → return true. Wrap both in a single Postgrest call sequence; idempotency relies on the unique constraint added in Phase 1's DDL.

Subscribe: Realtime channel filtered on `squad_message_reaction` where `message_id IN (SELECT id FROM squad_message WHERE squad_id = X)`. If filtering by joined table isn't supported by the Realtime client at the time of impl, subscribe to all reactions and filter client-side using `SquadMessageStore.messagesBySquad`.

**Acceptance:** Manual smoke (two devices) shows reaction propagation.

**Commit:** `feat(squads-v1): production SquadReactionBackend`

### Task P2.3 — `SquadReactionStore`

**File:** Create `SquadReactionStore.swift`.

Mirrors `SquadMessageStore` shape:

```swift
@MainActor
final class SquadReactionStore: ObservableObject {
    @Published private(set) var reactionsByMessage: [UUID: [SquadMessageReaction]] = [:]
    private let backend: SquadReactionBackendProtocol
    private var subscriptions: [UUID: Task<Void, Never>] = [:]

    func loadFor(messageIds: [UUID]) async { ... }
    func subscribe(squadId: UUID) { ... }
    func toggle(messageId: UUID, emoji: String, userId: UUID) async { ... } // optimistic
    func reactions(for messageId: UUID) -> [SquadMessageReaction] { ... }
    func aggregated(for messageId: UUID) -> [String: Int] { ... } // emoji -> count
}
```

**Acceptance:** `SquadReactionStoreTests` — toggle reflects in `aggregated`; double-toggle returns to baseline; subscribe receives external toggles.

**Commit:** `feat(squads-v1): SquadReactionStore`

### Task P2.4 — `SquadBlockListStore` + `SquadReportClient`

**Files:** `SquadBlockListStore.swift`, `SquadReportClient.swift`.

Block list: UserDefaults-backed set per logged-in user. Keys: `squadBlockList.<currentUserId>`. Stored as a JSON-encoded `[String]` of UUIDs.

```swift
@MainActor
final class SquadBlockListStore: ObservableObject {
    @Published private(set) var blockedUserIds: Set<UUID> = []
    func load(currentUserId: UUID)
    func block(_ userId: UUID)
    func unblock(_ userId: UUID)
    func isBlocked(_ userId: UUID) -> Bool
}
```

Report client posts to a Supabase Edge Function (`report-squad-message`) — function inserts into `squad_message_report` (separate DDL, Task P2.10).

**Acceptance:** `SquadBlockListStoreTests` round-trip. Manual: report sends an entry to the table.

**Commit:** `feat(squads-v1): block list + report client`

### Task P2.5 — `SquadMessageAutoPoster`

**File:** Create `SquadMessageAutoPoster.swift`.

```swift
@MainActor
final class SquadMessageAutoPoster {
    private let messages: SquadMessageStore
    private let squads: SquadServiceProtocol
    private var observers: [NSObjectProtocol] = []

    init(messages: SquadMessageStore, squads: SquadServiceProtocol) { ... }

    func start() {
        observe(.workoutCompleted) { [weak self] note in
            await self?.handleWorkoutCompleted(note)
        }
        observe(.prAwarded) { ... }
        observe(.vowSealed) { ... }
    }
}
```

Behavior per event:
- `.workoutCompleted` (payload: `Workout` with `id, title, durationMin, rpe?`): if current user is in a squad, insert a `SquadMessage(kind: .workout, payload: .workout(...))` for that squad.
- `.prAwarded` (payload: `{workoutId, exerciseName, summary}`): insert `.pr`.
- `.vowSealed` (payload: vow name): insert `.vowSeal`.

If the existing notifications carry different payloads, do a one-line bridge in the handler — don't refactor the event publishers. If the events don't exist yet, identify the call sites that DO complete workouts / award PRs / seal vows and post the notification there (one-line `NotificationCenter.default.post`) as part of this task.

**Acceptance:** `SquadMessageAutoPosterTests` — emit a workout-completion notification with mocks → message lands in `SquadMessageStore`. No squad → no-op (no crash).

**Commit:** `feat(squads-v1): SquadMessageAutoPoster`

### Task P2.6 — Bubble views

**Files:** `MessageBubble.swift`, `TextBubble.swift`, `WorkoutBubble.swift`, `PRBubble.swift`, `VowSealBubble.swift`, `SystemBubble.swift`, `ChallengeEventBubble.swift` (stub), `SavedWorkoutShareBubble.swift` (stub).

`MessageBubble` switches on `message.payload`:

```swift
struct MessageBubble: View {
    let message: SquadMessage
    let author: SquadMember?      // resolved by parent
    let reactions: [String: Int]  // emoji -> count
    let onToggleReaction: (String) -> Void
    let onLongPress: () -> Void

    var body: some View {
        switch message.payload {
        case .text(let body):                  TextBubble(...)
        case .workout(let id, let t, let d, let r): WorkoutBubble(...)
        case .pr(_, let exercise, let summary):    PRBubble(...)
        case .vowSeal(let name):               VowSealBubble(...)
        case .savedWorkoutShare(let id, let t): SavedWorkoutShareBubble(...)
        case .challengeEvent(_, _, let body):  ChallengeEventBubble(text: body)
        case .system(let body):                SystemBubble(body: body)
        }
    }
}
```

Each subview is small and self-contained. Reaction row appears under every non-system bubble. Long-press triggers `onLongPress` (parent shows `MessageContextMenu`).

**Acceptance:** SwiftUI previews for each kind. Screenshot diffs not required, just visual sanity.

**Commit:** `feat(chat): bubble views per payload kind`

### Task P2.7 — `ReactionRow` + `ComposeBar` + `MessageContextMenu`

**Files:** `ReactionRow.swift`, `ComposeBar.swift`, `MessageContextMenu.swift`.

`ReactionRow`:
```swift
struct ReactionRow: View {
    let aggregated: [String: Int]   // emoji -> count
    let myReactions: Set<String>    // which I've toggled on
    let onToggle: (String) -> Void
}
```
- Shows existing reactions as small pills (highlighted if I toggled).
- Shows a `+` button that opens a popover/menu with the 5 allowed emojis.

`ComposeBar`:
```swift
struct ComposeBar: View {
    @Binding var text: String
    let onSend: (String) -> Void
}
```
- TextField with rounded background, send button.
- Character cap = 280; over → button disabled + small counter (`263/280`) appears.
- Send clears the field and calls `onSend(trimmed)`.

`MessageContextMenu`:
- Copy (always)
- Report message (always — opens a tiny sheet with a free-text reason field; submits via `SquadReportClient`)
- Block sender (only if message is not from the current user)

**Acceptance:** Previews + tap-test in simulator. Character cap enforced.

**Commit:** `feat(chat): ReactionRow, ComposeBar, MessageContextMenu`

### Task P2.8 — `SquadChatView`

**File:** Create `SquadChatView.swift`.

```swift
struct SquadChatView: View {
    let squadId: UUID
    @EnvironmentObject var services: ServiceContainer
    @State private var composeText = ""
    @State private var blockTarget: UUID?
    @State private var reportTarget: SquadMessage?

    var body: some View {
        VStack(spacing: 0) {
            chatHeader      // back button + squad name + presence summary
            ScrollViewReader { proxy in
                ScrollView { ... }
                .onChange(of: messages.last?.id) { proxy.scrollTo($0, anchor: .bottom) }
            }
            ComposeBar(text: $composeText, onSend: send)
        }
        .fullScreenCover(item: $reportTarget) { ReportSheet(message: $0) }
        .task {
            await services.squadMessages.load(squadId: squadId)
            services.squadMessages.subscribe(squadId: squadId)
            services.squadReactions.subscribe(squadId: squadId)
            let ids = services.squadMessages.messages(for: squadId).map(\.id)
            await services.squadReactions.loadFor(messageIds: ids)
        }
    }

    private var messages: [SquadMessage] {
        let blocked = services.squadBlockList.blockedUserIds
        return services.squadMessages.messages(for: squadId)
            .filter { msg in
                guard let author = msg.authorUserId else { return true }
                return !blocked.contains(author)
            }
    }
}
```

Date dividers: insert a `— MONDAY —` style header whenever the previous message's day differs from the current.

**Acceptance:** Open from header `[💬 Open Chat]`, send a message, see it appear, react to it, count increments. Block a user, their messages disappear.

**Commit:** `feat(chat): SquadChatView full-screen surface`

### Task P2.9 — Wire `[💬 Open Chat]` + populate `SquadRecentStrip`

**Files:** Modify `SquadHeaderCard.swift`, `SquadRecentStrip.swift`, `SquadDetailView.swift`.

`SquadHeaderCard.openChat` now opens `SquadChatView` via `.fullScreenCover` declared in `SquadDetailView`.

`SquadRecentStrip` reads the last 3 messages from `SquadMessageStore.messages(for: squadId)` (filter out `.text` if you want it punchier — recommend keeping all kinds for now), renders one-liner summaries:
```swift
switch m.payload {
case .text(let body): "💬 \(authorName): \(body.prefix(40))"
case .workout(_, let title, _, _): "💪 \(authorName) trained \(title)"
case .pr(_, let exercise, let summary): "✨ \(authorName) PR'd \(exercise) — \(summary)"
case .vowSeal(let name): "🔮 \(authorName) sealed \(name)"
case .savedWorkoutShare(_, let title): "📋 \(authorName) shared \(title)"
case .challengeEvent(_, _, let body): "🤝 \(body)"
case .system(let body): "🧰 \(body)"
}
```

"See all →" button → presents chat.

**Acceptance:** Sending a message in chat updates the recent strip on the squad page when you dismiss the chat.

**Commit:** `feat(squads-v1): wire chat surface + recent strip`

### Task P2.10 — Report DDL + Edge Function

**Files:** `db/migrations/20260524_squad_message_report.sql`, `supabase/functions/report-squad-message/index.ts`.

```sql
create table if not exists public.squad_message_report (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.squad_message(id) on delete cascade,
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now()
);
```

Edge function (TypeScript):
- Verify auth (Supabase JWT)
- Validate body `{ messageId: uuid, reason?: string }`
- Insert into `squad_message_report`
- Return `{ ok: true }`

**Acceptance:** Manual: tap Report from chat → row lands in the table.

**Commit:** `feat(squads-v1): report-squad-message endpoint + DDL`

### Task P2.11 — Push notifications (2 kinds)

**Files:** Modify `AniBodyApp.swift` (or push-handler equivalent), add a `SquadPushPayload.swift` for parsing.

Two push notification kinds delivered by the existing push infra (assumed to be Supabase function or APNs server-side):
1. **Reply to your message**: if anyone posts a `.text` message within 60s of your `.text` message AND it's authored by someone else, send you a push: `"<Author> replied in <Squad name>: <preview>"`. Server-side logic — implement as a Supabase Postgres function or trigger.
2. **Your card got 3+ reactions**: when reaction count on a message you authored crosses the 3-mark, send: `"🔥 Your <kind> card has 3 reactions in <Squad name>"`. Same — DB trigger.

Client-side: register the two `Notification.Name`s and route push opens to `SquadChatView` for the relevant squad.

**Acceptance:** Push received → tapping opens to chat.

**Commit:** `feat(squads-v1): push notifications for replies + reaction-milestone`

### Task P2.12 — UI walkthrough test

**File:** Create `SquadChatWalkthroughTests.swift` (UITests).

Scenario:
1. Launch with seeded squad of 4 members.
2. Open Squad tab → tap `[💬 Open Chat]`.
3. Verify migration notice system card is visible.
4. Type "hello crew" → tap send → message appears at bottom.
5. Tap 🔥 reaction on a workout card → count becomes 1.
6. Long-press own message → Copy + Report visible; Block NOT visible.
7. Long-press another user's message → Block visible.
8. Tap Block → message disappears, chat refreshes.

**Acceptance:** All 8 steps pass on simulator.

**Commit:** `test(chat): SquadChatWalkthroughTests`

---

## Verification (end of phase)

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/SquadReactionStoreTests \
  -only-testing:UNBOUNDTests/Services/SquadMessageAutoPosterTests \
  -only-testing:UNBOUNDTests/Services/SquadBlockListStoreTests \
  -only-testing:UNBOUNDUITests/SquadChatWalkthroughTests
```

All green = Phase 2 done. Hand off to Phase 3 (Challenges).

Manual sanity check:
1. Two devices in same squad → workout completion on device A surfaces as a card on device B in <2s.
2. Reaction toggled on A propagates to B.
3. Block a member on A → their card disappears on A only.
