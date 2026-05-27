# UNBOUND Training System 8.5 Approval Plan

Status: hard execution plan
Baseline artifact: `LocalArtifacts/year-simulation-merged-20260525-184726`
Goal: all three reviewer lenses rate the program/coaching system at least 8.5/10.

## 2026-05-26 Stricter Package Goal

New target: reviewers grade against a 9.5/10 premium-coach bar, not the original 8.5 approval bar.

The system should feel like a well-rounded training product, not just a program generator with good art. The package must prove:

- Year-long programming distinguishes direct hard sets, secondary exposure, skill/isometric practice, mobility/control work, and joint/tendon stress.
- Body-region math from the progression migration is productized: it feeds reports, coaching decisions, and a visible Profile body-map surface without creating body-part ranks.
- Advanced density tools are modeled conservatively: supersets may compress short sessions, but drop sets/rest-pause/myo-reps are not default programming until there is set-method logging, recovery accounting, and safety copy.
- Monthly checkpoint recaps explain body-region trends in user-facing language while deterministic guardrails remain the source of workout changes.
- Artifacts must include a coach-grade body-region ledger so reviewers can audit direct vs secondary volume instead of guessing from broad muscle tags.
- Reviewer scoring asks, "Would I trust this for a paid full-year plan for a real user?" Anything below 9.0 is treated as a blocker; 9.5+ is the internal finish line.

## Execution Log

### 2026-05-25 Phase 4/9-Class Push

New broad artifact: `LocalArtifacts/year-simulation-20260525-212441`

What changed:

- App-path rollover now builds real exercise history from the active program, recent workout logs, program blocks, progression state, and family tier state.
- Deterministic generation now receives `exerciseRotationsToApply` and avoids stale movements when compatible alternatives exist.
- The year simulation now passes rollover rotations into generation and simulates the Wave-adjusted program.
- Static known finding `rollover_exercise_history_stubbed` was removed.
- Wave 2 is scoped to future Wave 2 days only; it no longer mutates earlier Wave 1 prescriptions.
- Bodyweight/skill progressions now classify as bodyweight progression instead of loaded compound/accessory progression, while weighted bodyweight variants stay loaded.
- Travel substitutions now avoid duplicate same-session replacements when a compatible unique alternative exists.

Verification:

- Targeted tests passed: `DailyWorkoutResolverTests`, `ProgressionEngineBehaviorTests`, `DeterministicProgramGeneratorTests`, `BlockRolloverServiceTests`, `WaveAdjusterTests`.
- Full all-persona 365-day simulation passed for 7 personas.
- Current all-persona sim: 0 critical violations, 0 warnings, no static known findings.
- Travel duplicate check on the artifact returned 0 duplicate travel-day prescriptions.
- Bodyweight/calisthenics final states now keep bodyweight squat, pushup, l-sit, hollow hold, front lever work, and similar skills at `0kg`.

Reviewer re-score after rollover fix:

| Reviewer lens | Updated score | Passed 8.5? | Main 9-10 blocker |
| --- | ---: | --- | --- |
| Home-user coach | 9.1/10 | Yes | Same-session substitution uniqueness and bodyweight progression polish. |
| Professional trainer | 8.8/10 | Yes | Bodyweight/skill load semantics, Wave 2 scope, and hard-set volume quality. |
| Elite athlete reviewer | 8.9/10 | Yes | True annual phase diversity, deload/taper logic, and advanced outcome checks. |

Reviewer re-score after substitution/bodyweight/Wave 2 fixes:

| Reviewer lens | Updated score | Passed 8.5? | Crossed 9? | Main 9.5-10 blocker |
| --- | ---: | --- | --- | --- |
| Home-user coach | 9.3/10 | Yes | Yes | Felt-variety checks, UX friction, and form/instruction quality for home swaps. |
| Professional trainer | 9.1/10 | Yes | Yes | Hard-set volume semantics and phase-aware block variation. |
| Elite athlete reviewer | 9.1/10 | Yes | Yes | First-class annual phases, deload/taper/test weeks, and outcome validation. |

### 2026-05-25 Phase 1/2 Pass

New broad artifact: `LocalArtifacts/year-simulation-20260525-204019`

What changed:

- Added session-length budgets to deterministic generation and rollover input.
- Added role-specific warmups for non-rest generated workouts.
- Added workout compression for short session windows.
- Added band-safe catalog movements and corrected band equipment inference.
- Routed year-sim travel days through `DailyWorkoutResolver` so the simulation judges the actual app-resolved Workout Ready prescription.
- Fixed progression success so high-RPE grinder sets do not count as clean wins.
- Fixed accessory progression so rep targets cap before load progression/reset.
- Fixed Wave 2 so adjustment rows mutate remaining engine-owned prescriptions instead of only emitting rationale.
- Added regression coverage for travel substitutions, warmups, short-session compression, grinder RPE, and accessory caps.

Verification:

- Targeted tests passed: `DailyWorkoutResolverTests`, `ProgressionEngineBehaviorTests`, `DeterministicProgramGeneratorTests`.
- Targeted Wave 2 tests passed: `WaveAdjusterTests`.
- Full all-persona 365-day simulation passed for 7 personas.
- Current all-persona sim: 0 critical violations, 0 warnings, 0 equipment mismatches, 0 empty warmups, 0 session length overages, 0 grindy RPE bumps, 0 accessory rep runaway warnings, 0 Wave 2 no-op warnings.

Remaining blockers:

- `rollover_exercise_history_stubbed` remains a static known finding.
- Weekly volume caps, recent-session loop, annual periodization, and UI button-flow verification are not complete yet.

Reviewer re-score:

| Reviewer lens | Updated score | Passed 8.5? | Main 9-10 blocker |
| --- | ---: | --- | --- |
| Home-user coach | 8.8/10 | Yes | Live rollover history/rotation so blocks feel fresh over months. |
| Professional trainer | 8.6/10 | Yes | Real rollover history, bodyweight/skill load semantics, and stronger volume invariants. |
| Elite athlete reviewer | 8.6/10 | Yes | App-path rotation history, downstream Wave-adjusted simulation, and stronger annual phase diversity. |

## Executive Read

UNBOUND did not fail as an app concept. It failed the higher bar of "premium adaptive coach" because the current training engine behaves too much like a repeated template with strong visuals around it.

The fix is not to slap AI copy on top. The fix is to make the deterministic coaching system obey training reality, make recent sessions change future workouts, then use AI only where it adds judgment, explanation, and personalization inside guardrails.

## Current Ratings

| Reviewer lens | Current score | Why it did not pass |
| --- | ---: | --- |
| Home-user coach | 6.5/10 | Strong motivation and fantasy, but workouts do not react hard enough to time limits, stress, travel, missed sessions, or equipment. |
| Professional trainer | 6/10 | Good skeleton, but progression, deloads, warmups, volume caps, and exercise rotation are not coach-grade yet. |
| Elite athlete reviewer | 4.5/10 | Too much repeated accumulation, not enough annual periodization, performance logic, fatigue management, or advanced specificity. |

Target rating: 8.5/10 minimum from each reviewer. Internal target: 9/10 for the home-user and pro-trainer lenses so the elite lens can remain stricter without sinking the product.

## Baseline Failure Data

From the 365-day merged simulation:

| Finding | Count | Rating damage |
| --- | ---: | --- |
| `accessory_rep_ceiling_runaway` | 2,835 | Makes progression look mechanically wrong. |
| `empty_warmup` | 1,613 | Makes plans feel incomplete and less safe. |
| `session_length_overage` | 972 | Breaks trust with onboarding answers. |
| `wave2_no_prescription_change` | 91 | Adjustment layer explains more than it changes. |
| `equipment_mismatch` | 51 critical | Hard failure for travel and limited-equipment users. |
| `progressed_on_grindy_rpe` | 27 | Rewards bad effort and poor recovery. |

Static known findings:

- `WaveAdjuster` returns the original program while emitting adjustment rows.
- Progression treats RPE above target as success.
- Accessory progression can extend rep targets indefinitely.
- App rollover path has stubbed exercise history, so rotations cannot mature correctly.

## Approval Definition

The system is not approved until all of this is true:

- Home-user reviewer score is at least 8.5/10.
- Professional trainer score is at least 8.5/10.
- Elite athlete reviewer score is at least 8.5/10.
- 365-day simulation passes for all seven personas.
- Zero critical violations across all personas.
- Equipment mismatch count is zero.
- Empty warmup count is zero.
- Grindy RPE progression count is zero.
- Session length overage is below 2 percent of completed workouts, with no overage above 10 minutes.
- Wave 2 and rollover changes materially alter prescriptions when they claim to.
- Recent-session state changes at least one future prescription in every persona where adherence, stress, travel, or performance changes.
- Actual app UI flow verifies onboarding, program generation, workout completion, recent session review, next-session adjustment, and rollover.

