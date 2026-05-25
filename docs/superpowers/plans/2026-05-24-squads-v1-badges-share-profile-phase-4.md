# Squads v1 — Phase 4: Badges + Share Saved Workout + Lightweight Profile

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`docs/superpowers/specs/2026-05-24-squads-v1-redesign-design.md`](../specs/2026-05-24-squads-v1-redesign-design.md). Phases 1–3 must be landed: badges hook into `CoopPairChallengeService.cleared` events, share workout posts a `.savedWorkoutShare` card into the existing chat surface, profile reads from existing services.

**Goal:** Ship the two tiered badges (Accountability — personal; Crew Streak — squad-wide), the Share-Saved-Workout flow, and the lightweight crewmate profile. Replaces the existing `SquadMemberDetailView` with a slimmer card aligned to spec. Closes out the v1 redesign.

**Architecture:** Both badges are derived state — Accountability counter is incremented on every challenge clear (Open win OR Co-op pair clear), Crew Streak counter is a weekly Cron job that runs Sunday 11:59pm checking each member's session count. Tier crossings emit `SquadMessage(.system)` cards. Share Saved Workout is a new sheet from `SavedWorkoutsListView` (built in the program redesign) that resolves a recipient (crewmate or `.broadcast`) and inserts a `.savedWorkoutShare` SquadMessage. Profile is a refactor of `SquadMemberDetailView` — narrower scope, no badges shelf, no with-you record.

**Tech stack:** Swift, SwiftUI, Supabase Postgrest, Supabase Cron (pg_cron), XCTest.

---

## Scope

In:
- `AccountabilityBadgeState` model + service (per-user, tier I/II/III at 1/5/25 clears)
- `CrewStreakBadgeState` model + service (per-squad, tier I/II/III at 5/12/26 consecutive weeks)
- Weekly streak evaluator (server-side via pg_cron)
- Badge UI: Accountability on profile + roster tile; Crew Streak in the dedicated slab (replaces P1 stub)
- Tier-earned auto-post to chat (`.system` message)
- Share Saved Workout flow (sheet, recipient picker, send)
- `SavedWorkoutShareBubble` upgrade — `[Add to my library]` enabled, copies workout into recipient's library
- Lightweight `SquadMemberDetailView` refactor

