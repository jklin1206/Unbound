# Reward Celebration — Close All Gaps

> Closes the four gaps left after the initial RewardCelebrationView shipped against `QuickLogSheet`. Designed as four independent chunks; A & B can ship in parallel, C depends on both, D is independent. Each chunk lands behind a build-green review gate.

**Goal:** Every training event that earns the user something — set, session, PR, badge, rank — opens a celebration moment. No silent rewards, no missed dopamine.

**Status of foundation (already shipped):**
- `Models/RewardSummary.swift` — model with `xpGained`, `personalRecord`, `rankUp`, `badgeUnlocks`, `hasContent`, `deservesCinematic`
- `Views/Components/Unbound/RewardCelebrationView.swift` — modal sheet renders cards stacked, scales with content
- `QuickLogSheet.submit()` — wires PR detection (max-reps / max-weight / max-hold)

**Architectural bet:** Build a reusable `RewardComputer` service that snapshots state before a write, runs the write, snapshots after, and emits a `RewardSummary`. All callers (QuickLog, Session-end, future Scan-complete, etc.) share this one service so reward semantics stay consistent.

---

## Chunk A — Rank-up detection

**Why first:** Rank-ups are the loudest possible reward (cinematic for Vessel/Unbound/Ascendant). Skipping them was the biggest hole.

**Insight:** We don't need the per-skill rank state-machine migration to ship rank-up detection. `RankTitle.derived(state:currentLevel:skillRank:)` already maps the existing data into the 9-tier ladder. We just snapshot that derived value before and after the write.

**Files**
- `Services/Rewards/RewardComputer.swift` (new) — central snapshot/diff service
- `Views/Home/SkillDetailView.swift` (modify QuickLog submit) — call into `RewardComputer.afterSetLog(...)` instead of the inline PR diff currently there

**Service shape (new file):**
```swift
@MainActor
final class RewardComputer {
    static let shared = RewardComputer()
    private init() {}

    /// Snapshot returned by `before(...)` and consumed by `after(...)`.
    /// Carries everything we need to diff cleanly without a stateful
    /// service. Pure data, safe to capture across async boundaries.
    struct Snapshot: Sendable {
        let userId: String
        let skillId: String
        let derivedRank: RankTitle
        let unlockedBadgeIds: Set<String>
        let priorBest: Double           // dimension-aware (reps OR kg OR hold-seconds)
        let isHoldBased: Bool
    }

    func before(skillId: String, isHoldBased: Bool) async -> Snapshot { ... }

    func after(
        snapshot: Snapshot,
        currentSet: LoggedSet,
        skillTitle: String,
        sessionLog: WorkoutLog?,        // nil for QuickLog, non-nil for sessions
        xpGained: Int
    ) async -> RewardSummary { ... }
}
```

**Key methods inside `after(...)`:**
1. Re-derive `RankTitle` post-write — diff against snapshot. If changed, populate `summary.rankUp = RankUp(skillId, skillTitle, fromTier, toTier)`.
2. Run PR diff using `currentSet` vs `snapshot.priorBest` (existing math, just relocated).
3. Evaluate badges via `BadgeService.evaluate(trigger: .sessionLogged(log))` if `sessionLog` non-nil, else `.setCompleted(exerciseKey, reps)`. Diff against `snapshot.unlockedBadgeIds` to filter to NEW badges only.
4. Pass through `xpGained`.
5. Return summary.

**`SkillDetailView.QuickLogSheet.submit()` becomes (after replace):**
```swift
let snapshot = await RewardComputer.shared.before(skillId: skillId, isHoldBased: isHoldBased)
// ... existing write ...
let summary = await RewardComputer.shared.after(
    snapshot: snapshot,
    currentSet: set,
    skillTitle: skillTitle,
    sessionLog: nil,
    xpGained: QuickLogSheet.quickLogXP
)
if summary.hasContent { rewardSummary = summary } else { dismiss() }
```

**Verification**
- Tap Log Set on a skill near a rank-tier boundary → cinematic appears with from/to titles
- Tap Log Set with no rank change → no rank card in stack
- Build green via `xcodebuild`

**Risk:** `RankTitle.derived(...)` is a coarse mapping; it can falsely report a rank-up if the underlying state mutates in a non-monotonic way (achievement → mastered jump). Pin behavior with a snapshot test once the proper per-skill state machine lands.

---

## Chunk B — Badge integration