## Non-Negotiable Product Position

Do not market "AI coach" as the primary paid value until the deterministic engine passes the safety and trust gates.

Allowed before final approval:

- "Adaptive training plan"
- "Personalized program"
- "Progression engine"
- "Built around your equipment, schedule, and recovery"

Allowed only after final approval:

- "AI coach"
- "AI adjusts your workouts"
- "Coach-grade programming"
- "Year-long adaptive plan"

## Phase 1: Safety And Trust Fixes

Purpose: remove the obvious reasons a normal user or trainer would distrust the app.

### 1. Equipment Constraint Enforcement

Build requirements:

- Every generated exercise must resolve through `MovementCatalog`.
- Program generation must filter exercises by onboarding equipment before final selection.
- Travel modifiers must force temporary bodyweight/bands/dumbbell-safe substitutions.
- If no compatible movement exists, generator must choose a safe fallback and emit a visible reason.

Acceptance gates:

- `equipment_mismatch = 0` in the 365-day sim.
- Travel persona completes the year with zero critical violations.
- UI shows the substituted movement and why it changed.

Expected reviewer lift:

- Home-user coach: +0.5
- Professional trainer: +0.5
- Elite athlete: +0.25

### 2. Session Length Compression

Build requirements:

- Generator must treat onboarding session length as a hard budget.
- Each workout gets a time model: warmup, main work, accessories, rest estimates, cooldown.
- If the workout exceeds budget, compress in this order:
  1. remove low-priority accessories,
  2. reduce accessory sets,
  3. use supersets where appropriate,
  4. reduce main volume only if recovery/adherence requires it.
- The UI must display a clear "fits your 30 min window" or "compressed today" reason.

Acceptance gates:

- `session_length_overage` below 2 percent of completed workouts.
- No overage above 10 minutes.
- Home and travel personas must stay within their stated time window.

Expected reviewer lift:

- Home-user coach: +0.75
- Professional trainer: +0.4
- Elite athlete: +0.1

### 3. Warmups And Prep Work

Build requirements:

- Every non-rest workout gets a warmup.
- Warmups must be role-specific: push, pull, legs, upper, lower, full-body, skill, conditioning.
- Pain, travel, stress, and first-week context must change warmup selection.
- Advanced strength days need ramp sets or warmup sets in addition to general prep.

Acceptance gates:

- `empty_warmup = 0`.
- Warmup exists for every completed non-rest workout in all personas.
- Warmup length fits inside the session time budget.

Expected reviewer lift:

- Home-user coach: +0.25
- Professional trainer: +0.75
- Elite athlete: +0.4

## Phase 2: Progression Engine Correctness

Purpose: make the engine stop rewarding the wrong things.

### 4. RPE Success Logic

Build requirements:

- A set should count as clean success only when reps hit target and RPE is at or below target tolerance.
- RPE above target should trigger caution, maintain, reduce load, or deload depending on trend.
- Repeated grindy sessions should not increase weight.
- Store actual top-set RPE and rep outcome in progression state.

Acceptance gates:

- `progressed_on_grindy_rpe = 0`.
- All personas show at least one maintain/reduce decision when stress or underperformance appears.
- Trainer review can inspect why progression did or did not happen.

Expected reviewer lift:

- Home-user coach: +0.25
- Professional trainer: +0.75
- Elite athlete: +0.6

### 5. Accessory Progression Ceiling

Build requirements:

- Fix accessory logic so reps-first progression has a real cap.
- After cap, progress load, tempo, range of motion, or exercise difficulty depending on equipment.
- Bodyweight skills should progress by variation, hold time, tempo, or density, not fake load bumps.

Acceptance gates:

- `accessory_rep_ceiling_runaway = 0`.
- Accessory rep targets stay inside sane ranges.
- Every accessory progression has one of: reps, load, tempo, ROM, density, or variation.

Expected reviewer lift:

- Home-user coach: +0.2
- Professional trainer: +0.7
- Elite athlete: +0.5

### 6. Weekly Volume Caps

Build requirements:

- Add weekly set caps by muscle group, experience, goal, recovery, and phase.
- Block generation must check weekly volume before finalizing.
- Cut mode and high-stress mode must lower recoverable volume.
- Elite strength/calisthenics personas can tolerate higher volume only when recovery supports it.

Acceptance gates:

- Weekly volume CSV has no out-of-band spikes unless explicitly justified by phase.
- Deload weeks reduce weekly set count materially.
- Cut-mode persona maintains strength emphasis without runaway accessory volume.

