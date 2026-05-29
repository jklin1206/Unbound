# ONE METRIC — Autonomous Execution Log

**Goal:** Execute as much of `docs/ONE-METRIC-CLEANUP-PLAN.md` as possible, overnight, autonomously.
**Started:** 2026-05-29 (overnight run, self-paced via /loop + ScheduleWakeup).
**Push policy (jlin, durable auth):** FULL PROD each phase — commit + push to `main` AND deploy Supabase migrations/functions to prod per phase, unattended. No users exist → git revert + forward migration is the safety net.

## Operating rules (every loop iteration: read this file first, then resume)
1. **Gate before every commit:** `xcodegen generate` → build green → full test suite green. No green = no commit. Record the command output summary here.
2. **Atomic commit per phase** (or per coherent sub-step if a phase is large), with the Co-Authored-By trailer. Push to `main` immediately. Deploy Supabase if the phase added migrations/functions.
3. **Delete old impl + its wiring in the SAME commit** (the doc's standing rule). Never park dead code "for safety." git is the safety net.
4. **Do NOT delete load-bearing code blindly.** Before deleting a symbol the plan lists, prove zero live consumers (grep). If it's load-bearing, the deletion is a real refactor — do it only if unambiguous; otherwise log a BLOCKER.
5. **Balance / external-data / design decisions are BLOCKERS, not guesses.** SubRank cadence (18→9), the bw-relative strength dataset, hex curve steepness, Ascension ceremony design — implement the unambiguous parts, log the judgment calls for jlin.
6. **Review everything:** after each phase's code is written, run a senior-code-reviewer pass (Agent) before committing. Persistence phases (0, 2, 7) additionally get a live rollback test where a migration is involved.
7. **Limits/context:** when running low, ScheduleWakeup with the same /loop prompt (delay sized to limit reset) so the run resumes. Update this log before sleeping so the next iteration has full state.
8. **End condition:** all feasible phases done OR all remaining work is blocked. Then generate the HTML slideshow report (`docs/one-metric-report.html`): changes made, tests run, blockers.

## Baseline (ESTABLISHED 2026-05-29 ~03:34) — GREEN ✅
- [x] `xcodegen generate` succeeds
- [x] Build succeeds (scheme UNBOUND, Debug) — exit 0
- [x] Full test suite: **990 tests, 0 failures, 8 skipped** in ~6s (regression oracle)
- Test destination: `platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D` (iPhone 17, booted)
- Test/build commands:
  - `xcodegen generate`
  - `xcodebuild build-for-testing -project UNBOUND.xcodeproj -scheme UNBOUND -configuration Debug -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' -quiet`
  - `xcodebuild test-without-building -project UNBOUND.xcodeproj -scheme UNBOUND -configuration Debug -destination '...id=810087B3...'`
- **Note:** tests are ~6s; build is the bottleneck (~min). Batch where safe.

## Ground-truth corrections to the plan (discovered during audit)
- **Phase 0 mostly done already:** `complete()` is canonical (wires progression/rank/skill-tier/trials/streak/cosmetics/ProofEngine). `recordProgressionForLegacyWorkout` is *intentionally* side-effect-free. Remaining = delete the truly-dead `saveLog` cascade + add "unmatched — won't count" integrity state.
- **`unbound.gains` is NOT a dead counter — it's the live LVL XP store**, fed by routine completions (`RoutineHistoryStore`), daily photos + scans (`PhotoXPService`), and node unlocks (`SkillProgressService.awardGains`). `OverallLevelProgress` is XP-derived from *logged workouts only* (does NOT capture photos/routines/scans). → Phase 1 fork: deleting `unbound.gains` per plan = photos/routines/scans stop granting LVL. (DECISION/BLOCKER, see below.)
- **`SubRank` (109 refs) is load-bearing** — surfaced in `UnboundHomeView` (`aggregateRank: SubRank`), drives StrengthStandards/PR-detection/attribute rank-up cadence. Phase 2 "delete SubRank" = balance-changing surgery (18→9 cadence). BLOCKER.
- **`SkillRank` (10 live consumers incl. Views + RewardComputer)** — audit's "dead" was WRONG. Real surgery, not cleanup.
- **`MuscleGroupTier` trio is fully orphaned** (zero external consumers) → clean Phase 2 deletion. ✅
- **`SkillTreeContent.swift.new`** (336KB) unreferenced, git-tracked → safe delete. ✅

## Phase status
| Phase | Title | State | Notes |
|---|---|---|---|
| 0 | Logging actually records | NOT STARTED | complete() already canonical per audit; remaining = delete dead saveLog cascade + add "unmatched" integrity state. Verify, don't assume. |
| 1 | One LVL | NOT STARTED | Core merge done; remaining = delete `unbound.gains` (10 refs) + surface OverallLevel on Home/Profile + standardize "LVL" label. |
| 2 | One rank ladder (kill E–S) | NOT STARTED | RISK: SubRank load-bearing (109 refs, drives rank-up cadence). SkillRank(22)/MuscleGroupTier(21) likely deletable. |
| 3 | Rank every movement by template metric | NOT STARTED | Needs public bw-relative strength dataset (external data → likely BLOCKER for the dataset curation). Delete LiftTierCriteria/MovementTierStandard. |
| 4 | Skill tree placement = difficulty weight | NOT STARTED | Delete SkillLevel(680 refs — high fan-out)/node.levels, MovementDifficulty axis, SkillTreeContent.swift.new dupe. |
| 5 | Attributes: one number + hard-to-max hex | NOT STARTED | Hex curve steepness = balance decision → BLOCKER for calibration. |
| 6 | Rename AP → XP; split jobs | NOT STARTED | Mostly mechanical rename + derived "% to next rank". |
| 7 | Overall rank = accumulation + Ascension | NOT STARTED | Largest design surface; Ascension ceremony = design decision → BLOCKER. |
| 8 | Docs + file-structure | NOT STARTED | Build ARCHITECTURE.md map, regroup model files, delete superseded docs. |

## Decisions made (record every non-trivial call here)
- (none yet)

## Blockers (for the morning report)
- (none yet)

## Commits / pushes / deploys
- (none yet)

## Test runs
- (none yet)
