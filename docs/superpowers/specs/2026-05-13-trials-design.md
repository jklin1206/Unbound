# Trials — Weekly Emphasis Lens Design

**Status:** Brainstormed 2026-05-13. Awaiting user review before plan-writing.

**Goal:** Ship a weekly trials system that gives users 3 player-chosen direction cards each Monday, biases (not replaces) their normal training mid-week, and culminates in a Saturday-Sunday capstone. Completion earns badges, advances tiered Titles (bronze/silver/gold across 9 paths), and creates the "boss-fight" emotional payoff of the weekly arc.

**Sub-project:** #5 of the UNBOUND product redesign.

**Approach:** Standalone Trials service (`TrialsService` + `TrialsStore`), loose coupling to existing services. Card generation reads `BuildIdentity` and recent `WorkoutLog` history. Capstone verification reuses `TierCriterionEvaluator` (from sub-project #4) for log-based capstones, adds a live in-app timer view for hold/timed capstones, and a manual "I did it" fallback. Notifications + a Home chip create the weekly cadence rhythm.

**Spec dependency:** Builds on BuildIdentity (sub-project #1), the attribute system, the SkillTier ladder (sub-project #4 — specifically `TierCriterion` + `TierCriterionEvaluator`), and the Create Your Own Arc framing (sub-project #3).

---

## Product directive (governing principles)

These come from the user 2026-05-13 and govern every implementation decision below:

1. **3 cards, not 1 assignment.** Each week the app surfaces 3 trial cards — Aligned (reinforces strongest axis), Growth (targets weakest axis), Prestige (stretch). User picks ONE. That commit IS the trial for the week. See [[project_unbound_trials_three_options]].
2. **Emphasis lens, not extra workload.** Trials bias the user's existing training; they never stack mandatory volume on top. "What direction do I want to push my build this week?" — NOT "do these extra workouts." See [[project_unbound_trials_emphasis_not_workload]].
3. **Three-beat weekly arc.** Beginning = direction choice. Middle = bias on existing training (narrative tracking only, no gate). End = capstone (symbolic, validating, exciting — not CNS-destroying).
4. **No penalty for non-completion.** Skip the pick, miss the capstone — fresh trio next Monday. Trials must never produce homework or shame energy.
5. **Capstone window is the Saturday-Sunday weekend.** Two-day arena for the "boss fight" attempt. Single attempt per week.
6. **Titles are earned, not assigned.** 9 Title paths (6 axes + 3 card kinds) × 3 tiers (bronze=3, silver=7, gold=15 completions) = 27 total Titles. Equippable as a profile headline. Aligns with [[feedback_unbound_buildidentity_vs_titles]] — Titles are the "earned fantasy flavor" layer.

Memory anchors: [[project_unbound_trials_three_options]], [[project_unbound_trials_emphasis_not_workload]], [[project_unbound_create_your_own_arc]], [[feedback_unbound_buildidentity_vs_titles]], [[project_unbound_rank_redesign_2026_05_07]].

---

## Architecture

### Core types

```swift
/// The axis or wildcard flavor that defines a trial.
enum TrialTheme: Codable, Hashable, Sendable {
    case axis(AttributeKey)
    case wildcard               // Prestige cards — any axis blend
}

/// Which card slot in the 3-card weekly trio.
enum TrialCardKind: String, Codable, Sendable {
    case aligned                // Reinforces strongest axis
    case growth                 // Targets weakest axis
    case prestige               // Stretch / wildcard
}

/// One of the 3 cards offered for the week. Static once generated.
struct TrialCard: Codable, Identifiable, Equatable, Sendable {
    let id: String              // e.g. "trial-2026-W19-aligned"
    let kind: TrialCardKind
    let theme: TrialTheme
    let displayName: String     // "Power Focus"
    let blurb: String           // 1-sentence narrative
    let capstone: TrialCapstone
}

/// The end-of-week challenge for a card.
struct TrialCapstone: Codable, Equatable, Sendable {
    let displayName: String     // "Top-Set Benchmark"
    let description: String     // Full instruction shown on attempt screen
    let evaluation: CapstoneEvaluation
}

/// How a capstone is verified.
enum CapstoneEvaluation: Codable, Equatable, Sendable {
    /// Reuses TierCriterionEvaluator. Auto-completes from WorkoutLogService hook.
    case autoFromLog(TierCriterion)
    /// In-app timer with countdown; user starts in-app, must hold.
    case liveTimer(seconds: Int, exerciseName: String)
    /// "Mark complete" button. Trust-based.
    case manualClaim
}

/// The user's committed trial for the current week.
struct Trial: Codable, Identifiable, Equatable, Sendable {
    let id: String              // matches TrialCard.id
    let userId: String
    let weekStart: Date         // Monday 00:00 local
    let chosenCard: TrialCard
    var capstoneState: CapstoneState
    var completedAt: Date?
}

enum CapstoneState: String, Codable, Sendable {
    case pending                // Trial active, capstone not yet attemptable (Mon-Fri)
    case windowOpen             // Saturday 00:00 → Sunday 23:59
    case completed              // Capstone done
    case missed                 // Sunday 23:59 passed without completion
}

/// Persisted trials state per user.
struct TrialsState: Codable, Sendable {
    var currentWeekStart: Date?                       // Monday 00:00 of the active week
    var currentWeekCards: [TrialCard]                 // 3 cards for currentWeek; empty before first generation
    var currentTrial: Trial?                          // user's pick (nil = not picked / skipped)
    var completionsByAxis: [AttributeKey: Int]        // per-axis trial-completion count (Title progress)
    var completionsByCardKind: [TrialCardKind: Int]   // per-kind trial-completion count (Title progress)
    var unlockedTitles: [TitleID]                     // ordered, append-only
    var equippedTitle: TitleID?                       // user-chosen headline title

    static let empty = TrialsState(
        currentWeekStart: nil,
        currentWeekCards: [],
        currentTrial: nil,
        completionsByAxis: [:],
        completionsByCardKind: [:],
        unlockedTitles: [],
        equippedTitle: nil
    )
}

/// Identifier for an earned Title.
struct TitleID: Codable, Hashable, Sendable {
    enum Path: Codable, Hashable, Sendable {
        case axis(AttributeKey)
        case cardKind(TrialCardKind)
    }
    enum Tier: String, Codable, Sendable { case bronze, silver, gold }
    let path: Path
    let tier: Tier
}
```

### Title catalog

9 paths × 3 tiers = **27 Titles**. Thresholds: bronze at 3 completions, silver at 7, gold at 15.

Axis Titles (locked naming):
- Power: `Power Initiate` / `Power Sovereign` / `Power Ascendant`
- Agility: `Agility Initiate` / `Agility Striker` / `Agility Ascendant`
- Control: `Control Initiate` / `Control Master` / `Control Ascendant`
- Endurance: `Endurance Initiate` / `Endurance Pacer` / `Endurance Ascendant`
- Mobility: `Mobility Initiate` / `Mobility Warden` / `Mobility Ascendant`
- Explosiveness: `Explosiveness Initiate` / `Explosiveness Striker` / `Explosiveness Ascendant`

Card-kind Titles:
- Aligned: `Specialist Initiate` / `Specialist Master` / `Specialist Ascendant`
- Growth: `Wanderer Initiate` / `Wanderer Pathfinder` / `Wanderer Ascendant`
- Prestige: `Striver Initiate` / `Striver Conqueror` / `Striver Ascendant`

(Naming may be tuned during implementation but the structure ships as above. Treat these as the authoring scaffold, not gospel.)

A single trial completion increments BOTH the axis counter (for the trial's theme axis) AND the card-kind counter (for the chosen card's `kind`). Both counters can independently cross thresholds and unlock Titles in the same completion event.

### Services

```swift
@MainActor
protocol TrialsServiceProtocol: AnyObject {
    /// If currentWeekStart is stale or absent, roll the week and generate 3 fresh cards.
    /// Marks prior trial as .missed if uncompleted. Posts .trialWeekRolled.
    func ensureCurrentWeek(userId: String) async

    /// User picks one of the 3 cards. Persists as currentTrial; the other 2 are discarded.
    func pickCard(_ card: TrialCard, userId: String)

    /// User skipped the pick this week. No trial active; no chip; no penalty.
    /// Persisted so the modal doesn't re-pop on next foreground.
    func skipThisWeek(userId: String)

    /// Mark the current trial's capstone complete. Increments Title counters,
    /// unlocks Titles at threshold crossings, posts .trialCompleted (and
    /// .titleUnlocked per crossing).
    func completeCapstone(userId: String, at date: Date)

    /// Called from WorkoutLogService.recompute after each session.
    /// Only acts when capstoneState == .windowOpen and evaluation == .autoFromLog.
    func evaluateCapstoneFromLog(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) async

    /// Equip an unlocked Title as the user's profile headline.
    func equipTitle(_ titleId: TitleID?, userId: String)

    func state(userId: String) -> TrialsState
}
```

**`TrialGenerator`** — pure function. Inputs: `BuildIdentity`, recent `[WorkoutLog]`, week-start `Date`. Output: 3 `TrialCard`s.

Algorithm:
- **Aligned**: `theme = .axis(identity.dominantAxis)` — strongest axis from BuildIdentity. Uses `CapstoneCatalog.capstone(for: axis)`.
- **Growth**: `theme = .axis(identity.weakestAxis)` — lowest current axis from `AttributeService.snapshot`. Uses `CapstoneCatalog.capstone(for: axis)`.
- **Prestige**: `theme = .wildcard`. Uses `PrestigeCapstoneCatalog.capstone(for: weekNumber)` — rotates through ≥6 prestige capstones so the same one doesn't repeat within ~6 weeks.

Deterministic given identical inputs — testable via fixtures.

**`CapstoneCatalog`** — static data:

```swift
enum CapstoneCatalog {
    static let perAxis: [AttributeKey: TrialCapstone] = [
        .power: TrialCapstone(
            displayName: "Top-Set Benchmark",
            description: "Hit a working set above your 4-week best on a Power-axis exercise.",
            evaluation: .autoFromLog(/* dynamically scaled — see below */)
        ),
        .agility: TrialCapstone(
            displayName: "Movement Flow",
            description: "Move through a 3-minute mobility flow without breaks.",
            evaluation: .liveTimer(seconds: 180, exerciseName: "mobility flow")
        ),
        .control: TrialCapstone(
            displayName: "Hold Sequence",
            description: "Hold a strict 90-second plank.",
            evaluation: .liveTimer(seconds: 90, exerciseName: "plank")
        ),
        .endurance: TrialCapstone(
            displayName: "Timed Cardio",
            description: "Log a 5K run, row, or bike interval session.",
            evaluation: .autoFromLog(.variant("run 5k"))
        ),
        .mobility: TrialCapstone(
            displayName: "Deep Squat Hold",
            description: "Sit in a deep squat for 60 seconds without breaking.",
            evaluation: .liveTimer(seconds: 60, exerciseName: "deep squat")
        ),
        .explosiveness: TrialCapstone(
            displayName: "Output Challenge",
            description: "8 max-effort box jumps.",
            evaluation: .autoFromLog(.reps(8, exerciseName: "box jump"))
        )
    ]
}

enum PrestigeCapstoneCatalog {
    static let rotation: [TrialCapstone] = [
        TrialCapstone(
            displayName: "Max Pull-Up AMRAP",
            description: "One AMRAP set of pull-ups, 15+ reps unbroken.",
            evaluation: .autoFromLog(.reps(15, exerciseName: "pullup"))
        ),
        TrialCapstone(
            displayName: "Broad Jump Distance",
            description: "Hit a personal-best broad jump.",
            evaluation: .manualClaim
        ),
        TrialCapstone(
            displayName: "1-Rep PR Attempt",
            description: "Hit a 1-rep PR on bench, squat, deadlift, or overhead press.",
            evaluation: .autoFromLog(.weightKg(/* user's recent best × 1.025 */))
        ),
        TrialCapstone(
            displayName: "Strict Muscle-Up",
            description: "One strict muscle-up. No kip.",
            evaluation: .autoFromLog(.variant("strict muscle-up"))
        ),
        TrialCapstone(
            displayName: "L-Sit Hold",
            description: "20-second strict L-sit hold.",
            evaluation: .liveTimer(seconds: 20, exerciseName: "l-sit")
        ),
        TrialCapstone(
            displayName: "5K Sub-25",
            description: "Log a 5K under 25 minutes.",
            evaluation: .manualClaim
        )
    ]
}
```

The `.power` autoFromLog criterion needs runtime scaling — at card generation time, the generator computes the user's best working weight on Power-axis exercises in the last 4 weeks and bakes a `.weightKg(best × 1.05)` criterion into the card. Same dynamic-scaling pattern for the Prestige 1-rep PR capstone.

**`TrialsStore`** — UserDefaults JSON persistence. One `TrialsState` entry per userId. Mirrors `UserSkillTierStore` pattern from sub-project #4.

**`TitleService`** — small helper over `TrialsState.unlockedTitles`. Exposes `unlockedTitles(userId:)`, `equippedTitle(userId:)`, `equipTitle(_:userId:)`. Implementation just forwards to `TrialsService.state` and `TrialsService.equipTitle`.

**`TrialsNotificationScheduler`** — small actor that schedules 3 local notifications per week per user:
- Monday 09:00 local: "Your week's trials are ready."
- Saturday 08:00 local: "Capstone unlocked." (only if uncompleted active trial)
- Sunday 18:00 local: "Capstone window closes in 6 hours." (only if uncompleted active trial)

Reschedules on `.trialWeekRolled`. Cleared on `skipThisWeek`. Notifications are accelerants, not gates — system works without permission.

### Notifications

```swift
extension Notification.Name {
    static let trialWeekRolled         = Notification.Name("unbound.trialWeekRolled")
    static let trialPicked             = Notification.Name("unbound.trialPicked")
    static let trialCapstoneWindowOpen = Notification.Name("unbound.trialCapstoneWindowOpen")
    static let trialCompleted          = Notification.Name("unbound.trialCompleted")
    static let titleUnlocked           = Notification.Name("unbound.titleUnlocked")
}
```

Payloads:
- `.trialPicked`, `.trialCompleted`: `Trial` in `object`
- `.titleUnlocked`: `TitleID` in `object`
- `.trialWeekRolled`, `.trialCapstoneWindowOpen`: no payload

### WorkoutLogService integration

```swift
// Inside WorkoutLogService.recompute(after: log):
let history = log.exerciseEntries
let bw = await services.user.currentBodyweightKg(userId: log.userId) ?? 70
await trialsService.evaluateCapstoneFromLog(
    userId: log.userId,
    history: history,
    bodyweightKg: bw
)
```

The trials service's evaluator only acts when:
1. `currentTrial.capstoneState == .windowOpen`
2. `currentTrial.chosenCard.capstone.evaluation == .autoFromLog(criterion)`

When both hold, it calls `TierCriterionEvaluator.satisfied(criterion:history:bodyweightKg:)` and if true, fires `completeCapstone`.

---

## Weekly lifecycle

Single source of truth: ISO week number + year in local timezone. `TrialsState.currentWeekStart` is Monday 00:00 of the active week.

### Rollover

```
On app foreground OR home-tab appear:
  TrialsService.ensureCurrentWeek(userId:) →
    state = store.load(userId: userId)
    let newWeekStart = mostRecentMondayMidnight(now: Date.now)
    if state.currentWeekStart == newWeekStart { return }

    // Roll prior week. completions counters do NOT change on miss —
    // they only increment on actual completion. The prior trial object
    // itself is discarded (no trial-history view in scope); the .missed
    // state matters only for the in-flight week before rollover, so the
    // chip shows the correct "missed" treatment between Sun 23:59 and
    // Mon 00:00 if the user opens the app in that window.
    if var trial = state.currentTrial, trial.capstoneState != .completed {
        trial.capstoneState = .missed
    }

    // Generate new cards
    let identity = AttributeService.shared.snapshot(userId: userId, asOf: .now).buildIdentity
    let history = await services.workoutLog.fetchRecentLogs(userId: userId, limit: 30)
    state.currentWeekCards = TrialGenerator.cards(
        for: identity,
        history: history,
        weekStart: newWeekStart
    )
    state.currentTrial = nil
    state.currentWeekStart = newWeekStart

    store.save(state, userId: userId)
    NotificationCenter.default.post(name: .trialWeekRolled, object: nil)
    TrialsNotificationScheduler.reschedule(for: userId, weekStart: newWeekStart)
```

### Capstone window transition

```
On app foreground OR home-tab appear:
  TrialsService.checkCapstoneWindow(userId:) →
    if let trial = state.currentTrial,
       trial.capstoneState == .pending,
       Date.now >= mostRecentSaturday00(of: state.currentWeekStart) {
        trial.capstoneState = .windowOpen
        store.save(state)
        NotificationCenter.default.post(name: .trialCapstoneWindowOpen, object: nil)
    }
```

### Auto-completion hook

`WorkoutLogService.recompute(after:)` calls `trialsService.evaluateCapstoneFromLog(...)` after every session ingest. Inside:

```
TrialsService.evaluateCapstoneFromLog(userId:history:bodyweightKg:):
    let state = store.load(userId: userId)
    guard let trial = state.currentTrial,
          trial.capstoneState == .windowOpen,
          case .autoFromLog(let criterion) = trial.chosenCard.capstone.evaluation
    else { return }

    if TierCriterionEvaluator.satisfied(
        criterion: criterion,
        history: history,
        bodyweightKg: bodyweightKg
    ) {
        completeCapstone(userId: userId, at: .now)
    }
```

### Completion flow

```
TrialsService.completeCapstone(userId:at:):
    guard var state = store.load(userId: userId), var trial = state.currentTrial else { return }
    trial.capstoneState = .completed
    trial.completedAt = date
    state.currentTrial = trial

    // Increment counters
    let axisOrNil: AttributeKey? = {
        if case .axis(let a) = trial.chosenCard.theme { return a }
        return nil
    }()
    if let axis = axisOrNil {
        state.completionsByAxis[axis, default: 0] += 1
    }
    state.completionsByCardKind[trial.chosenCard.kind, default: 0] += 1

    // Detect Title threshold crossings
    let crossings = TitleThresholdEvaluator.crossings(prior: priorState, current: state)
    for titleId in crossings {
        state.unlockedTitles.append(titleId)
        NotificationCenter.default.post(name: .titleUnlocked, object: titleId)
    }

    store.save(state, userId: userId)
    NotificationCenter.default.post(name: .trialCompleted, object: trial)
```

`TitleThresholdEvaluator` is a small pure helper that compares `prior` vs `current` counter dicts and returns any `TitleID`s that just crossed 3/7/15.

---

## UI surfaces

### Monday card-pick modal — `TrialCardPickerView`

Presented as `.fullScreenCover` when the user opens the app for the first time on or after Monday 00:00 of a new week AND `currentTrial == nil` AND they haven't skipped this week.

Structure (top → bottom):
1. **Cinematic intro line** — "CHOOSE YOUR DIRECTION" in `Font.unbound.displayM`, tracked.
2. **Three TrialCardView cards** stacked vertically (iPhone) or 3-wide (iPad). Each shows:
   - Card kind chip (`ALIGNED` / `GROWTH` / `PRESTIGE`) — muted monospace, top-left.
   - Theme line (`POWER FOCUS`) — `Font.unbound.titleL`, axis-colored glow.
   - 1-sentence blurb under the theme.
   - Capstone preview line — "Capstone: Top-Set Benchmark · Saturday".
3. **Bottom skip link** — "Skip this week" as a faint underlined `Text`.

Tap a card → confirmation sheet ("Lock in Power Focus for the week?") → on confirm, `TrialsService.pickCard`, dismiss modal, card-animates into the Home chip.

Tap "Skip this week" → confirmation → `TrialsService.skipThisWeek`, dismiss modal. No chip on Home until next Monday.

### Home chip — `TrialActiveChip`

Renders at the top of the Home tab (above the existing daily-mission card). Hidden if `currentTrial == nil` AND user hasn't yet been prompted this week (avoid pre-modal flash) OR if user skipped this week.

State-driven appearance:

| State | Treatment | CTA |
|---|---|---|
| `pending` (Mon–Fri) | Muted surface bg, kind chip + theme line + "Capstone unlocks Saturday" subline | Tap → trial detail sheet |
| `windowOpen` (Sat–Sun) | Accent border + faint pulse | "Capstone ready — tap to start" → `CapstoneAttemptView` |
| `completed` | Celebratory: accent fill, ✓ icon, "{TheTitlePath} progress" sub | Tap → completion replay sheet |
| `missed` | Hidden — chip disappears at Sun 23:59 transition | — |

Live data wired via `@EnvironmentObject services` reading `trials.state(userId:)`. Observes `.trialPicked`, `.trialCapstoneWindowOpen`, `.trialCompleted`, `.trialWeekRolled` to refresh.

### Capstone attempt screen — `CapstoneAttemptView`

Push-navigated from the active chip when it's tapped during the windowOpen state.

Three rendering modes based on `capstone.evaluation`:

**`.autoFromLog(criterion)`** — `CapstoneAutoFromLogView`
- Description text explaining the criterion ("Hit a working set of 100kg or higher this weekend").
- Status badge: "Watching your logs" with a small spinner.
- Auto-dismisses + opens `TrialCompletionView` when `.trialCompleted` fires.
- Tap-to-dismiss is allowed; the watcher keeps running in the background.

**`.liveTimer(seconds, exerciseName)`** — `CapstoneLiveTimerView`
- Big "START" button.
- On tap: fullscreen countdown overlay, exercise name + remaining seconds, heavy haptic at start.
- On completion: heavy haptic, calls `completeCapstone`, opens `TrialCompletionView`.
- On early cancel: cancel sheet with "If you stop now, this attempt won't count." Cancel returns to capstone screen, can retry.

**`.manualClaim`** — `CapstoneManualClaimView`
- Description + "I completed this challenge" button.
- Tap → confirmation sheet → `completeCapstone` → `TrialCompletionView`.

### Completion celebration — `TrialCompletionView`

Triggered on `.trialCompleted` notification. Lighter-weight than the chain-shatter cinematic from sub-project #4.

- Header: "TRIAL COMPLETE" in `Font.unbound.displayM`, axis glow.
- Card identity restated: kind chip + theme line.
- Title progress: "Power Sovereign · 4 / 7 completions" with a progress bar.
- If `.titleUnlocked` co-fired: a smaller chain-shatter moment plays first; the unlocked Title appears as a `TitleBadge` with celebratory haptic.
- "Share" button → uses existing `ShareSheet` pattern (the trial name, theme, and Title progress get rendered into a share card via a reused-ish `TrialShareCardRenderer` modeled on `RankUpShareCardRenderer`).
- "Done" button → dismiss.

### Profile integration

Extend `ascensionCard` from sub-project #4 (the `Profile/ProfileView.swift` rank surface). Add a new row underneath:

```
TITLES EARNED  •  {count}

[TitleBadge] [TitleBadge] [TitleBadge] ...    →    (horizontal scroll)
```

Each `TitleBadge` is a pill chip — distinct visual from `TierBadge`. Tap → "Equip as headline" action sheet with "Set as my title" / "Unequip current" / "Cancel".

The equipped Title appears next to the user's display name on the `headerCard` of the profile (small monospace label above or below the handle).

### TitleBadge view (new)

```swift
struct TitleBadge: View {
    let titleId: TitleID
    var compact: Bool = false

    var body: some View {
        // Pill chip. Bronze: muted bronze hue. Silver: silver hue.
        // Gold: brand accent with glow. Text = TitleCatalog.displayName(for: titleId).
    }
}
```

Color treatment:
- Bronze tier: muted warm tone (`Color(red: 0.68, green: 0.46, blue: 0.28).opacity(0.7)`)
- Silver tier: cool neutral (`Color(red: 0.75, green: 0.78, blue: 0.82)`)
- Gold tier: `Color.unbound.accent` + glow (mirrors flagship cinematic energy)

---

## Testing strategy

### Pure-type tests

- `TrialThemeTests` — Codable roundtrip for `.axis(_)` and `.wildcard`. Equality.
- `TrialCardKindTests` — Codable, allCases coverage.
- `TitleIDTests` — Codable, equality; both `.axis` and `.cardKind` path variants.
- `CapstoneEvaluationTests` — Codable roundtrip for each variant.

### Generator + catalog tests

- `TrialGeneratorTests`:
  - Deterministic: same inputs → same 3 cards.
  - Aligned card's theme = identity.dominantAxis.
  - Growth card's theme = identity.weakestAxis from snapshot.
  - Prestige card differs across consecutive weeks (no immediate repeat).
  - All 3 cards have distinct themes.
- `CapstoneCatalogTests` — every `AttributeKey` has a capstone; `PrestigeCapstoneCatalog.rotation.count >= 6`.

### Service tests — `TrialsServiceTests`

- `ensureCurrentWeek` generates 3 cards when state is empty.
- `ensureCurrentWeek` rolls a new week when ≥7 days elapsed.
- `ensureCurrentWeek` marks prior trial as `.missed` if uncompleted.
- `pickCard` persists the choice; subsequent `state.currentTrial` reflects the card.
- `skipThisWeek` persists no trial AND no card shows on next ensureCurrentWeek within the same week.
- `completeCapstone`:
  - Increments `completionsByAxis[axis]` by 1 (when axis-themed).
  - Increments `completionsByCardKind[kind]` by 1.
  - Unlocks Titles at exactly the 3 / 7 / 15 thresholds. Boundary tests at each threshold (2→3, 6→7, 14→15).
  - Posts `.trialCompleted` once.
  - Posts `.titleUnlocked` once per crossing (can fire 0, 1, or 2 times per completion — axis path + card-kind path).
- `evaluateCapstoneFromLog`:
  - Only acts when `windowOpen` AND `.autoFromLog`.
  - Calls `TierCriterionEvaluator.satisfied` with correct args.
  - Triggers `completeCapstone` on satisfaction.
  - No-op for `.liveTimer` or `.manualClaim` evaluations.

### Persistence tests — `TrialsStoreTests`

- Save/load roundtrip per userId.
- Multiple users isolated.
- Empty state on missing user.

### Title threshold tests — `TitleThresholdEvaluatorTests`

- 2→3 (axis): yields `[.bronze]`.
- 6→7 (axis): yields `[.silver]`.
- 14→15 (axis): yields `[.gold]`.
- Mixed jumps (e.g. counter goes 2→8 from a single completion is impossible — but tested as a sanity guard).
- Both axis AND card-kind crossings in a single completion fire 2 events.

### Snapshot tests

- `TrialCardPickerSnapshotTests` — 3 cards rendered, dark + light if applicable.
- `TrialActiveChipSnapshotTests` — `.pending`, `.windowOpen`, `.completed` states.
- `CapstoneAttemptSnapshotTests` — all 3 evaluation modes.
- `TitleBadgeSnapshotTests` — bronze / silver / gold variants.

`xcodebuild test` is authoritative per [[feedback_sourcekit_crossfile_noise_unbound]].

---

## Migration strategy — greenfield

No existing trial-like data. On first launch after upgrade:
- `TrialsState` is `.empty`.
- First `ensureCurrentWeek` call generates the user's initial 3 cards from their BuildIdentity + recent logs (or seeded BuildIdentity if no logs yet).
- The Monday modal triggers on the next app foreground if it's Monday-or-later of the current week.

For users with no training history (brand new): generator uses their onboarding-seeded BuildIdentity (from sub-project #3). The dominant axis is the highest-seeded axis; weakest is the lowest. Prestige card still rotates per week number.

No data migration required.

---

## Implementation order (informs the plan, not binding)

The writing-plans skill will lay out exact phases. Suggested order:

1. Core types (`TrialTheme`, `TrialCardKind`, `TrialCard`, `TrialCapstone`, `CapstoneEvaluation`, `Trial`, `CapstoneState`, `TrialsState`, `TitleID`).
2. Title catalog + `TitleThresholdEvaluator` + tests.
3. `CapstoneCatalog` + `PrestigeCapstoneCatalog` static data.
4. `TrialGenerator` (pure) + tests.
5. `TrialsStore` (UserDefaults JSON) + tests.
6. `TrialsService` + tests (rollover, pick, complete, evaluate-from-log).
7. `WorkoutLogService.recompute` integration hook.
8. `TitleBadge` view.
9. UI: `TrialActiveChip` + integration on Home.
10. UI: `TrialCardPickerView` + presentation logic.
11. UI: `CapstoneAttemptView` + 3 mode subviews (autoFromLog / liveTimer / manualClaim).
12. UI: `TrialCompletionView` + share card.
13. Profile integration: Titles row in ascensionCard + equip flow.
14. `TrialsNotificationScheduler` + local notification registration.
15. Final smoke + regression.

---

## Out of scope (deferred)

- Social/squad trial coordination (sub-project #6 territory).
- Live leaderboards on capstone results.
- Trial history view ("show me my last 12 trials"). Profile shows aggregate counter only.
- Custom user-authored trials.
- AI-generated capstone descriptions (locked authored copy only).
- Title naming refinement / brand audit (the locked scaffold above ships; brand can tune later).
- Push notifications (uses iOS local notifications only — server-side push is future work).
- Trial-specific share card visual design (uses a reused-ish layout from `RankUpShareCard`; bespoke trial share-card art deferred).