Expected reviewer lift:

- Home-user coach: +0.2
- Professional trainer: +0.8
- Elite athlete: +0.75

## Phase 3: Recent Session Loop

Purpose: make the app feel alive instead of static.

### 7. Recent Session State Model

Build requirements:

- Completed workouts must persist:
  - completed sets,
  - reps,
  - RPE,
  - load,
  - pain flags,
  - missed session,
  - skipped exercise,
  - perceived readiness,
  - session duration.
- Recent session state must be readable by next-workout generation and rollover.
- Undo must restore the previous training state.

Acceptance gates:

- Completing a workout changes progression state.
- Missing a workout changes next-session recommendation.
- Undo restores previous progression and recent-session state.
- Year sim verifies these transitions for every persona.

Expected reviewer lift:

- Home-user coach: +0.7
- Professional trainer: +0.7
- Elite athlete: +0.5

### 8. Adherence-Aware Adjustments

Build requirements:

- If a user misses one session, next workout should preserve the week without panic.
- If a user misses two sessions, app should compress or rebalance the microcycle.
- If travel is active, choose travel-safe sessions.
- If stress or sleep is poor, reduce volume, intensity, or exercise complexity.

Acceptance gates:

- Travel persona has zero equipment criticals and visible adaptations.
- Inconsistent persona has fewer missed-session cascades.
- Stressed/cut persona receives recovery-aware changes without losing all progression.

Expected reviewer lift:

- Home-user coach: +0.8
- Professional trainer: +0.5
- Elite athlete: +0.4

### 9. Pain And Substitution Rules

Build requirements:

- Pain flags must be hard constraints for affected patterns.
- App should substitute movement slots, not random exercises.
- Substitution should preserve training intent when possible.
- Repeated pain should trigger deload, alternate pattern, or scan/check-in.

Acceptance gates:

- Simulated pain scenarios never repeat the flagged movement pattern blindly.
- Substitution rationale appears in app UI.
- Professional trainer reviewer signs off on pain handling as safe enough for a consumer app.

Expected reviewer lift:

- Home-user coach: +0.4
- Professional trainer: +0.7
- Elite athlete: +0.5

## Phase 4: Block And Year Periodization

Purpose: pass the elite reviewer and make the "year program" claim real.

### 10. Real Annual Structure

Build requirements:

- A 365-day plan must not be 14 near-identical blocks.
- Add named macrocycle phases:
  - onboarding/calibration,
  - base accumulation,
  - intensification,
  - specialization,
  - deload/resensitization,
  - test/checkpoint,
  - rebuild.
- Each phase must alter volume, intensity, exercise selection, and success metrics.

Acceptance gates:

- Every persona has a readable annual arc.
- Advanced strength and calisthenics personas show phase-specific progression.
- Elite reviewer agrees the year has actual periodization, not repeated templates.

Expected reviewer lift:

- Home-user coach: +0.25
- Professional trainer: +0.7
- Elite athlete: +1.2

### 11. Rollover And Exercise Rotation History

Build requirements:

- App rollover must use actual exercise history.
- Rotate stale accessories and repeated main variants when needed.
- Preserve exercises that are progressing well.
- Rotate intelligently after plateau, pain, boredom, or equipment changes.

Acceptance gates:

- `rollover_exercise_history_stubbed` removed from known findings.
- Every persona shows at least one justified rotation over the year.
- No random churn: important main lifts/skills are not rotated away while progressing.

Expected reviewer lift:

- Home-user coach: +0.25
- Professional trainer: +0.75
- Elite athlete: +0.6

### 12. Wave 2 Must Actually Change Prescription

Build requirements:

- `WaveAdjuster` must produce actual changed prescriptions when it claims adjustment.
- Changes can include sets, reps, RPE, load target, exercise difficulty, density, or rest.
- No adjustment row should exist without a user-visible effect.

Acceptance gates:

- `wave2_no_prescription_change = 0`.
- Every wave adjustment has a before/after diff.
- UI can explain the change in one sentence.

Expected reviewer lift:

- Home-user coach: +0.4
- Professional trainer: +0.6
- Elite athlete: +0.5

## Phase 5: AI Coach Layer

Purpose: make AI worth paying for without letting it break training safety.

### 13. AI Must Be Constrained

AI should not generate arbitrary programs from scratch.

AI may:

- summarize why the deterministic engine changed the plan,
- choose among safe alternatives already approved by the engine,
- generate user-facing coaching explanations,
- ask a check-in question when data is missing,
- produce adherence strategies,
- flag conflicts between goals, recovery, schedule, and equipment.

