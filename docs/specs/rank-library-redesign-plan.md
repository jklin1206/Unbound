# Implementation Plan: Rank Library + Rank Detail Redesign

Companion to `docs/specs/rank-library-redesign.md`. Status: PLAN (awaiting review before IMPLEMENT).

## Overview

Rebuild the rank library as a full-screen push destination that leads with the user's earned ranks (best-first), and replace BOTH divergent detail screens with one unified four-tab `RankDetailView` used app-wide.
Presentation-layer only: reuse existing data sources, logging, chart, and muscle-map components.

## Architecture Decisions

1. **Full migration to one detail (user call).** `RankDetailView` becomes the app-wide skill/exercise detail. It replaces every use of `SkillDetailView` (5 call sites) and `ProgramRankExerciseDetailView` (3 call sites). Both old screens and all their extensions are deleted once migrated.
2. **Dual init / source-normalizing view model.** `RankDetailView(node:graph:nodeStates:)` serves the 4 skill-only callers (skill tree x2, Program Overview, Home DEBUG) as a near drop-in rename; `RankDetailView(row:)` serves the library for both `.skill` and `.exercise`. A `RankDetailViewModel` normalizes either entry into the four tabs.
3. **Absorb skill behaviors, not just exercise ones.** The new detail must carry SkillDetailView's rank path, requirements/unlocks, guide (Form/Assist/Tips/Fixes), and sticky action (-> `SkillSessionView`/quickLog/trainChooser), plus the exercise ruler/chart/muscle-map/reveal. Mapped across the four tabs below.
4. **Presentation preserved per caller; detail owns its top bar.** Each existing caller keeps its presentation (skill tree keeps `.fullScreenCover`); only the content view changes. `RankDetailView` renders a custom top bar bound to `@Environment(\.dismiss)`, so it works pushed (library, back) or covered (skill tree, close). No reliance on a system nav bar.
5. **Library nav: one NavigationStack, rows push.** Library is presented in a single stack from Home; rows push `RankDetailView(row:)` via `navigationDestination`. The old `.sheet` + `.fullScreenCover` + nested `NavigationStack` + custom `xmark` are removed.
6. **Reuse heavy components.** Ruler (`ProgramRankMetricRuler`), chart (`ProgramRankProofHistoryLineGraph`), muscle figures (`ProgramRankTargetBodyFigure`), equipment strip, guide (`SkillGuideLayerView`/`FormPhaseSlideshow`), tier art (`TierBadge`). New work is layout + IA.
7. **New calm primitives are additive** in `Views/Components/Unbound/` (underline tab bar, calm rank row, non-pill segmented filter).

## Tab -> content mapping (app-wide)

- **Overview:** hero + title, current rank + next gate, logging (skill: sticky action -> session/quickLog; exercise: ruler + reveal overlay), muscle map, equipment, guide (Form/Assist/Tips/Fixes for skills; guide layer for exercises).
- **Rank:** the 9-tier ladder + per-tier criteria (skill `tierCriteria` / exercise ratio ladder), current position, path to next, plus unlocks/requirements (absorbed from SkillDetailView).
- **Stats:** bests/PRs (1RM, reps, hold, distance, calories where supported), total AP, last logged; graceful when a source lacks a stat.
- **History:** chronological log list (revive dead `historyCard`) + trend chart with range selector.

## Proposed File Structure

```
Views/Components/Unbound/
  UnderlineTabBar.swift          (new)
  RankRow.swift                  (new - replaces card-chrome library row)
  SegmentedFilterBar.swift       (new - non-pill filter/scope)
Views/Program/RankLibrary/
  ProgramRankLibraryView.swift   (edit - push nav, earned-first sections, calm rows/filter)
  ProgramRankLibraryModels.swift (edit - earned-first ordering)
  Detail/
    RankDetailView.swift         (new - container, custom top bar, dual init)
    RankDetailViewModel.swift    (new - normalizes node|row -> tab data)
    RankDetailOverviewTab.swift  (new)
    RankDetailRankTab.swift      (new)
    RankDetailStatsTab.swift     (new)
    RankDetailHistoryTab.swift   (new)
Migrated call sites (edit, ~1 line each): UnboundSkillTreeTabView, ClusterStaircaseView,
  HomeTabView (DEBUG), ProgramOverviewView, ProgramRankLibraryDetailViews
Deleted after migration:
  SkillDetailView.swift (+Form, +Guide, +RankPath, +RequirementsAndActions)
  ProgramRankExerciseDetailView.swift (+Sections, +LogControls)
  ProgramRankLibraryDetailViews.swift skill/exercise branch (file may collapse to a pusher)
```

