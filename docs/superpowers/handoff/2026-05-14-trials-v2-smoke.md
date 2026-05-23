# Trials v2 — Final Smoke + Handoff
Date: 2026-05-14  
Branch: `trials-v2`  
Sub-project: #5 (UI + Home + Profile + Coach Cue + Regression)

---

## What Shipped in Phases 7–13

### Phase 7 — TrialCardView
- `UNBOUND/Views/Trials/TrialCardView.swift`
- Single card view sized ~460pt for swipeable picker
- Theme tag, big title, blurb, axis pills, capstone footer
- Added `tintColor` + `displayLabel` extensions to `TrialTheme`

### Phase 8 — TrialPickerSheet
- `UNBOUND/Views/Trials/TrialPickerSheet.swift`
- TabView `.page` swiper with 3 horizontal cards
- Tinted COMMIT button updates per selected card

### Phase 9 — Home-slot components
- `TrialPickerPromptCard.swift` — quiet prompt card for contextualStack
- `ActiveTrialCard.swift` — shows chosen trial + capstone progress bar
- `TrialCapstoneToast.swift` + `.trialCapstoneToast()` modifier

### Phase 10 — Home integration
- Added `trialsState: TrialsState` + `showTrialPicker: Bool` state
- Trials state loads in `load()` via `services.trials.state(userId:)`
- `contextualStack` shows `ActiveTrialCard` when trial active, `TrialPickerPromptCard` when cards available and not skipped
- `.sheet(isPresented: $showTrialPicker)` for TrialPickerSheet
- SESSION PLAN rows: `isAlignedExercise(_:)` helper + TRIAL / +1 RPE chip overlay on aligned exercises
- Listens for `.trialCompleted` and `.trialWeekRolled` to refresh state

### Phase 12 — COACH CUE trial-aware copy
- `coachCueText` now surfaces "Trial: push +1 RPE on {exercise}." when trial active + aligned exercise in today's workout
- Falls back to existing copy when no trial or no aligned exercise

### Phase 11 — Profile integration
- `ProfileTrialHistorySection.swift` — shows active trial, completion stats (aligned/growth/prestige counts), unlocked titles
- Added `displayName` extension to `TitleID`
- ProfileView loads `trialsState` and renders `ProfileTrialHistorySection` between `ProfileScanRow` and `heatmapPlaceholder`

---

## API Adaptations Made

| Planned API | Actual API | Resolution |
|---|---|---|
| `trialsState.activeTrial` | `trialsState.currentTrial` | Used `currentTrial` |
| `trialsState.weeklyCards` | `trialsState.currentWeekCards` | Used `currentWeekCards` |
| `trialsState.capstoneProgress` | Derived from `trial.capstoneState` | Computed 0/0.5/1.0 from state enum |
| `trialsState.canPickThisWeek` | Not present | Used `!skippedCurrentWeek && !cards.isEmpty` |
| `services.trials.pickCard(_, userId:)` async | Sync method | Called without `await` |
| `services.trials.history(userId:)` | Not on protocol | Derived from `currentTrial` only (no full history in v1) |
| `TrialCard.alignedAxes` | Not a field | Derived from `TrialTheme.axis(key)` |
| `TrialCard.theme.tintColor` | Not on model | Added as extension on `TrialTheme` |

---

## Regression Results

```
Executed 315 tests, with 5 failures (0 unexpected)
```
- 315 > 280 baseline
- 5 pre-existing failures unchanged (not introduced by this work)
- BUILD SUCCEEDED on iPhone 17 simulator

---

## Session-flow Home Checklist

| Module | Status |
|---|---|
| "Move, [Name]" greeting (`homeBriefing`) | VISIBLE |
| Foundation/Push subhead (`briefingCopy`) | VISIBLE |
| TODAY STATUS hero (`trainingConsole`) | VISIBLE |
| BEGIN SESSION button | VISIBLE |
| SESSION PLAN structure | VISIBLE (+ TRIAL chip when trial active) |
| COACH CUE | VISIBLE (+ trial-aware when active) |
| WEEK PATH | VISIBLE |
| HomeBuildChipCard | VISIBLE |
| ScanDueCard | VISIBLE when due |

---

## Screenshot
`/tmp/trials-v2-home.png`

---

## Commits (Phases 7–13)

| SHA | Description |
|---|---|
| `3c443ef` | feat(trials): add TrialCardView (single card) |
| `14be2a0` | feat(trials): add TrialPickerSheet (3 horizontal swipeable cards) |
| `a5977da` | feat(trials): add TrialPickerPromptCard for Home contextualStack |
| `fe74c04` | feat(trials): add ActiveTrialCard for Home contextualStack |
| `841a6b1` | feat(trials): add TrialCapstoneToast (TierBloomToast-style payoff) |
| `e61acf4` | feat(trials): wire TrialPickerPromptCard + ActiveTrialCard + toast into Home |
| `45d222c` | feat(trials): add ProfileTrialHistorySection |
| `5e7364c` | feat(trials): wire ProfileTrialHistorySection into ProfileView |

---

## Known Gaps / Deferred

- `services.trials.history(userId:)` not implemented — no full multi-week history persistence in v1. Profile section shows current week only.
- TrialPickerPromptCard only visible when `currentWeekCards` is non-empty (requires `ensureCurrentWeek` to have run). On fresh simulator install, shows nothing until first app session completes async load.
- Capstone progress bar is derived from state enum (0/0.5/1.0), not a continuous float. Fine for v1.

---

Status: **DONE**