Out:
- Named cosmetic badge catalog beyond these two (YAGNI)
- "With-you" joint history on profile (YAGNI)
- XP → level progression (YAGNI)
- Manual badge management (no settings UI for badges)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/AccountabilityBadgeState.swift` | **Create** | `userId, clearedCount, currentTier`. Tier enum `.none, .I, .II, .III`. |
| `UNBOUND/Models/CrewStreakBadgeState.swift` | **Create** | `squadId, consecutiveWeeks, currentTier, weekIsoLast`. Tier as above. |
| `UNBOUND/Services/Squads/AccountabilityBadgeServiceProtocol.swift` | **Create** | `incrementOnClear(userId:)`, `state(userId:)`, `subscribe(userId:)` |
| `UNBOUND/Services/Squads/AccountabilityBadgeService.swift` | **Create** | Postgrest impl. On increment, computes new tier; if tier crossed → emits `Notification.Name.accountabilityTierEarned`. |
| `UNBOUND/Services/Squads/CrewStreakBadgeServiceProtocol.swift` | **Create** | `state(squadId:)`, `evaluateWeek(squadId:weekIso:)` (test seam), `subscribe(squadId:)` |
| `UNBOUND/Services/Squads/CrewStreakBadgeService.swift` | **Create** | Reads + writes the badge state row; `evaluateWeek` checks each member trained ≥1 session in the given Mon–Sun; updates `consecutiveWeeks` and tier; if tier crossed → emits `Notification.Name.crewStreakTierEarned`. New members mid-week are excluded from that week's check. |
| `UNBOUND/Services/Squads/ServiceContainer.swift` | **Modify** | Wire both badge services. |
| `UNBOUND/Services/Squads/ChallengeXPAwarder.swift` | **Modify** | After awarding XP on a challenge clear, also call `accountabilityBadgeService.incrementOnClear(userId:)`. For Open challenge: only the winner gets +1 (matches spec). For Co-op pair: both get +1. |
| `UNBOUND/Services/Squads/SquadMessageAutoPoster.swift` | **Modify** | Add observers for `.accountabilityTierEarned` and `.crewStreakTierEarned` → post `.system` card to the squad: "🏷️ <Name> earned Accountability II (5 challenges cleared)" / "🔥 Your crew hit Crew Streak II — 12 weeks together!". |
| `UNBOUND/Views/Squads/Badges/AccountabilityBadgeView.swift` | **Create** | Small icon + tier roman numeral + progress bar to next tier. Used in profile + roster tile. |
| `UNBOUND/Views/Squads/Badges/CrewStreakBadgeView.swift` | **Create** | Larger card: tier icon, current streak, weeks-to-next. Used in `SquadCrewStreakBadgeSlot`. |
| `UNBOUND/Views/Squads/SquadCrewStreakBadgeSlot.swift` | **Modify (replace stub)** | Use `CrewStreakBadgeView`. |
| `UNBOUND/Views/Squads/SquadCrewGrid.swift` | **Modify** | Each tile renders a tiny `AccountabilityBadgeView` (icon + tier, no progress bar) if user has earned at least tier I. |
| `UNBOUND/Views/Squads/SquadMemberDetailView.swift` | **Rewrite (lightweight)** | New layout: profile pic, name, equipped title, build hex (existing), this-week session count, last 3 workouts (titles only — tap → existing `WorkoutDetailView`), `AccountabilityBadgeView` (with progress bar), "Currently in:" list (active challenges for that user). Remove: badges shelf, sealed-vows shelf, with-you record (none of these exist in v1). |
| `UNBOUND/Views/Squads/Chat/SavedWorkoutShareBubble.swift` | **Modify (replace stub)** | Real card: title + "Shared by {sender}". `[Add to my library]` calls `SavedWorkoutStore.save` on the recipient's device — see Task P4.6 for cloning logic. |
| `UNBOUND/Views/Program/SavedWorkoutsListView.swift` | **Modify** | Add a `[Share]` action per row. Opens `ShareSavedWorkoutSheet`. |
| `UNBOUND/Views/Squads/ShareSavedWorkoutSheet.swift` | **Create** | Recipient picker: list of crewmates + a "Broadcast to crew chat" option. Send → posts `.savedWorkoutShare` SquadMessage. |
| `db/migrations/20260608_squad_badges.sql` | **Create** | `accountability_badge_state` + `crew_streak_badge_state` tables + pg_cron job for weekly evaluation. |
| `supabase/functions/evaluate-crew-streak-weekly/index.ts` | **Create** | Sunday 23:55 UTC cron entry-point. Iterates all squads, calls evaluation logic, writes state. |
| `UNBOUND/UNBOUNDTests/Services/AccountabilityBadgeServiceTests.swift` | **Create** | Increment from 0 → tier I auto-earned; 5th increment → tier II; 25th → tier III; tier-earned notification fires exactly once per crossing |
| `UNBOUND/UNBOUNDTests/Services/CrewStreakBadgeServiceTests.swift` | **Create** | 5 consecutive weeks → tier I; 1 member misses → reset to 0; new-mid-week member doesn't break streak |
| `UNBOUND/UNBOUNDTests/Services/ShareSavedWorkoutTests.swift` | **Create** | Share → recipient's library contains a clone; original unchanged |
| `UNBOUND/UNBOUNDUITests/BadgeAndShareWalkthroughTests.swift` | **Create** | Clear 1 challenge → accountability badge tier I appears on profile + roster tile; share a workout → card in chat → recipient adds to library |

---

## Tasks

### Task P4.1 — DDL + pg_cron for badges

**File:** `db/migrations/20260608_squad_badges.sql`.

```sql
create table if not exists public.accountability_badge_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  cleared_count int not null default 0,
  current_tier text not null default 'none'  -- 'none','I','II','III'
);