## Dependency Graph

```
Calm primitives (T1)
   │
   ├── Library push-nav skeleton + Home rewire (T2)  ← high risk, fail fast
   │       │   (pushes EXISTING detail container as temporary target)
   │       ├── LIBRARY track ── earned-first (T3) ── calm rows/filter/header (T4)
   │       │
   │       └── DETAIL track ── container+VM dual-init (T5) ── Overview (T6) ┐
   │                                                       ── Rank (T7)     ├ T6-T9 fan-out
   │                                                       ── Stats (T8)    │
   │                                                       ── History (T9)  ┘
   │                                                              │
   │                              Migrate 5 call sites (T10) ─────┘
   │                                       │
   └────────────── Delete old screens + READMEs + tests (T11)
```

LIBRARY track (T3-T4) and DETAIL track (T5-T9) run in parallel after Checkpoint A. T6-T9 are the subagent fan-out (isolated files, share only the T5 VM contract). T10 needs the VM + tabs feature-complete; T11 last.

## Task List

### Phase 1: Foundation + navigation

## Task 1: Calm shared primitives
**Acceptance:** `UnderlineTabBar`, `RankRow`, `SegmentedFilterBar` exist, tokens-only, no capsules, each with a `#Preview` on true-black at AA contrast.
**Verify:** sim build; preview screenshots.
**Deps:** None. **Files:** 3 new. **Scope:** S/M.

## Task 2: Library push-nav skeleton + Home rewire
**Description:** Library in one `NavigationStack`; rows push the EXISTING detail container (unchanged) via `navigationDestination`; remove fullScreenCover/nested stack/xmark; flip Home entry `.sheet` -> push. Add `--unbound-open-rank-detail <id>` launch arg.
**Acceptance:** skill + exercise rows both PUSH; one native back; no second modal; Home opens the push destination.
**Verify:** sim build; screenshot full-screen library + pushed detail, single back.
**Deps:** None. **Files:** `ProgramRankLibraryView.swift`, `ProgramRankLibraryDetailViews.swift`, `UnboundHomeView.swift`, `UnboundHomeView+Controls.swift`. **Scope:** M. **Risk:** high.

### Checkpoint A — review with human
- [ ] Library is full screen; row push works for skill + exercise; one back; no double modal.

### Phase 2: Library presentation (parallel with Phase 3)

## Task 3: Earned-first ordering + sections
**Acceptance:** earned movements first, best tier at top (recency tiebreak); category groups follow; empty "Your Ranks" hides for new users.
**Verify:** sim build; seeded-rank screenshot.
**Deps:** T2. **Files:** `ProgramRankLibraryModels.swift`, `ProgramRankLibraryView.swift`. **Scope:** M.

## Task 4: Calm rows + calm filter + slimmer header
**Acceptance:** no `Capsule()` for nav/filter; rows use `RankRow` (tier glyph + typographic meta); compact header.
**Verify:** sim + device-arch build; screenshot + color check.
**Deps:** T1, T3. **Files:** `ProgramRankLibraryView.swift`, `ProgramRankLibraryRowView.swift`. **Scope:** M.

### Checkpoint B — review with human
- [ ] Library reads calm: no pills, earned-first, compact header; color check passed.

### Phase 3: Unified detail (T6-T9 fan-out)

## Task 5: RankDetailView container + dual-init view model
**Description:** `RankDetailView` with custom top bar (dismiss-bound), `UnderlineTabBar`, and `RankDetailViewModel` normalizing `node|row` -> tab data. Library pushes `RankDetailView(row:)`. Stub tabs. SkillDetailView still present (migrated in T10).
**Acceptance:** pushing any library row shows the 4-tab container; container also constructs from a `SkillNode`; top bar dismisses correctly pushed and covered.
**Verify:** sim build; screenshot container for skill + exercise.
**Deps:** T1, T2. **Files:** `RankDetailView.swift`, `RankDetailViewModel.swift`, `ProgramRankLibraryDetailViews.swift`. **Scope:** M. **Risk:** med (VM contract gates fan-out).

