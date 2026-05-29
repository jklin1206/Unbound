# Workstream B2 — "Wired in, never triggered" · Remediation Report

**Date:** 2026-05-28
**Coordinator:** main session · **Workers:** 4 parallel isolated-worktree subagents + 1 squad loop-closing round + 3-reviewer council
**Result:** ✅ All 6 B2 issue-groups addressed, proven, integrated to `main` (local; not yet pushed/deployed).

> Scope note: This session executed **B2** (the parallelizable "wired in, never triggered" half) plus the mandatory impact-radius pass over **B1**. **B1** (the shared progression/ranking/program-generation engine — load-bias, velocity layer, rank decay, trials+peak-gating, skill auto-proof, auto-deload) remains for a focused **sequential** phase; see the handoff at the end.

---

## Impact-radius pass (kickoff "first move #2")

4 read-only Explore agents mapped every B2/B1 issue to files+symbols and produced the collision map. Key outcomes:
- **B1 cannot be parallelized** — 5 hot shared files (`ProgressionState`, `CheckpointSignals`, `ArcGenerator`, `ProgramPhaseEngine`, `RankService`) are touched by multiple B1 concerns. B1 stays sequential.
- **Correction to a WS-C assumption:** the note claiming "gate trials on attribute PEAK already landed" is **false** — `OverallRankTrialService.swift:~1848` reads `.current`, not `.peak`. Peak-gating is unbuilt and folds into the B1 "Trials ignore skills" item.
- **B2 is mostly separable** except the squad sub-issues, which collide on `SquadActivityService` + the squad cron — so they were done by one worker, not three.

---

## Orchestration model

Each worker ran fully isolated (own worktree off `main`, own branch, own simulator, own DerivedData), TDD with a falsifiable proof, structured return. Coordinator merged + integration-tested + (for the data-layer worker) ran council + a live rollback test.

| Worker | Branch | Simulator | Issue group |
|---|---|---|---|
| badges | `fix/ws-b-badges` | UNBOUND-wsb-badges | Badge catalog ↔ service mismatch |
| home | `fix/ws-b-home` | UNBOUND-wsb-home | Home bell + Daily-Quest inert |
| loggers | `fix/ws-b-loggers` | UNBOUND-wsb-loggers | Frozen 5→5 grades + dual loggers |
| squads | `fix/ws-b-squads` | UNBOUND-wsb-squads | Linked-session bonus + squad titles + missions/challenges |

---

## What each worker did

### 1. Badges — catalog ↔ service mismatch (S)
**Root cause:** `BadgeService` emitted 15 ids absent from `BadgeCatalog`, so `BadgeCatalog.byId[id]` returned nil and those unlocks were silently dropped before persist/notification.
**Fix:** all 15 had live, intentional triggers → added catalog entries (matching existing rarity convention); introduced `BadgeService.awardableIds` as the single source of truth so the contract is enforceable. Now exact set equality (40 = 40).
**Files:** `BadgeCatalog.swift`, `BadgeService.swift`, `BadgeCatalogReconciliationTests.swift`.
**Proof:** RED (2/4 fail listing the exact 15 missing ids) → GREEN (4/4: awarded⊆catalog, catalog⊆awardable, set-equality, no dupes).

### 2. Home — bell + Daily Quest inert (M)
**Root cause:** bell was an explicit no-op; Daily Quest rendered `DailyQuestPlaceholder.sample` while its start button launched a different hardcoded `SideQuestLibrary.pushProtocol` (display ≠ action).
**Fix:** bell now presents the **already-built** `NotificationSettingsView` as a sheet (promoted `private`→internal — real destination existed). Daily Quest card + start action now both read the same real `SideQuest` (`activeRoutine`); placeholder deleted; the displayed XP is sourced from the real entry. Divergence is structurally impossible.
**Files:** `UnboundHomeView.swift`, `SettingsView.swift`.
**Proof:** `** BUILD SUCCEEDED **` + Home screenshot (`home-proof.png`). No test added (pure navigation + single-source state — a test would be speculative).

