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
| 0 | Logging actually records | ✅ DONE (`a24529a`) | complete() canonical (pre-done). Added live "Won't count toward rank or XP" badge on unmatched exercises (ExerciseLogCard + CustomExerciseBuilderView). Deleted dead WorkoutLoggingView/VM/SetLogRow + saveLog cascade + recordProgressionForLegacyWorkout. 972 tests. |
| 1 | One LVL | ✅ DONE (`b0dbbf4`) | Re-sourced to AP-derived OverallLevel; unbound.gains deleted (grep 0). Photo/routine/scan LVL drop flagged (D1). |
| 2 | One rank ladder (kill E–S) | ✅ SubRank DONE (`c5237a7`); SkillRank → Phase 4 | MuscleGroupTier trio deleted (`212a40c`). SubRank deleted, RankTier sole ladder, 18→9 reviewed. **SkillRank FINDING:** it's the per-node intrinsic *difficulty* bucket (Dormant/Awakened/…/Ascended + taglines + colors), NOT the rank ladder — that's Phase 4's placement concept. 6 buckets don't map cleanly to RankTier's 9 tiers. Deleting needs the Phase 4 placement decision + copy re-homing. Moved to Phase 4. |
| 3 | Rank every movement by template metric | ✅ DONE (`1316aad`) | StrengthLevel bw-relative ratios, 5 compounds + 8 accessory families (male+female), unranked set, DB×2 rule. LiftTierCriteria + dead ladder engine deleted. App logs TOTAL load (verified). 986 tests. |
| 4 | Skill tree placement = difficulty weight | PARTIAL (`212a40c`) | .new dupe deleted. SkillLevel (680 refs) deletion is high fan-out — staged, not started. |
| 5 | Attributes: one number + hard-to-max hex | ✅ DONE (`6428420`) | AttributeValue→{xp,lastContributionAt}. Curve 16·L^2, max100, linear hexFill; ~3yr balanced/~6yr focused (heavy). Per-axis catch-up multiplier (build-revealing, balance is efficient). Deleted 0-100 scale/duplicate rank/display trick/decay. 979 tests. |
| 6 | Reward beat: "+X XP" + "% to next rank" | NEXT (Phase 3 done → unblocked) | **GOAL (jlin reframe):** the real question is "does the user feel REWARDED for the exercises they did after a workout, with a % to the next rank." Not a rename — the post-workout reward sequence (WorkoutRewardSequenceView) shows per-exercise **+X XP** and a derived **"X% → [next rank]"** bar (current best vs next RankTier threshold via StrengthStandards, computed not stored) + the rank-up moment on crossing. AP→XP rename is the surface; the reward UX is the deliverable. Eyeball in-app (UX). |
| 7 | Overall rank = accumulation + Ascension | ✅ DONE (`d73a611`) | aggregateRank = build+difficulty-weighted mean w/ decay + ≥4 coverage guard. Two-gate eligibility (accumulation + minOverallLevel). Tiered ceremony: auto-confirm (Novice/Apprentice) / benchmark (Forged/Veteran) / gauntlet (Master+). Omni-max gates deleted; minOverallLevel kept; highestPassedRank = claimed (never demotes) drives cosmetics. 974 tests. NOTE: barbell-compound difficulty fixed=6 (interpretive, one-line change). |