## Task 6: Overview tab
**Acceptance:** logging works for BOTH paths (skill -> session/quickLog; exercise -> ruler + reveal fires); muscle map, equipment, guide render for skill + exercise.
**Verify:** sim build; log a skill and an exercise end-to-end; screenshot.
**Deps:** T5. **Files:** `RankDetailOverviewTab.swift` (+ VM). **Scope:** M (split logging vs about-blocks if >5 files).

## Task 7: Rank tab
**Acceptance:** all 9 tiers + criteria for skill (`tierCriteria`) and exercise (ratio ladder); unlocks/requirements shown; current tier + next gate distinct; no capsules.
**Verify:** sim build; screenshot skill + exercise.
**Deps:** T5. **Files:** `RankDetailRankTab.swift`. **Scope:** M.

## Task 8: Stats tab
**Acceptance:** only movement-relevant stats (no empty distance/calories on a pull-up); numbers match progress data; graceful skill empty state.
**Verify:** sim build; screenshot; spot-check seeded data.
**Deps:** T5. **Files:** `RankDetailStatsTab.swift`. **Scope:** S/M.

## Task 9: History tab
**Acceptance:** entries list + chart render; range selector works; clean empty state.
**Verify:** sim build; screenshot with/without history.
**Deps:** T5. **Files:** `RankDetailHistoryTab.swift`. **Scope:** S/M.

### Checkpoint C — review with human
- [ ] All 4 tabs render for skill + exercise; logging + reveal work; device-arch green; color check.

### Phase 4: Migration + cleanup

## Task 10: Migrate the 5 SkillDetailView call sites
**Description:** Swap `SkillDetailView(node:graph:nodeStates:)` -> `RankDetailView(node:graph:nodeStates:)` at skill tree x2, Program Overview, Home (DEBUG); collapse the library's skill/exercise branch to `RankDetailView(row:)`. Preserve each presentation.
**Acceptance:** skill-tree drill-in, Program Overview drill-in, library (skill + exercise), and `--unbound-open-skill` all show the new detail and dismiss correctly; skill session still launches.
**Verify:** sim build; screenshot each of the 4 surfaces; 3x launch.
**Deps:** T6-T9. **Files:** the 5 call-site files. **Scope:** M. **Risk:** high (cross-surface).

## Task 11: Delete old screens + READMEs + tests
**Description:** Delete `SkillDetailView` (+Form/+Guide/+RankPath/+RequirementsAndActions) and `ProgramRankExerciseDetailView` (+Sections/+LogControls); update touched dir READMEs; `xcodegen generate`; verify team 6K5R25Y398 + HotReloading `weak: true` survive; run README freshness + rank/skill suites.
**Acceptance:** zero references to deleted screens; build + device-arch green; `ReadmeFreshnessTests` + rank/skill suites pass.
**Verify:** full build; `-only-testing:ReadmeFreshnessTests`; rank tests; 3x launch.
**Deps:** T10. **Files:** deletions + READMEs. **Scope:** M.

### Checkpoint D (Complete) — review with human
- [ ] All acceptance criteria met; final screenshots of library + 4 tabs + skill-tree drill-in; color check; ready for PR.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Migration breaks skill tree / Home / Program Overview | High | Drop-in `(node:graph:nodeStates:)` signature; screenshot each surface in T10; 3x launch. |
| New detail must reproduce skill session/quickLog/requirements | High | Absorb SkillDetailView behaviors in T6/T7; port from its source; verify session launches. |
| Detail must serve skill + exercise shapes | Med | `RankDetailViewModel` normalizes; tabs read the VM. |
| SwiftUI metadata-depth crash on device (bigger view) | Med | Each tab in its own file; AnyView-wrap heavy children per prior fix. |
| `xcodegen` wipes team / HotReloading weak | Med | After regen verify team + `weak: true`. |
| Per-tier tints fail AA on true-black | Med | Use `rewardTextTint`; color check gate. |
| RankDetailView dismiss differs pushed vs covered | Med | Bind custom top bar to `@Environment(\.dismiss)` (handles both); test both. |

## Parallelization

- After Checkpoint A: LIBRARY track (T3-T4) and DETAIL track (T5-T9) independent.
- T6-T9 fan out to parallel subagents once the T5 VM contract lands; I own the contract, integration, build, and verification.
- Sequential: T2 (nav contract) and T5 (VM contract) gate dependents; T10 then T11 last.

## Resolved
- Scope: full migration to one app-wide detail (delete `SkillDetailView`).
- Execution: fan out the four tabs after T5.