### 3. Loggers — frozen 5→5 grades + dual loggers (M)
**Root cause (both real):** the legacy `WorkoutLoggingViewModel` flush routed through `TrainingCompletionService.recordProgressionForLegacyWorkout()` → the same `MovementProgress/BodyMap/Attribute/OverallLevel` sinks the canonical `complete()` writes → **double progression award**. And `ScanComparisonService` stamped a neutral `BodyPartDelta(before:5, after:5)` onto all 6 body parts of every persisted `ScanDeltaReport` → dead "5→5" grades upserted into 12 columns.
**Fix:** legacy path now calls the side-effect-free `previewProgression()` (receipt still renders; nothing persists). `ScanDeltaReportRow` grade columns made optional and written `nil`.
**Files:** `TrainingCompletionService.swift`, `ScanComparisonService.swift`, + 2 test files.
**Proof:** RED (5 failures: legacy flush wrote to each progression collection) → GREEN (10 + 1 tests); regressions re-run green (MovementProgress 22, draft-store 3, scan-checkpoint 3).

### 4. Squads — linked-session bonus + squad titles + missions/challenges (M×3)
Built first as machinery (all unit-green), then a **3-reviewer council** found the loops didn't actually close in production. A second focused round closed them.

**A) Missions — FULLY CLOSED.** `recordProgress` was only reachable from the legacy logger (now neutered). Re-wired into the canonical `TrainingCompletionService.complete()` cascade with an idempotency set (`recordedSquadProgressLogIds`). Server increment via the new RPC.
**B) Friend challenges — FULLY CLOSED.** `evaluateExpired()` now runs on `scenePhase .active`, made idempotent with a `where winner_user_id is null` guarded UPDATE + claim-check before posting.
**C) Cron `week_iso` bug — FIXED.** `evaluate_squad_mission` emitted the **calendar** year; RPC + client use the **ISO** year-of-week. Diverged ~1 week/year (Dec/Jan), silently killing missions. Extracted a pure `iso_week.ts` deriving the year from the Thursday-shifted date; deno test 3/3 (boundary cases + 5-year lockstep).
**D) Linked-session bonus — PARTIALLY CLOSED (documented gap).** New `SquadLoopReconciler` fetches the user's new `linked_sessions` on squad load, dedupes via a persisted processed-id set, and fires `handleLinkedSessionDetected`. **Residual:** true per-session base XP is unrecoverable from the row (the table stores no log id / XP), so it uses the same fixed `baseSessionXP=10` proxy the affinity path already uses. Exact bonus requires `detect_linked_sessions` to persist the originating log id/XP — explicit deferred item.
**E) Squad titles — PARTIALLY CLOSED.** `squadStreakWeeks` + `linkedSessionsCount` counters now feed `applyCounterUpdate` from real observation points; `SquadDetailView` renders awarded titles via `SquadTitleBadge`. **Deferred (not fabricated):** `collectiveAxisRankUps` + `affinityTenureMonths` have no aggregation source — left 0 with a TODO.
**Bonus fix:** caught + fixed an `EXC_BREAKPOINT` launch crash from a `SquadService↔SquadLoopReconciler↔SquadActivityService` static-init cycle (lazy resolution).
**Files:** `SquadActivityService(+Protocol).swift`, `SquadTitleService.swift`, `SquadLoopReconciler.swift`, `SquadLoopStore.swift`, `SquadBackend(+Protocol)/MockSquadBackend.swift`, `SquadMissionService.swift`, `FriendChallengeService.swift`, `TrainingCompletionService.swift`, `SquadDetailView.swift`, `AniBodyApp.swift`, `evaluate_squad_mission/{index,iso_week,iso_week_test}.ts`, migration `20260528000004_squad_mission_progress_rpc.sql`, + 4 Swift test files.
**Proof:** 43 squad-suite tests green; deno 3/3.

---

## Council + live test (data-layer mandate)