**Files**
- `Services/Rewards/RewardComputer.swift` — flesh out the badge diff inside `after(...)` (already sketched in Chunk A's `after`)
- `Models/RewardSummary.swift` (no change — `BadgeUnlock` model already exists)

**Mapping Badge → BadgeUnlock:**
```swift
extension Badge {
    var rewardUnlock: BadgeUnlock {
        BadgeUnlock(
            id: id,
            title: title,
            subtitle: description,    // BadgeCatalog already authors copy
            assetName: "badge_art_\(id.replacingOccurrences(of: ".", with: "_"))"
        )
    }
}
```

**Implementation note:** `BadgeService.evaluate(trigger:)` already returns `[Badge]` of newly-unlocked badges (it only emits the diff). So we don't have to compute the diff ourselves — just `.evaluate(...)` after write and map to `BadgeUnlock`. Snapshot before is defensive.

**Verification**
- Trigger a session that crosses a badge threshold (e.g. session #10) → "BADGE UNLOCKED" card appears in stack with the BadgeArt PNG
- No badges → no card
- Multiple badges in one event → stacked cards in earned-order

**Risk:** Badge asset names need to match the imageset bundle exactly. We have 39 BadgeArt assets — audit the mapping function output against the catalog to catch ID drift early.

---

## Chunk C — Session-end celebration

**Why now:** With A + B shipped, session-end is just the same `RewardComputer` call with a different inputs. Most leverage per LOC.

**Files**
- `Views/Home/SkillSessionView.swift` — find the "Finish Session" / save handler, snapshot before, snapshot after, present `RewardCelebrationView` if content
- `RewardComputer.shared.after(...)` — already takes `sessionLog: WorkoutLog?` parameter

**PR semantics for sessions (different from QuickLog):**
- Session can have multiple exercises × multiple sets each
- Surface the SINGLE biggest PR (most-impressive dimension across all sets)
- Tie-break: rank-defining lift > rep-PR > weight-PR > hold-PR
- Detection runs over ALL sets logged in the session, not just the last one

**Pseudo-code in session save handler:**
```swift
let snapshot = await RewardComputer.shared.before(skillId: skillId, isHoldBased: isHoldBased)
let log = persistSession(...)        // existing path
let summary = await RewardComputer.shared.after(
    snapshot: snapshot,
    currentSet: bestSet(from: log),  // helper picks the most-impressive set
    skillTitle: skillTitle,
    sessionLog: log,
    xpGained: log.xpAwarded
)
if summary.hasContent {
    presentRewardSummary = summary   // existing sheet plumbing
} else {
    dismissSession()
}
```

**`bestSet(from log:)` policy:**
- Hold-based skill → set with `max(holdSeconds)`
- Weighted skill → set with `max(weightKg)` (then by reps as tiebreak)
- Bodyweight skill → set with `max(reps)`

**Verification**
- Finish a session that PRs → celebration screen with PR + XP + (if any) badges + (if any) rank-up
- Finish a session with nothing new → silent dismiss
- Cinematic case: complete the criterion that crosses Vessel → full chain-shatter backdrop

---

## Chunk D — First-set-ever celebration

**Why last:** Smallest scope, decoupled. Adds emotional surface for users on day 1.

**The right framing:** This is NOT a fake PR. It's a distinct reward type — "JOURNEY BEGINS" — celebrating their first-ever logged set on this skill.

**Files**
- `Models/RewardSummary.swift` — add `firstSet: FirstSet?` field + struct
- `Views/Components/Unbound/RewardCelebrationView.swift` — render `firstSetCard(...)` in stack
- `Services/Rewards/RewardComputer.swift` — detect first-ever via `priorBest == 0` AND `unlockedBadgeIds` had no prior session badges; emit FirstSet

**Card copy:**
- Title: "FIRST REP"
- Body: "You logged your first {skill}. The path begins."
- Visual: small pulsing accent ring with the skill's icon

**Trigger logic:**
```swift
let isFirstEver = (snapshot.priorBest == 0)
                && (await fetchAnyPriorLog(userId, skillId) == nil)
if isFirstEver {
    summary.firstSet = FirstSet(skillId: ..., skillTitle: ...)
}
```

**Verification**
- Brand-new account, first ever Log Set → "FIRST REP" card
- Second session → no FirstSet card
- Different skill, first time → FirstSet card again (per-skill scope, not per-account)

---

## Build verification (every chunk)

```bash
cd /Users/jlin/Documents/toji/UNBOUND && xcodegen && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expect `** BUILD SUCCEEDED **` after each chunk.

---

## Out of scope for this plan

- **Share cards** — generating an exportable PNG of the celebration moment (separate plan; depends on rank cosmetic asset access in social context)
- **Sound/haptic design** — current `UnboundHaptics.medium()` on appear is fine; a distinct sound pack is its own design pass
- **Streak celebration micro-toast** — different surface (top of screen toast, not modal sheet); add when streak system gets refresh
- **Lift-rank crossings** — currently only the per-skill rank ladder is wired. Lift Rank (Bench/Squat/Deadlift) celebration uses the same RewardSummary + RewardCelebrationView but needs `LiftRankService.evaluate(...)` integration — separate plan
- **Achievement undo** — if the user re-opens a session and edits sets such that a PR no longer holds, we don't claw back the celebration. Edge case, leave alone

---

## Order of operations

1. **Chunk A** — RewardComputer foundation + rank-up detection (~60-90 min)
2. **Chunk B** — badge integration on top (~30 min)
3. **Chunk C** — session-end hook (~45 min)
4. **Chunk D** — first-set-ever (~20 min)

Total: half a day of focused work, four review gates.