AI may not:

- prescribe exercises outside `MovementCatalog`,
- ignore equipment constraints,
- increase load when deterministic progression says no,
- override pain constraints,
- bypass weekly volume caps,
- invent annual periodization unsupported by the engine.

Acceptance gates:

- AI output validates against deterministic schema.
- Invalid AI suggestions are rejected and replaced with deterministic fallback.
- AI produces a clear "why this changed" explanation for all adaptations.

Expected reviewer lift:

- Home-user coach: +0.5
- Professional trainer: +0.3
- Elite athlete: +0.3

### 14. Cost And Product Guardrails

Build requirements:

- AI should run only at high-leverage moments:
  - onboarding summary,
  - weekly review,
  - missed-session recovery,
  - plateau explanation,
  - pain/travel adjustment explanation,
  - block rollover summary.
- Cache AI outputs by state hash.
- Use deterministic copy for routine day-to-day confirmations.

Approval gate:

- AI cost per active user stays low enough that premium margin still makes sense.
- If AI cannot meet this gate, ship "adaptive coach" first and delay "AI coach" branding.

## Phase 6: Actual App Verification

Purpose: prove this is not just a model test.

### 15. Button And Flow Coverage

Required app flows:

- Onboarding from first screen to generated program.
- Equipment selection for bodyweight, dumbbell/bench, full gym, hybrid, and travel.
- Program overview.
- Workout start.
- Exercise completion.
- RPE/load/reps logging.
- Skip exercise.
- Substitute exercise.
- Finish workout.
- Recent session view.
- Next workout adjustment.
- Missed session flow.
- Block rollover.
- Scan/checkpoint handoff.
- Paywall/locked state does not block required validation flows.

Acceptance gates:

- Every primary button in these flows is tapped in simulator automation or UI tests.
- App screenshots/logs prove each flow reached expected state.
- Recent session state is visible and affects next prescription.

## Phase 7: Re-Review Process

Purpose: make the 8.5 target objective.

### Reviewer Re-Score Packet

Every re-review must include:

- `365-day-program-export.json`
- `year-simulation-summary.md`
- `constraint-violations.md`
- `weekly-volume-report.csv`
- app UI screenshots for core flows
- before/after examples for:
  - equipment substitution,
  - stress adjustment,
  - missed session,
  - deload,
  - wave 2 change,
  - rollover rotation,
  - AI explanation if enabled.

### Reviewer Approval Questions

Each reviewer must answer:

1. Would you trust this app to guide its target user for a year?
2. Would you pay for this as a premium coaching product?
3. What is the biggest remaining risk?
4. What score out of 10?
5. Is this score at least 8.5?

No phase is complete if any reviewer says no to question 5.

## Execution Order

| Order | Workstream | Main rating target | Completion gate |
| ---: | --- | --- | --- |
| 1 | Equipment constraints | Home/pro trust | Zero equipment criticals |
| 2 | Session length budgets | Home-user trust | Overage below threshold |
| 3 | Warmups | Pro safety | Zero empty warmups |
| 4 | RPE and accessory progression | Pro/elite trust | Zero grindy bumps, zero runaway accessories |
| 5 | Weekly volume caps | Pro/elite trust | No unjustified volume spikes |
| 6 | Recent session state | All reviewers | Logged sessions alter future workouts |
| 7 | Adherence/recovery/travel adjustments | Home/pro trust | Miss/travel/stress scenarios visibly adapt |
| 8 | Pain/substitution rules | Pro safety | Pain constraints are hard stops |
| 9 | Rollover history | Pro/elite trust | Rotations are history-aware |
| 10 | Annual periodization | Elite approval | Year has real phases |
| 11 | Wave 2 real changes | All reviewers | Adjustment diffs exist |
| 12 | AI constrained coach | Premium upside | AI explains and selects, never breaks rules |
| 13 | Full app UI verification | Product proof | Every core flow/button covered |
| 14 | Re-review packet | Approval | All reviewers rate 8.5+ |

## Hard Stop Conditions

Do not proceed to AI marketing if any of these remain true:

- any equipment critical violation,
- any pain constraint ignored,
- any grindy RPE weight increase,
- empty warmups,
- accessory rep runaway,
- wave adjustment with no prescription diff,
- recent sessions do not affect future workouts,
- annual plan still looks like repeated 28-day blocks,
- UI flow cannot prove workout completion and next-workout adjustment.