create table if not exists public.crew_streak_badge_state (
  squad_id uuid primary key references public.squad(id) on delete cascade,
  consecutive_weeks int not null default 0,
  current_tier text not null default 'none',
  week_iso_last text                          -- 'YYYY-Wnn' of the last evaluated week
);

alter publication supabase_realtime add table public.accountability_badge_state;
alter publication supabase_realtime add table public.crew_streak_badge_state;

-- pg_cron: every Sunday 23:55 UTC, call the edge function
select cron.schedule(
  'evaluate-crew-streak-weekly',
  '55 23 * * 0',
  $$ select net.http_post(
       url := 'https://<project-ref>.functions.supabase.co/evaluate-crew-streak-weekly',
       headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.cron_secret'))
     ) $$
);
```

**Acceptance:** Migration runs. `select * from cron.job` shows the entry. (Replace `<project-ref>` with real ref.)

**Commit:** `db(squads-v1): badge state tables + weekly streak cron`

### Task P4.2 — `AccountabilityBadgeService`

**Files:** `AccountabilityBadgeState.swift`, `AccountabilityBadgeServiceProtocol.swift`, `AccountabilityBadgeService.swift`, mock.

```swift
struct AccountabilityBadgeState: Codable, Equatable, Sendable {
    enum Tier: String, Codable, Sendable { case none, I, II, III }
    let userId: UUID
    var clearedCount: Int
    var currentTier: Tier
}

extension AccountabilityBadgeState.Tier {
    static func tier(forClearedCount n: Int) -> Self {
        switch n {
        case 25...: return .III
        case 5..<25: return .II
        case 1..<5: return .I
        default: return .none
        }
    }
    var progressToNext: (current: Int, target: Int)? {
        // Returns nil if at III (terminal)
    }
}
```

`incrementOnClear(userId:)`:
- Upsert + atomic `clearedCount = clearedCount + 1` (use a Postgres RPC or `RETURNING` clause)
- Recompute tier from new count
- If new tier > old tier → emit `Notification.Name.accountabilityTierEarned` with `(userId, newTier)` payload

**Acceptance:** `AccountabilityBadgeServiceTests`:
- Start 0 → increment → tier I, notification fires
- 4 → 5th increment → tier II, notification fires
- 5 → 6th increment → still tier II, notification does NOT fire (only on crossings)
- 24 → 25 → tier III, notification fires
- 25 → 26 → still tier III, no notification

**Commit:** `feat(squads-v1): AccountabilityBadgeService`

### Task P4.3 — `CrewStreakBadgeService`

**Files:** `CrewStreakBadgeState.swift`, protocol, service, mock.

```swift
struct CrewStreakBadgeState: Codable, Equatable, Sendable {
    enum Tier: String, Codable, Sendable { case none, I, II, III }
    let squadId: UUID
    var consecutiveWeeks: Int
    var currentTier: Tier
    var weekIsoLast: String?
}

