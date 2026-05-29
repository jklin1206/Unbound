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
| 0 | Logging actually records | BLOCKED (B1) | complete() already canonical (most of phase pre-done). Remaining = delete dead saveLog cascade + "unmatched" integrity state (needs UX decision + legacy-screen reachability check). |
| 1 | One LVL | ✅ DONE (`b0dbbf4`) | Re-sourced to AP-derived OverallLevel; unbound.gains deleted (grep 0). Photo/routine/scan LVL drop flagged (D1). |
| 2 | One rank ladder (kill E–S) | PARTIAL (`212a40c`) + BLOCKED (B2) | MuscleGroupTier trio deleted. SubRank/SkillRank load-bearing → cadence balance decision needed. |
| 3 | Rank every movement by template metric | BLOCKED (B3) | Needs external public bw-relative strength dataset. LiftTierCriteria can't go until then. |
| 4 | Skill tree placement = difficulty weight | PARTIAL (`212a40c`) | .new dupe deleted. SkillLevel (680 refs) deletion is high fan-out — staged, not started. |
| 5 | Attributes: one number + hard-to-max hex | BLOCKED (B4) | Hex curve steepness = balance decision. |
| 6 | Rename AP → XP; split jobs | NOT STARTED | Safe part = user-facing "AP"/"Ascension Points" → "XP" rename. Ledger-as-rank-input removal depends on Phase 3 (blocked). |
| 7 | Overall rank = accumulation + Ascension | BLOCKED (B5) | Ascension ceremony = design decision; largest surface. |
| 8 | Docs + file-structure | NOT STARTED | Build ARCHITECTURE.md map + report. Safe to do. |

## Decisions made (record every non-trivial call here)
- **D1 — Phase 1 LVL source = OverallLevelProgress, legacy counter deleted wholesale (Option A, not re-routed).** Plan uses explicit DELETE language ("delete unbound.gains + every read/write"). Per Simplicity/Surgical discipline I follow it literally rather than inventing an unrequested re-route of photo/routine/scan XP into OverallLevel. **Consequence (FLAGGED for jlin):** daily-photo (+5), scan (+25), routine (+spReward), and node-unlock gains will NO LONGER grant LVL. LVL becomes purely the AP-derived OverallLevel fed by logged workouts via `complete()`. If you want those activities to keep granting LVL, that's Option B (route them through `OverallLevelService` ingest) — say so and I'll do it.
- **D2 — The flat +30/session increment + session gains-toast are ALREADY DEAD** (`onSessionComplete()` has zero callers; `beginTodaySession()` at line 367 is the live entry and does not call it). So deleting them is dead-code removal, not behavior change. Phase 1 deletes `onSessionComplete()` + the toast machinery it solely drove (`showingGainsToast`, `gainsToast`, `lastGainsAwarded`) — VERIFY lines 1378-1400 aren't a separate live card before deleting.