The squad worker touched Supabase (a new RPC + the cron edge fn), so per the project rule it got the WS-A treatment:
- **Council (3 independent reviewers):** security, correctness, integration. Caught 2 blockers (cron `week_iso`; `recordProgress` off the real path) + the "machinery-built-but-untriggered" gaps that unit tests passed over — all addressed above.
- **Live RPC rollback test** (`supabase db query --linked`, `BEGIN … ROLLBACK`, nothing persisted): `ALL-GUARDS-PASS` — authenticated non-member rejected (`is not a member`), `delta=999` rejected (`out of range`), service-role valid delta no-ops cleanly (compiles under `search_path=''` against the real catalog), and `rpc_week_iso = 2026-W22` matches the Swift client format.

---

## Integration (coordinator)

- Zero file overlap across all 4 branches → zero merge conflicts.
- Combined `build-for-testing` green; combined proof + regression suites: **0 failures**.
- Merge order to `main`: badges → home → loggers (verified clean), then squads (after council + live test). Squads was rebased onto the post-loggers `main` so its `recordProgress` wiring targets the canonical completion path.
- Final build gate on `main`: `** TEST BUILD SUCCEEDED **`.

`main` is **ahead of `origin` and NOT pushed; nothing deployed.** (Per the user's push/deploy-only-when-asked rule.)

---

## Deploy steps that remain (await approval — outward-facing)

Project `xwoemvkzrnnsvtupxctu` (Unbound):
1. `supabase db push` — applies migration `20260528000004_squad_mission_progress_rpc.sql` (the mission-progress RPC; live-tested via rollback, not yet applied).
2. `supabase functions deploy evaluate_squad_mission` — ships the cron `week_iso` ISO-year fix.

Both are additive + fail-safe; until deployed, mission progress simply doesn't advance (the prior status quo).

## Deferred follow-ups (explicitly out of scope, documented not faked)
- **Linked-session exact bonus:** persist the originating log id / base XP on the `linked_sessions` row (in `detect_linked_sessions`) so the +20% is exact rather than the `baseSessionXP=10` proxy.
- **Squad-title counters:** build aggregation for `collectiveAxisRankUps` + `affinityTenureMonths` (the other two title categories).
- **RPC anti-cheat:** mission progress trusts client +1 with no per-event idempotency. Verified acceptable today (completion grants nothing abusable — cosmetic feed row only); add event attribution before mission completion ever grants a real reward.

---

## Remaining: B1 — "computed but never applied" (next focused session, SEQUENTIAL)

Per the impact-radius pass, B1 must be done sequentially (shared engine). Recommended order (heaviest first is the **velocity layer** — the teardown's central finding: rank is currently pure volume, ability is invisible):
1. **Velocity / LV layer** — rank-up boluses + skill/compound/comeback multipliers; new service hooking `RankService.evaluateTierCrossings`.
2. **Rank decay / honest signal** — `isStale` flag + recent-vs-lifetime (today `RankDecayService.applyDecay` is a no-op; `AttributeValue` has `peak`/`current` but no staleness).
3. **Checkpoint load-bias + auto-deload/peaking** — heavily interdependent (`ArcGenerator` + `ProgramPhaseEngine` + `CheckpointSignals` + `PlateauDetector`/`DeloadPlanner`); the bias is computed (`ArcGenerator.swift:~113`) but only drives rationale copy, never sets/reps/RPE.
4. **Trials skill-gating + PEAK-gating** — both in `OverallRankTrialService` (single file); add path-aware "any N of" skill gates AND switch the attribute read from `.current` to `.peak`.
5. **Skill auto-proof hold/carry** — `SkillProgressService.requirementMet` returns false for `.hold`/`.carry`; detect `holdSeconds`/`distanceMeters` from logged sets to auto-advance nodes.

---

## Verdict

**6 / 6 B2 issue-groups: addressed with falsifiable proof, integrated to `main`, zero conflicts, full combined suite green.** The squad data layer additionally cleared a 3-reviewer council + a live rollback test, which caught real loop-closing gaps unit tests missed (and a launch crash). Two squad sub-loops land with explicitly documented, non-faked deferrals. **B2 done; B1 (sequential engine work) is the next focused effort.**