## Definition Of Done

The plan is done when:

- the year simulation passes all approval gates,
- actual app UI verification passes,
- trainer re-review notes show at least 8.5/10 from all three reviewers,
- the product claim is updated to match the actual system,
- and the artifact bundle is saved as the new approved baseline.

Until then, the correct internal stance is:

UNBOUND has a strong fantasy and a promising training skeleton. The work now is to make the coaching engine worthy of the aesthetic.

## 2026-05-26 Strict Reviewer Re-Grade

Target: move the internal bar from 8.5 approval to a 9.5 premium-coach package. Anything below 9.0 is a blocker; 9.5+ is the finish line.

Strict review scores after the body-region package pass:

- Home-user coach: 9.0/10
- Professional trainer: 8.7/10
- Elite athlete coach: 8.3/10

Shared blockers:

- The smoke artifact was 56 days and was incorrectly carrying full-year critical checks.
- Profile body map used equal AP spreading instead of direct/secondary/skill/mobility/tendon semantics.
- The artifact proved direct and secondary load, but not skill, mobility/control, and joint/tendon stress.
- Core and lower-back load needed better distinction between trunk bracing and direct low-back work.
- Full 365-day all-persona review is still required before claiming 9.5 readiness.

Patch goals for the next review packet:

- Full-year tests must fail on critical violations.
- Smoke runs must not emit annual-only criticals.
- Completed workout logs must feed role-weighted body-region load into the Profile body map.
- Profile must surface dominant recent role signals, not only generic region heat.
- Ledger tests must prove direct, secondary, skill, mobility/control, joint/tendon, carry, and core-bracing behavior.
- Region fatigue budget tests must use real workouts/drafts, not only synthetic region load maps.

Current execution status:

- Smoke artifact now reports zero criticals and zero warnings for the 56-day home-user run.
- `BodyRegionTrainingLedger` now accepts completed `PerformanceLog` input.
- `BodyMapProgressService` now weights Profile body load using the coach-role ledger when completion context is available.
- `BodyRegionLoad` now keeps recent role counters with decode defaults for existing persisted profiles.
- Profile body map rows can show recent role mix, such as direct, secondary, skill, mobility, and tendon load.
- Core movements like planks no longer count lower back as direct hard-set volume by default.
- Carry prescriptions preserve richer muscle-group context so shoulder/forearm/trap/lower-back tendon stress is not lost.

## 2026-05-26 Annual Artifact Gate

Fresh full-year artifact:

- Path: `LocalArtifacts/year-simulation-20260526-083623`
- Days: 365
- Personas: 7
- Critical violations: 0
- Warnings: 0
- Body-role totals:
  - direct hard sets: 43,423
  - secondary exposure sets: 59,826
  - skill practice sets: 7,333
  - mobility/control sets: 19,314
  - joint/tendon stress sets: 2,626

Role coverage by persona:

- advanced calisthenics: skill 7,333; mobility 2,349; tendon 2,314
- advanced strength: skill 0; mobility 1,879; tendon 312
- cut-mode hybrid: skill 0; mobility 3,003; tendon 0
- full-gym intermediate: skill 0; mobility 2,442; tendon 0
- home bodyweight beginner: skill 0; mobility 3,694; tendon 0
- home dumbbell bench: skill 0; mobility 3,022; tendon 0
- travel inconsistent: skill 0; mobility 2,925; tendon 0

The full-year evidence packet is now strong enough for strict reviewer re-score. Remaining scrutiny should focus on whether the simulated skill/carry/recovery paths are representative enough, whether role-specific fatigue should become separate adjustment thresholds, and whether repeated home-user base blocks need more product explanation or rotation.

## 2026-05-26 Final Reviewer Delta

After closing the AP-empty BodyMap and calisthenics tendon-stress blockers, strict reviewers scored the package:

- Home-user coach: 9.6/10
- Professional trainer: 9.4/10
- Elite athlete coach: 9.3/10

Resolved blockers:

- Role-only BodyMap updates without movement AP now persist visible Profile load.
- Wrist/shoulder-sensitive calisthenics skill practice now contributes joint/tendon stress while preserving skill-practice accounting.
- Annual artifact remains clean across 365 days and 7 personas after the patch.

Remaining 9.5 gap:

- Role-specific fatigue thresholds need to affect future programming decisions directly.
- Annual phase diversity needs stronger proof beyond clean repeated block execution.
- High regional load should produce clearer user-facing explanation and coach rationale.
