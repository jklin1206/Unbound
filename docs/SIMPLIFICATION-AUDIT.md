# UNBOUND Simplification Audit

Current source for the three-agent simplification review. The binary slide deck lives at `outputs/manual-20260601-simplify/presentations/unbound-complexity-audit/output/unbound-simplification-audit.pptx`; this file is the durable text version that can be reviewed and diffed.

## Verdict

The product loop is simple: collect intent, prescribe training, record proof, award progress, adapt the plan, and connect the user to squads. The code becomes hard to review when one file owns several of those jobs at once.

## Component Map

| Surface | Job | Current pressure |
| --- | --- | --- |
| App shell | launch, auth, onboarding/home routing, foreground work | must stay small and boring |
| Onboarding | collect goals, equipment, scan/photo, reveal | flow ordering and validation should be descriptor-driven |
| Home | daily snapshot, next action, scan cards, rank/trial prompts | loader/router/reward/scan cadence are too intertwined |
| Program | plan, routines, schedule, focus, rank trials | biggest UI hotspot; needs typed presentation state |
| Skill detail | education, rank path, guide, quick log, sessions | content library and logging mini-app live inside one view |
| Workout/routine | set logging, timers, completion records | player/controller duplication should collapse |
| Completion/rewards | idempotent ingest, rank/LVL/attributes, reward sequence | core behavior is valuable; split rule owners, not behavior |
| Profile/settings/scan | account, scan proof, debug tools, notifications | production settings and debug panels need a clearer boundary |
| Squads/social | missions, chat, friend challenges, honors | now has architecture doc; keep rule evaluators and backends split |

## Reviewer Lanes

### Maxwell - SwiftUI/Product Flow

Top issues:

- `ProgramOverviewView` is a modal coordinator disguised as a screen. Replace scattered booleans with `ProgramPresentation` and move tabs/sheets into named views.
- `SkillDetailView` owns sheet routing, guide content, rank-path logic, and quick logging. Use one `SkillDetailSheet` enum, move guide data to a library, and move quick logging out.
- `UnboundHomeView` duplicates derived state around scan/reward/trial routing. Introduce `HomeSnapshot` plus typed commands.
- `WorkoutRewardSequenceView` should render a list of `RewardBeat` values instead of page integers and scattered timing helpers.
- `SettingsView` should keep production settings separate from `#if DEBUG` developer tooling.

### Hegel - Domain/Progression

Top issues:

- Canonical rank is cleaner now, but active names still mix `SkillTier`, `RankTier`, and `RankTitle`. New code should prefer `RankTier`; old aliases stay only for compatibility.
- `NodeState` is now locked/proven. Any remaining attempting/achieved/mastered language is legacy decode or stale copy.
- `aggregateTier` and `aggregateRank` are both public and need clearer names: highest unlocked tier vs build-weighted rank.
- AP/XP naming is the next real domain pass. Internal AP fields are a work-ledger compatibility layer; user-facing reward language should be XP.
- Proof and rank evaluation should converge on one standards evaluation result so rewards and persistence do not walk criteria separately.

### Parfit - Repo/Docs/Tests

Top issues:

- `ARCHITECTURE.md` was stale and now owns the current subsystem map.
- Old Firebase V1 code has been archived under `docs/legacy/firebase-v1/` so it no longer looks shippable.
- The generated PPTX now has this markdown source-of-truth.
- `UNBOUNDTests/README.md` now maps test ownership; the remaining cleanup is to split the root smoke/junk-drawer tests into focused files.
- `ONE-METRIC-*` docs are historical. They now point readers back to current architecture docs instead of pretending to be active instructions.

## Roadmap

| Pass | Work | Approval proof |
| --- | --- | --- |
| A - orientation cleanup | active/legacy map, app entry rename, Firebase archive, test map | build plus grep for old active paths |
| B - UI boundaries | Program presentation enum, SkillDetail sheet enum, guide library, debug settings split | focused build/tests plus simulator smoke |
| C - core pipelines | completion receipt store, movement ledger, reward receipt builder, scan cadence policy | idempotency/replay tests stay green |
| D - contracts | sync schema ownership, entitlement naming, squad rule/backend boundaries, asset manifest | sync/security/squad focused tests |

## What Changed In This Pass

- Archived Firebase V1 functions and Firestore rules under `docs/legacy/firebase-v1/`.
- Renamed the app entry file to `UNBOUND/App/UnboundApp.swift`.
- Added architecture deep dives for ranking, skills, movements, logging, progression, levels, attributes, and recovery.
- Added `UNBOUNDTests/README.md`.
- Cleaned active skill-tree vocabulary around locked/proven state.
- Replaced Skill Detail's parallel sheet booleans with one `SkillDetailSheet`.
- Split Skill Detail's guide data, quick-log sheet, and visual resolver into named files.
- Split Settings' debug/player tools out of production settings.
- Split Program's focus-switch sheet and rank library out of `ProgramOverviewView`.
- Split reward-sequence visual components out of `WorkoutRewardSequenceView`.

## Next Recommended Slice

Continue with typed presentation state in `ProgramOverviewView` and a scan/reward snapshot for `UnboundHomeView`. The big file boundaries are now cleaner; the next risk is the scattered routing state that still makes the app harder to explain than the product flow.