extension CrewStreakBadgeState.Tier {
    static func tier(forWeeks w: Int) -> Self {
        switch w {
        case 26...: return .III
        case 12..<26: return .II
        case 5..<12: return .I
        default: return .none
        }
    }
}
```

`evaluateWeek(squadId:, weekIso:)`:
1. Resolve `weekStart` and `weekEnd` from `weekIso` (Mon 00:00 → Sun 23:59:59)
2. Fetch all squad members; exclude those who joined after `weekEnd - 4 days` (mid-week join rule from spec)
3. For each remaining member, count logged workouts where `completedAt` ∈ `[weekStart, weekEnd]`
4. If every member has ≥1 → `consecutiveWeeks += 1`; else `consecutiveWeeks = 0`
5. Recompute tier; if crossed → emit `Notification.Name.crewStreakTierEarned`
6. Persist state; idempotent on `weekIsoLast` (if `weekIsoLast == weekIso`, no-op)

**Acceptance:** `CrewStreakBadgeServiceTests`:
- 5 weeks all-trained → tier I, notification fires
- Week 6: one member misses → consecutiveWeeks resets to 0, tier reverts to .none, no notification (tier loss is silent)
- Member who joined Friday of week 3 doesn't break week 3's streak
- Repeat evaluation of same week is a no-op

**Commit:** `feat(squads-v1): CrewStreakBadgeService with mid-week-join handling`

### Task P4.4 — Weekly Edge Function

**File:** `supabase/functions/evaluate-crew-streak-weekly/index.ts`.

```ts
// Pseudocode
const weekIso = isoWeekOf(new Date()); // current week, Mon-based
const squads = await sb.from('squad').select('id');
for (const { id } of squads.data ?? []) {
  await sb.rpc('evaluate_crew_streak_for_squad', { p_squad_id: id, p_week_iso: weekIso });
}
```

Where `evaluate_crew_streak_for_squad` is a Postgres function that mirrors `CrewStreakBadgeService.evaluateWeek` server-side (so client-side service is for tests + read; truth lives server-side). Auth: function requires the service-role key from `current_setting('app.cron_secret')`.

**Acceptance:** Trigger function manually via `supabase functions invoke` → state rows update for all squads.

**Commit:** `feat(squads-v1): weekly crew-streak evaluation edge function`

### Task P4.5 — Badge UI

**Files:** `AccountabilityBadgeView.swift`, `CrewStreakBadgeView.swift`, modify `SquadCrewStreakBadgeSlot.swift`, modify `SquadCrewGrid.swift`.

`AccountabilityBadgeView` (props: `state`, `compact: Bool = false`):
- Compact (used in roster tile): just icon + roman numeral, no progress bar
- Full (used in profile): icon + tier name + small progress bar with `N / target` label (or "Maxed" if III)

`CrewStreakBadgeView` (props: `state`):
- Tier icon (flame, scaled to tier)
- Current streak in weeks
- Subtitle: "N weeks until <Tier>" or "Maxed" or "Start training together to begin a streak"

Roster tile update: render small `AccountabilityBadgeView(compact: true)` if `state.currentTier != .none`.

**Acceptance:** Previews for each tier state of each view. Roster tile renders badge for users who have earned one.

**Commit:** `feat(squads-v1): badge UI components`

### Task P4.6 — Share Saved Workout flow

**Files:** `ShareSavedWorkoutSheet.swift`, modify `SavedWorkoutsListView.swift`, modify `SavedWorkoutShareBubble.swift`.

`SavedWorkoutsListView`: add a `[Share]` button per row → presents `ShareSavedWorkoutSheet(savedWorkoutId:)`.

`ShareSavedWorkoutSheet`:
- Header: workout title
- Recipient picker — segmented control "To one crewmate" / "Broadcast to crew chat"
- If "To one crewmate", list of squad members (radio select)
- "Share" button → posts a `SquadMessage(.savedWorkoutShare)` to the user's current squad. Payload carries the `savedWorkoutId` and the workout's title (denormalized for chat rendering even if the workout is later deleted locally).

`SavedWorkoutShareBubble` upgrade:
- Renders the title + "Shared by {sender}"
- `[Add to my library]` action — looks up the `SavedWorkout` (this is where it gets interesting: the sender's local SavedWorkout is on their device only, since the program redesign chose JSON-on-disk per `SavedWorkoutStore`). For v1 cross-device share, we need a *side-channel* — either:
  - **Option A:** Include the full workout payload (blocks + targets + equipment) in the SquadMessage payload itself (denormalized). Recipient adds without any extra network call.
  - **Option B:** Upload the SavedWorkout to a `shared_workout` Supabase table when sharing; recipient fetches by id.

**Pick Option A** for v1 (simpler, no new table). Update `SquadMessagePayload.savedWorkoutShare` accordingly:

```swift
case savedWorkoutShare(savedWorkoutId: UUID, title: String, blocks: [WorkoutBlock], targets: WorkoutTargets, preferredEquipment: Set<Equipment>)
```

On `[Add to my library]`, build a new `SavedWorkout` (with a fresh UUID) from the payload, call `services.savedWorkouts.save(_:)`. Show a brief confirmation toast.

**Acceptance:** `ShareSavedWorkoutTests` — share from device A → recipient on device B sees card → tap Add → recipient's `SavedWorkoutStore.all()` contains the clone with a different UUID. Original sender unchanged.

**Commit:** `feat(squads-v1): Share Saved Workout end-to-end`

### Task P4.7 — Lightweight profile refactor

**File:** Rewrite `SquadMemberDetailView.swift`.

New layout (single ScrollView):
```
[Profile photo · 80pt circle]
{Display name}
{Equipped title}