## Phase 1 — VERIFIED EXECUTION SPEC (ready to run; achieves goal + grep-zero)
Goal: user-visible level == AP-derived OverallLevel. Today the displayed level reads from `unbound.gains` (`(gains/250)+1`), disconnected from logged training (which feeds `OverallLevelProgress` via `complete()`). Fix = re-source displays + delete the counter.
Edits:
1. `UnboundHomeView.swift`: replace `@AppStorage("unbound.gains") gains` (L34) with `@State var overallLevel: OverallLevelProgress?`; delete `xpPerLevel` (L91). Add computed helpers: `lvlValue = overallLevel?.level ?? 0`, `lvlFraction = overallLevel?.progressToNextLevel ?? 0`, `lvlXPInLevel = Int(totalXP - OverallLevelCurve.xpRequired(forLevel: level))`, `lvlXPForLevel = Int(xpRequired(forLevel:level+1) - xpRequired(forLevel:level))`, `lvlTotalXP = Int(overallLevel?.totalXP ?? 0)`. Re-point sites L249, L419-421/444, L543-545, L765-766, L875("banked"→lvlTotalXP). In `load()` (L1426) fetch: `overallLevel = (try? await services.database.read(collection:"overall_level_progress", documentId:userId)) ?? OverallLevelProgress(userId:userId)`. Delete dead `onSessionComplete()` (L1625) + toast machinery.
2. `ProfileView.swift`: same re-source at trophyHeader (L271-273); delete `@AppStorage("unbound.gains")` (L59) → `@State overallLevel` + fetch in its load.
3. `SkillProgressService.swift`: delete `awardGains(_:)` (L639-642) + its 3 call sites (L167, L192, L305). Keep `NodeUnlockedEvent.gainsAwarded` (per-event display number; reframed to XP in Phase 6).
4. `PhotoXPService.swift`: sole purpose is the `unbound.gains` write. DELETE the service + protocol + `MockPhotoXPService`; remove `photoXP` from `ServiceContainer` (L31/71/111/139/180) + 3 call sites in `PhotoCaptureFlow.swift` (L418/456/489).
5. `RoutineHistoryStore.swift`: delete the gains bump (L51-52 + `gainsKey` L15); keep cooldown + history. Callers in `ProgramOverviewView` (L3677/4106) use the Bool return — unaffected.
6. `SettingsView.swift`: remove `gainsKey` dev seed (L1184 + usage).
Verify: `grep -rn '"unbound.gains"' UNBOUND` → 0. Build + 990 tests green. senior-code-reviewer pass. Then commit (Phase 1) + push.
SAFETY NOTE: legacy `WorkoutLoggingView` path (recordProgressionForLegacyWorkout) does NOT feed OverallLevel — if that screen is still a primary logger, LVL won't move for those sessions (Phase 0 gap). 6 modern paths DO feed it.

## Blockers (for the morning report)
- **B1 (Phase 0):** legacy `WorkoutLoggingView` → `recordProgressionForLegacyWorkout` is intentionally side-effect-free (no OverallLevel/skill/rank ingest). If that screen is still reachable as a real logger, those sessions silently don't count. Plan's "unmatched — won't count" integrity state also not yet built (needs UX decision). VERIFY reachability + decide.
- **B2 (Phase 2):** `SubRank` (109 refs) is load-bearing — surfaced in Home (`aggregateRank: SubRank`), drives StrengthStandards/PR-detection/attribute rank-up cadence. Deleting = coarsening rank-up cadence 18→9 steps = **game-balance decision**. `SkillRank` (10 live consumers incl. Views + RewardComputer) also real surgery, not the "dead" the audit claimed. NEEDS jlin's call on cadence.
- **B3 (Phase 3):** bodyweight-relative standards require curating an EXTERNAL public strength dataset (StrengthLevel-style) for all weighted movements. Data-sourcing + licensing decision. `LiftTierCriteria` (absolute kg) can't be deleted until the ratio standards exist.
- **B4 (Phase 5):** hex XP→level curve steepness is a **balance decision** ("genuinely hard to max", grow-from-tiny). Needs target calibration (how long should max take?) from jlin.
- **B5 (Phase 7):** Ascension ceremony design (tiered gauntlets, eligibility gates) is a **product/design decision**, largest surface.

## Commits / pushes / deploys
- `212a40c` (pushed to main) — Phase 2 partial (delete orphaned MuscleGroupTier rank trio) + Phase 4 partial (delete stale SkillTreeContent.swift.new). No Supabase change → no deploy. Tests 990/0.
- `b0dbbf4` (pushed to main) — Phase 1 DONE (one LVL: re-source Home+Profile to AP-derived OverallLevel, delete unbound.gains counter + all reads/writes incl. PhotoXPService, awardGains, routine bump, +30/session). No Supabase migration (uses existing `overall_level_progress` collection) → no deploy. Tests 990/0. Independently re-verified (build + test + grep + diff review).

## Test runs
- Baseline: 990 tests, 0 failures, 8 skipped ✅
- After `212a40c`: 990 tests, 0 failures, 8 skipped ✅
- After `b0dbbf4` (Phase 1): 990 tests, 0 failures, 8 skipped ✅ (re-verified independently)
