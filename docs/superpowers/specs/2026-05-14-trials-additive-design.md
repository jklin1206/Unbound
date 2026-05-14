# Trials — Additive Design (sub-project #5)

**Status:** Spec.
**Branch:** New `trials-v2` off current `program-redesign` HEAD.
**Reference:** `/Users/jlin/Documents/toji/UNBOUND-trials/` — has TrialCard / TrialTheme / Trial / TrialCapstone models, TrialsService, 27 trial titles, evaluator logic. Salvageable as-is for models + service layer.

---

## Goal

Weekly emphasis-lens system. Every Monday user picks 1 of 3 Trial cards (Aligned / Growth / Prestige themes). Selected Trial biases the existing training program visually + suggests +1 RPE on aligned exercises. Completing the Trial by Sunday unlocks a Title and bumps the aligned attribute axis.

## Hard philosophy constraints

Per memory:
- **3 player-chosen cards** ([[project_unbound_trials_three_options]]). Aligned/Growth/Prestige mix. Pick 1. Complete-or-not on that path.
- **Emphasis lens, NOT extra workload** ([[project_unbound_trials_emphasis_not_workload]]). Beat structure: beginning (choose) → middle (bias training) → end (capstone). Never separate mandatory workouts.
- **Cadence:** daily training / weekly trials / monthly scan ([[project_unbound_create_your_own_arc]]).
- **Self-directed identity evolution** — completing earns a Title that compounds over time.

## Hard additive constraint

Session-flow Home modules untouched:
- "Move, [Name]" greeting
- Foundation/Push subhead
- TODAY STATUS hero
- BEGIN SESSION
- SESSION PLAN (gets soft visual emphasis on aligned exercises — see below)
- COACH CUE (gets +1 RPE suggestion when Trial active — see below)
- WEEK PATH
- HomeBuildChipCard, ScanDueCard

The Trial card lives in the existing contextualStack slot. No new tab. No layout shift.

## Out of scope