## ROLL STATUS (2026-05-29) — ✅ COMPLETE (all 8 phases shipped)
All 8 phases (0–8) + D1 shipped to main, 972 tests green, every balance/design call jlin-checkpointed. Deferred (logged, non-blocking): skill-tree "stars" difficulty redesign + NodeState collapse + kill "mastered"/per-node Lv1-5 ladder (jlin's focused-UI-pass call); 2 tier-monotonicity flags (cl.hanging-leg-raise, cl.german-hang); internal AP-symbol rename (cosmetic, non-user-facing).

### (historical) prior note — CORE COMPLETE
SHIPPED to main (18 commits): Phase 1 (one LVL), Phase 2 (SubRank deleted + Unbound-peak swap), Phase 3 (StrengthLevel standards), Phase 5 (hex one-number + catch-up), Phase 7 (accumulation + Ascension), Phase 8 (ARCHITECTURE.md), D1 (photo/scan/routine LVL), dead-code purge. All build-green + full-test-verified + jlin-checkpointed on every balance/design call.
REMAINING (mechanical/low-risk, not blocking): Phase 6 (AP→XP rename + derived "% to next rank" — the ledger UI reframe), Phase 4 (SkillLevel 680-ref deletion + SkillRank→placementRank), Phase 0 ("unmatched — won't count" integrity UX + retire legacy WorkoutLoggingView path).
| 8 | Docs + file-structure | PARTIAL — `ARCHITECTURE.md` shipped | Map written (subsystem→code→planned doc). Did NOT delete superseded docs (premature — model not yet unified). Model-file regrouping deferred until Phase 2/3 land. |

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

## jlin's decisions (2026-05-29, resolved — now actionable)
- **D1 → Option B:** photos + scans (+ routines, same category) should grant *a bit* of LVL. Re-route through `OverallLevelService.ingest` (canonical source), NOT a revived counter. Amounts tunable (start photo 5 / scan 25 / routine spReward). Dedup via sourceLogId.
- **B2 → GO:** delete `SubRank` + `SkillRank`; 18→9 rank-up cadence accepted. (Phase 2)
- **B3 → StrengthLevel** (strengthlevel.com/strength-standards) is the bodyweight-relative dataset source. Unblocks Phase 3 + downstream Phase 6 AP→XP/% rename.
- **B4 → hex maxes in YEARS**, but fills *faster the harder/more often the user trains* (steep top-end curve; rate scales with training volume). (Phase 5)
- **B5 → Ascension ceremony: improve but keep SIMPLE.** Propose a concrete simple redesign at Phase 7 for thumbs-up; latitude given.

## Brand decision — Unbound is the peak (shipped `1981104`)
Council (4 lenses, ~unanimous): the eponymous word must be the summit. LABEL-ONLY swap — RankTier.displayName peak(.ascendant rawValue 8)="Unbound", tier7(.unbound)="Ascendant". Case names/rawValues/tokens/persistence/badge-art all unchanged. Fixed the ~4 ordering-encoded copy spots (skin hints, trial gate subtitles, onboarding label) + test. FOLLOW-UP flagged: ContentNotificationCatalog rank-up sequence has pre-existing ordering quirks + the "top 5%" superlative now belongs to Unbound — needs a holistic pass.

## Phase 3 decisions (jlin) + status
- Scope = **rank everything loaded** (build the C.3 family-default curves for accessories too; ratios are flagged estimates, tunable).
- Defaults taken (not objected): O1 5→9 anchoring (Beg=novice…Elite=ascendant), O4 male-default when sex nil, O5 dumbbell→barbell-parent table.
- Proposal: docs/PHASE3-STANDARDS-PROPOSAL.md. STILL NEEDS: jlin's go on the ratio table itself (the "tiers feel off" was the naming, now resolved) before wiring. Then implement (encode compounds + family-defaults + delete LiftTierCriteria + dead MovementTierStandard/MovementStandardLadder + re-point 4 readers to pass bodyweight), verify, push.

## Phase 3 — FULLY APPROVED, implementing
jlin approved: compound ratios (StrengthLevel, 5→9 anchoring, overwrite existing 4) + ALL 9 accessory families (docs/PHASE3-ACCESSORY-RATIOS.md, all StrengthLevel-sourced). Decisions: drop difficulty multiplier; per-family female bands (gap 0.67–1.0, not flat 0.55); DB-curl ×2 rule (per-hand→total); UNRANKED set = lateral/front/upright raise, glute kickback, hip abd/add, pallof press, landmine rotation, KB swing. Verify O-A1 (total-bar vs added-plates logging) in CODE before wiring (shifts F8 hip-thrust/F6 calf). Delete LiftTierCriteria + dead MovementTierStandard/MovementStandardLadder/tierStandards + re-point ExerciseLibraryViewModel/ProfileView/SettingsView readers (pass bodyweight). Gate: build+990 tests+grep LiftTierCriteria=0 & MovementTierStandard=0. Checkpoint diff to jlin before push.

## Phase 5 — decisions (jlin) + plan
- Curve: one scale/axis `xpRequired(L)=28·L^2.0`, maxLevel 100, hexFill=L/100 (proposal default; ~4.5yr heavy to max a FOCUSED axis, tunable). Starts tiny slivers.
- Collapse: AttributeValue → {xp, lastContributionAt}. DELETE 0-100 current/peak scale, duplicate AttributeValue.rankTier/rankTitle (keep levelRankTitle→rename rankTitle), hexDisplayValue/prestige-glow trick, legacyScoreXPScale/xpAwarded/legacyXP/apXPToDisplayScoreScale bridge, softcap branch, peak-relative AttributeDrift decay. Seed = L0 (plan: everyone starts zero). hexFill linear/honest.
- **NEW (jlin chose build-revealing + catch-up):** add a PER-AXIS catch-up multiplier — neglected axes (below your hex mean) earn bonus XP; over-fed axes near cap earn diminishing XP. Hex reveals build BUT power can't trivially pin + weakness-work is rewarding. Scheme: mult = clamp(1 + k·(meanLevel − axisLevel)/maxLevel, ~0.5, ~2.0) + a near-cap brake (>L90 ×0.5). Tunable. (This is the per-AXIS analog of the body-region novelty multiplier that already exists.)
- Checkpoint: bring jlin a REVISED projection (with catch-up modeled) before push. Then verify + push.

## Phase 4 — split (jlin) + DEFERRED redesign
SHIPPING NOW (mechanical, approved): delete dead `SkillLevel` type + `node.levels` + 675 data-file entries + Lv1-5 criterion copy (D1: drop, rely on tierCriteria/fallback); add `SkillNode.placementRank` (D3: tier N → RankTier rawValue N) as the canonical node-difficulty number. Strike MovementDifficulty (plan misclassified it — it's the live XP weight Phase 7 keeps). D4: report tier-vs-prereq monotonicity violations, don't re-author.
DEFERRED to a focused UI pass (jlin's "Overcooked-stars" instinct): replace `SkillRank`'s bespoke E–S bands + Dormant/Awakened/… copy with a SIMPLE difficulty rating (stars/dots from tier); collapse `NodeState` to locked/proven; KILL "mastered"/the 2× + the per-node Lv1-5 `SkillProgress.currentLevel` ladder (jlin: "what even is mastered" — buried cruft tied to a parallel ladder). These are visual/behavior changes that want eyes on the staircase, not a blind sweep. SkillRank stays as harmless legacy flavor until then (no longer a competing metric once placementRank is canonical).

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
- After `4602491` (D1): 990 tests, 0 failures ✅
- After `71727bf` (Phase 8 docs): n/a (docs only)
- After `c5237a7` (Phase 2 SubRank teardown): 990 tests, 0 failures, 8 skipped ✅ (independently re-verified, no count delta; checkpoint-reviewed by jlin)

## Commits (continued)
- `4602491` — D1 photos/scans/routines → OverallLevel grants. No deploy.
- `71727bf` — Phase 8 ARCHITECTURE.md map. Docs only.
- `c5237a7` — Phase 2: SubRank deleted, RankTier sole ladder (18→9). No migration (SubRank was never persisted). Pushed to main.