[Build hex] — reuse existing AttributeProfile rendering

THIS WEEK
  N sessions

LAST 3 WORKOUTS
  (titles only; tap → WorkoutDetailView read-only)

ACCOUNTABILITY
  [AccountabilityBadgeView full]
  N / target_next cleared

CURRENTLY IN
  • Push Week with Kai (Co-op Pair · 3d left)
  • Pushups in 60s (Open · joined, no score yet)
```

Cut from the old `SquadMemberDetailView`: any reference to `SquadTitleBadge`, `SquadHonors`, `WeeklyHonor`, sealed-vow shelf, with-you record.

**Acceptance:** Open profile from chat author tap → renders all sections without crash. Empty states sensible.

**Commit:** `feat(squads-v1): lightweight crewmate profile`

### Task P4.8 — Wire tier-earned auto-posts

**File:** Modify `SquadMessageAutoPoster.swift`.

Add observers:
- `.accountabilityTierEarned(userId, tier)` → for the user's current squad, post a `.system` SquadMessage with body `"🏷️ <displayName> earned Accountability <tier>"`
- `.crewStreakTierEarned(squadId, tier)` → post a `.system` SquadMessage to that squad with body `"🔥 Your crew hit Crew Streak <tier> — <N> weeks together!"`

**Acceptance:** Manually trigger a tier crossing via test → corresponding `.system` card appears in chat.

**Commit:** `feat(squads-v1): tier-earned auto-posts`

### Task P4.9 — UI walkthrough test

**File:** `BadgeAndShareWalkthroughTests.swift`.

Scenario:
1. Seed 2 squad members, no badges.
2. User A wins one Open challenge.
3. Accountability tier I unlocks → assert badge view appears on A's profile + roster tile.
4. System card in chat: `"🏷️ A earned Accountability I"`.
5. User A opens Saved Workouts list → taps Share on "My Pull Routine" → picks User B.
6. Chat shows `.savedWorkoutShare` card; B taps `[Add to my library]`.
7. Switch to B's Saved Workouts list → "My Pull Routine" present with a different id from A's.

**Acceptance:** All 7 steps pass.

**Commit:** `test(squads-v1): badge + share walkthrough`

---

## Verification (end of phase)

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/AccountabilityBadgeServiceTests \
  -only-testing:UNBOUNDTests/Services/CrewStreakBadgeServiceTests \
  -only-testing:UNBOUNDTests/Services/ShareSavedWorkoutTests \
  -only-testing:UNBOUNDUITests/BadgeAndShareWalkthroughTests
```

All green = Phase 4 done = Squads v1 ships.

Manual sanity check on real device:
1. Clear a challenge → tier I badge appears on profile, system card in chat.
2. Share a workout to another device → recipient sees card → adds → workout is in their library.
3. Wait through a full week (or trigger the cron manually) → crew streak count updates.