- Squads (#6) — separate spec.

---

## Architecture

### Models (most exist in `trials-impl` reference branch)

| File | Status |
|---|---|
| `UNBOUND/Models/TrialTheme.swift` | NEW (copy from reference). Enum: `.aligned`, `.growth`, `.prestige`. Each theme has a tagline, color treatment, and tier ladder (bronze/silver/gold). |
| `UNBOUND/Models/TrialCardKind.swift` | NEW (copy). Enum tagging the card with its aligned attribute axis. |
| `UNBOUND/Models/TrialCard.swift` | NEW (copy). The presentable card: theme, kind, title, subtitle, aligned attributes, capstone requirements, reward Title id. |
| `UNBOUND/Models/Trial.swift` | NEW (copy). The active trial record: chosen card, started date, completion state. |
| `UNBOUND/Models/TrialCapstone.swift` | NEW (copy). The end-of-week criterion (e.g. "Hit RPE 8 on Back Squat" or "Complete 4 power sessions"). |

### Catalog
- `UNBOUND/Resources/TrialCatalog.json` OR Swift-constants file (whichever the reference uses). Defines all available trial cards keyed by week/theme. ~24-30 cards total covering the 3 themes × multiple variants.

### Services
- `UNBOUND/Services/Trials/TrialCatalog.swift` — exposes the deterministic 3-card pick for a given week (e.g. seed by ISO week number + user id).
- `UNBOUND/Services/Trials/TrialsStore.swift` — UserDefaults persistence: current Trial + history.
- `UNBOUND/Services/Trials/TrialsService.swift` — orchestrator. `weeklyCards(userId:)` returns the 3-card pick. `pickCard(_:userId:)` activates a Trial. `evaluateCapstoneFromLog(...)` checks if today's workout completes the capstone. `expireTrialIfNeeded(userId:)` rolls into next week.
- `UNBOUND/Services/Trials/TrialTitleEvaluator.swift` — maps `(Trial, completionState)` to a Title id from the 27-title catalog.

### UI

| File | Purpose |
|---|---|
| `UNBOUND/Views/Trials/TrialCardView.swift` | Single card — theme color treatment, title, subtitle, capstone hint, "tap to pick" affordance |
| `UNBOUND/Views/Trials/TrialPickerSheet.swift` | Modal sheet presenting the 3 cards **side-by-side horizontally** (TabView with PageStyle, or horizontal scroll) with swipe-to-browse + tap-to-pick |
| `UNBOUND/Views/Trials/ActiveTrialCard.swift` | Compact card shown on Home contextualStack once a trial is picked — shows selected trial + capstone progress |
| `UNBOUND/Views/Trials/TrialCapstoneToast.swift` | TierBloomToast-style overlay on capstone completion |
| `UNBOUND/Views/Profile/ProfileTrialHistorySection.swift` | History list on Profile showing past Trials + earned Titles |

### Notifications
Add to existing `AttributeRankUpEvent.swift` notifications extension:
```swift
extension Notification.Name {
    static let trialPicked = Notification.Name("unbound.trialPicked")
    static let trialCapstoneCompleted = Notification.Name("unbound.trialCapstoneCompleted")
    static let trialExpired = Notification.Name("unbound.trialExpired")
}
```

---

## UI integration

### Home contextualStack
- On Monday morning OR when no trial is picked for the current week: show `TrialPickerPromptCard` ("Pick this week's trial · 3 cards") → tap opens `TrialPickerSheet`.
- After picking: show `ActiveTrialCard` (compact, displays trial title + capstone progress).
- After capstone completed: show `ActiveTrialCard` with a "✓ Capstone Cleared" state until week rolls over.

### TrialPickerSheet (the 3-horizontal-cards UI)
```swift
struct TrialPickerSheet: View {
    let cards: [TrialCard]  // exactly 3
    let onPick: (TrialCard) -> Void
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("PICK THIS WEEK'S TRIAL")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(Color.unbound.textSecondary)

            // 3 horizontal cards via TabView with PageStyle.
            // User swipes left/right between cards. Page indicator dots below.
            TabView(selection: $selectedIndex) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    TrialCardView(card: card)
                        .tag(index)
                        .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 480)

            // Pick button
            Button("Pick this trial") {
                onPick(cards[selectedIndex])
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
        .background(Color.unbound.bg)
    }
}
```

Alternative: horizontal `ScrollView { HStack { ... } }` instead of TabView — depends on UX preference. Plan should pick one.

### SESSION PLAN emphasis
- When a Trial is active, each row in SESSION PLAN that matches the trial's aligned axes (e.g. Trial aligned to .power → Back Squat, Bench Press, Deadlift rows highlighted) gets:
  - Small "TRIAL" violet tag chip
  - +1 RPE chip in the rest column ("RPE 8 → 9 · TRIAL")
- Non-aligned rows render unchanged.

### COACH CUE
- If active Trial exists AND today's workout has an aligned exercise:
  - COACH CUE displays "Trial: push +1 RPE on {exercise}. {motivation line}"
  - Backed by the existing ClaudeClient (sonnet, not haiku — coach cue is higher stakes copy)
- Otherwise: existing COACH CUE behavior (form/load coaching) unchanged.

### Profile
- New section `ProfileTrialHistorySection`:
  - Header: "TRIAL HISTORY"
  - List of past Trials with theme color + week date + Title earned (if any)
  - Most recent first; cap at 12 entries (with "see all" if more)

---

## Data flow

### Weekly cycle (every Monday)
1. `TrialsService.weeklyCards(userId:)` deterministically picks 3 cards from `TrialCatalog`:
   - Seed = `userId.hashValue ^ isoWeekNumber`
   - 1 Aligned (matches user's BuildIdentity primary axis — feels achievable)
   - 1 Growth (cross-trains the weakest axis from AttributeProfile)
   - 1 Prestige (high-ceiling, harder capstone, biggest title reward)
2. Cards shown in `TrialPickerSheet` when user opens Home and contextualStack offers it.
3. User picks one. `TrialsService.pickCard(_:userId:)` writes `Trial` to `TrialsStore`. Posts `.trialPicked`.

### During the week
1. Every workout log save hooks `TrialsService.evaluateCapstoneFromLog(log:userId:)` (already wired in WorkoutLogService from earlier sub-projects).
2. Evaluator checks if log satisfies the capstone (e.g. "Hit RPE ≥8 on Back Squat for 3 consecutive sessions"). 
3. If completed: write completion to TrialsStore. Post `.trialCapstoneCompleted`.
4. `TrialCapstoneToast` modifier on Home/Profile listens for that notification → renders TierBloomToast-style overlay (NOT the chain-motif cinematic — that's reserved for SkillTier flagship crossings).
5. `TrialTitleEvaluator.titleEarned(trial:)` resolves the Title id. `TitleService.unlock(titleId:userId:)` records it (uses existing infrastructure).
6. `AttributeService.applyBoost(axis:amount:userId:)` adds +5 to the aligned axis. Posts `.attributeRankUpEvent` if a tier crossing happens.

### End of week (Sunday → Monday rollover)
1. App launch on a new ISO week triggers `TrialsService.expireTrialIfNeeded(userId:)`.
2. If a trial was active and capstone wasn't completed → no title, no boost, log expiration to history.
3. New 3-card pick generated for the new week.

---

## TrialCard structure (from reference branch)

```swift
struct TrialCard: Identifiable, Codable, Equatable, Sendable {
    let id: String  // stable id, e.g. "aligned-power-2026w20"
    let theme: TrialTheme  // .aligned / .growth / .prestige
    let kind: TrialCardKind  // .powerSurge, .enduranceBuilder, etc.
    let title: String  // "Power Surge"
    let subtitle: String  // "Push your strongest 3 lifts harder."
    let alignedAxes: Set<AttributeKey>
    let capstone: TrialCapstone
    let titleReward: TitleID  // unlocks this Title on capstone completion
    let attributeBoost: Double  // 5.0 default
}
```

Reuse from reference branch.

---

## Acceptance criteria

1. **Session-flow Home modules unchanged.** Snapshot test passes.
2. **3 cards horizontal** in TrialPickerSheet (swipeable, with indicator dots).
3. **Aligned exercises in SESSION PLAN** get violet "TRIAL" tag + "+1 RPE" suggestion when a Trial is active and matches.
4. **Title unlock + attribute boost** on capstone completion.
5. **Trial history visible on Profile.**
6. **All trial-related tests pass.** No regression in pre-existing test count.

---

## Architecture decisions to lock in plan

1. **TabView .page vs ScrollView HStack for the 3-card picker** — pick one in the plan. TabView.page is iOS-native swipe; ScrollView gives explicit snap control.
2. **Catalog format** — JSON (like `AttributeContributions.json` from #1) or Swift constants? Reference branch uses Swift constants per cluster. Pick one.
3. **Capstone evaluation cadence** — every saveLog (real-time) vs daily batch? Reference uses every-saveLog. Stick with that.
4. **Trial card image art** — does each card have a hero image, or pure typographic + color? Recommendation: pure typographic for v1 (TrialTheme color does the heavy lifting). Image-per-card is future work.
5. **"Aligned" axis for the Aligned card** — derived from `BuildIdentity.primary` or just user's strongest attribute? Reference uses `BuildIdentity.primary`. Stick with that.

---

## Related memory
- [[project_unbound_trials_three_options]] — 3 cards Aligned/Growth/Prestige
- [[project_unbound_trials_emphasis_not_workload]] — emphasis lens, not workload
- [[project_unbound_create_your_own_arc]] — weekly cadence
- [[feedback_unbound_additive_not_redesign]] — session-flow preserved
- [[project_unbound_home_vs_profile_boundary]] — Home=LIVE / Profile=ARCHIVE
- [[feedback_verify_visual_diff_before_claiming_additive]] — screenshot before merge
