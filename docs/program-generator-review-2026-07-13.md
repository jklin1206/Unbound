# UNBOUND Workout Generator - Year-Simulation Review (Synthesized)

Date: 2026-07-13.
Inputs: 7 persona reviews (365-day simulated programs), each verified by a professional S&C coach, plus 3 code traces mapping the failures to generator code.
All findings below were CONFIRMED by the professional verifier or discovered by the verifier directly; refuted claims are listed in their own section.

## Executive summary

The generator's delivery infrastructure is genuinely good: scheduling cadence is exact for every persona, session caps are respected, travel substitution works, and cut-mode stress-spike days get a real same-day volume trim.
Everything a coach is actually paid for fails.
Across all 7 personas the verified grades are D+ to D-, and the failures are the same five engine defects wearing different persona clothes:

1. Sessions chronically underfill the requested time budget (49-95% fill, never once meeting it) because day size is fixed by absolute slot caps with no back-fill, and push/pull days structurally collapse to 2-3 exercises.
2. Progressive overload is absent or inverted: prescriptions freeze for 52 weeks (or regress), the engine ignores a simulated athlete beating targets at RPE 7 in essentially every session, calibration output never informs targets, and the one thing that does progress linearly is a misclassified isolation riding the compound ramp to physically impossible loads (Straight-Arm Pulldown 120-180 kg).
3. Movement selection is a uniform round-robin over the whole eligible pool, so no lift is ever anchored: barbell bench 0-11x/year, deadlift 2-9x, while the pool's majority (isolations, machine variants) dominates by membership share.
4. The difficulty model has no coherent user-level estimate: beginners get Nordic curls and never-progressing regressions, advanced users get assisted squats and band rows, often in the same session as elite variants.
5. Gymnastics skill work (front levers, planche, L-sits) leaks into every persona's program as ordinary core/accessory slots, misfiled onto Lower days, never progressing, and prescribed as rep counts instead of hold seconds - despite an existing opt-in skill channel the generator bypasses.

The code traces localize defects 1, 3, 4, and 5 to a small set of files in `UNBOUND/Services/ProgramGeneration/` and `UNBOUND/Models/Movements/`, and most fixes are narrow.
The progression/load engine failure (defect 2) is the most severe cross-persona defect and is NOT yet covered by a code trace; it needs its own trace before a fix ships.
Separately, the sim harness feeds a near-static athlete and classification-generic load seeds, so it must be improved before it can validate progression fixes.

## Per-persona verdicts (professional verifier grades)

| Persona | Junior grade | Verified grade | One-line verdict |
|---|---|---|---|
| home-bodyweight-beginner | D | D | Mildly regressing, not merely frozen (the only dose changes all year are downward); placebo pull training; unperformable Nordics; the frequency/time skeleton is the only thing keeping it off an F. |
| home-dumbbell-bench | D | D- | 570 curl sets vs 202 hard pull sets for a back-focused getStronger user; year's #3 exercise needs an unowned kettlebell; loads sit at ~RPE 4-5 all year; months 10-12 nearly replay months 5-7. |
| full-gym-intermediate | D+ | D | 2 bench presses in 52 weeks; a 54/54 identical 3-exercise 32-minute Pull day for a back-focused user; per-classification load buckets produce physically impossible prescriptions. |
| advanced-strength | D | D- | 49% budget fill; big-4 barbell lifts at 11/8/4/7 exposures/year; zero direct arm work in 312 sessions; inverted, unbounded progression engine. |
| advanced-calisthenics | D- | D- | One global 20s hold constant for all 269 isometrics; 111 hardcoded 2-exercise days; cornerstone skill movements uncatalogued (96 violations); a guaranteed 12-month plateau for a plateau-obstacle user. |
| travel-inconsistent | D+ | D+ | Superb scheduler around anterior-dominant churn; 24 skipped sessions never analyzed (both deadlift days skipped, so real hinge exposure was zero) and no generator response to misses. |
| cut-mode-hybrid | D+ | D+ | Great plumbing pumping the wrong water: squat/deadlift pinned at 4x8x92 kg across 33 sessions of "this was easy" feedback; acute stress autoregulation works, chronic periodization absent. |

## Confirmed systemic findings

### F1. Chronic session underfill; push/pull days structurally capped at 2-3 exercises (critical; all 7 personas)

No persona ever received a session meeting their requested budget.
Advanced-strength (90 min ask): max 58 min, avg 44.3, Pull locked at 32 min on all 103 pull days.
Advanced-calisthenics (60 min): avg 33 min; all 111 two-exercise days are Push/Pull days, e.g. "Pike Push-Up + Push-Up" as an entire session.
Full-gym-intermediate (60 min): all 54 Pull days are exactly 3 exercises / 11 sets / 32 min for a back-focused user; 77/260 days under 40 minutes.
Home-bodyweight-beginner (30 min): 39/156 days are 2-exercise 8-set sessions.
Home-dumbbell-bench: two contiguous ~8-week stretches (days 129-185 and 280-334) where every Lower day is 3 exercises / ~31 of 45 minutes.
Block metadata simultaneously claims estimatedDailyMinutes = budget, so plan-level intent contradicts the generator's own day assembly.

### F2. Progressive overload absent or inverted; perfect-performance feedback ignored (critical; all 7 personas)

Home-bodyweight-beginner: Push-Up 4x5 on all 105 post-calibration appearances; the only dose changes in the whole year are downward; calibration measured 12 clean reps @ RPE 7 and day 9 set the permanent dose at 5 reps (~40% of measured capacity), never referencing the measurement again.
Cut-mode-hybrid: Safety Bar Squat and Deadlift at 4x8x92 kg on all 33 appearances while the sim reports RPE 7 with all reps completed every time; the persona's declared obstacle is literally "plateau".
Advanced-strength: barbell bench gains 12.5 kg all year while the misclassified Straight-Arm Pulldown ramps 57.5 -> 180 kg and finishes as the program's heaviest lift.
Home-dumbbell-bench: 470/478 ten-rep slots show simulated top sets of 15-20 reps (prescribed load ~RPE 4-5) and the engine never closes the gap.
Advanced-calisthenics: every isometric all year is a single hardcoded 20s hold; the planche slot ping-pongs between two variants at identical prescriptions; the persona ends the year on day-13 prescriptions.
Travel-inconsistent: 497 of 538 accessory slots at one constant load while the simulated user doubles the rep target.
No deloads, rep waves, or phase changes exist anywhere; full-gym-intermediate's weekly volume actually declines 91 -> 79 sets across the year.
RPE is null on effectively all post-calibration slots for every persona, so there is no effort guidance and no autoregulation channel.

### F3. Movement churn: no anchor lifts, so overload exposure is structurally impossible (critical; home-dumbbell-bench, full-gym-intermediate, advanced-strength, travel-inconsistent, cut-mode-hybrid)

Uniform rotation over the whole pool yields appearance frequency = 1/poolSize.
Full-gym-intermediate: Barbell Bench Press 2x/year; 154 unique exercises and 168 unique compositions in 260 sessions.
Advanced-strength: 80 of 160 compositions appear exactly once (median repetition 2); big-4 lifts fill 4.7% of slots; churn is intra-block, not just at boundaries.
Travel-inconsistent: 128 unique exercises; the top movement (Smith bench, 28x) has 82-93 day gaps.
Home-dumbbell-bench: DB Bench on 9 days with 114+ day gaps, always 4x8.
Loads do creep on whatever persists, proving the progression math exists and the selection layer starves it.

### F4. Classification and load model inverted: isolations ride compound ramps, compounds freeze, loads come in global buckets (critical; full-gym-intermediate, advanced-strength, cut-mode-hybrid, travel-inconsistent)

Straight-Arm Pulldown is classified upperCompound, anchors every Pull day (54x-103x/year), and progresses to a fantasy 120-180 kg.
Pendlay/Meadows/Barbell Bent-Over Row are classified accessory and frozen at 18.4-20 kg - at or below an empty 20 kg bar.
Loads seed per classification, not per movement: every accessory at 18.4 kg (15.2 kg for travel), every upper compound at 57.5 kg, every lower compound at 92 kg (76 kg for travel).
This produces +57.5 kg Weighted Pull-Ups, 92-107.5 kg Goblet Squats, 122.5 kg Dumbbell RDLs, and a deadlift sharing the squat's load track.
Caveat: part of this may live in the sim harness's load model rather than the generator, but either way load realism is untested and per-exercise load conclusions are unreliable until the split is established.

### F5. Focus areas starved; pull/back training a placebo (critical; 5 personas)

Home-bodyweight-beginner: Superman Pull is the only pull movement for 105 sessions; Inverted Row rides as substitution metadata but never runs; a buildMuscle user gets zero lat/scapular/elbow-flexor loading for a year.
Home-dumbbell-bench (back focus): 56/107 Upper days have zero pulling; ~63 pull slots vs 190 curl slots for the year.
Full-gym-intermediate (back focus): the back day is the thinnest day of the week, every week, with no biceps movement and no hinge ever appearing on it.
Cut-mode-hybrid (back focus, every day labeled "+ Back Bias"): 53/108 Upper days have no row/pulldown/pull-up; 207 raise/fly slots vs ~49 loaded pull slots.
Travel-inconsistent (chest+legs focus): all labels are chest-bias only and the legs bias is never expressed; 36 zero-pull upper days sustain an anterior-dominant shoulder-risk pattern.
The focus-area system appears to apply exactly one bias globally, as a label rather than programming.

### F6. Difficulty model incoherent: regressions and elite movements interleaved with no user-level estimate (critical; all 7 personas)

Home-bodyweight-beginner: full Nordic Curls at 4x5-8 (beyond most trained lifters, unanchorable on the bodyweight equipment profile, with zero warmup) alongside Assisted Squat 43x including the year's final workout.
Full-gym-intermediate: Assisted Squat as the squat slot for a user squatting 112 kg; day 115 pairs Assisted Pull-Up Machine with Chest-to-Bar Pull-Up in one 3-exercise session.
Advanced-strength: 43-48 days contain assisted/negative/band/superman movements; 10 pull days are entirely regression/band mains; days 94/241 pair a +57.5 kg Weighted Pull-Up with Band Lat Pulldown.
Advanced-calisthenics: High Plank 37x (last on the year's final day) next to Advanced Tuck Back Lever; day 102 pairs Wide-Grip Pull-Up with its own band regression at matching prescriptions.
Cut-mode-hybrid: Assisted Dip Machine in the same session as unassisted Dips on 23 days.

### F7. Uninvited gymnastics skill work saturates programs, misfiled onto Lower days, never progressing, holds written as reps (major-to-critical; all personas except home-bodyweight-beginner)

Cut-mode-hybrid: Tuck FL (68x) and Advanced Tuck FL (64x) are the year's two most-programmed exercises, co-occur in the same session 48 times, and never advance past advanced-tuck; 36% of all slots are bodyweightSkill.
Full-gym-intermediate: 51 front-lever prescriptions on Lower days for a freeWeights user; both variants co-occur on 24 Lower days.
Advanced-strength: Wall HSPU / Pseudo-Planche / Pike / Archer push-ups as push-day mains for a barbell athlete; 15 days give both push mains to push-up variants.
Travel-inconsistent: 20 skill-work days, all on Lower or travel days, displacing leg volume.
Holds are prescribed as rep counts after calibration correctly used "20s" (145 hold-as-reps slots for dumbbell-bench; 171 "5-rep" holds for full-gym-intermediate), and the harder variant sometimes gets MORE reps (Advanced Tuck 3x8 vs Tuck 3x5).
A correct opt-in skill channel (program focus -> scheduled skill blocks, tree-gated, progression-aware) already exists in `DailyWorkoutResolver` and is bypassed entirely by the general pool.

### F8. Same-family duplicates stacked inside single sessions (major; 5 personas)

L-Sit + L-Sit (Tucked) in the same day 32x (advanced-calisthenics).
Three lateral-raise variants in one session on 36 days and 3+ leg-curl variants on 24 days (advanced-strength).
50 days with 3+ raise variants and 8 days with 3 curl variants (cut-mode-hybrid).
Recurring 3-curl-variant sessions (travel-inconsistent).
Near-duplicate variants burn slots the starved pull and leg patterns need.

### F9. Equipment mismatches with a blind validator (critical for home-dumbbell-bench; major elsewhere)

Home-dumbbell-bench: 101 slots require unowned gear (Kettlebell Swing 55x is the year's #3 exercise and the default hinge; Back Extension 22x; roman-chair work 24x), with violations = [] - the user hits an unperformable exercise on their very first Lower day.
Band work appears on full-gym days for full-gym personas (17 slots for full-gym-intermediate; 8 sessions mixing band curls with machine stations for travel-inconsistent).
Advanced-calisthenics: the persona's four cornerstone skill movements are uncatalogued (96 violations), falling back to inconsistent classifications (planche variants become loaded "accessories" with fictional 18.4-25 kg loads; back lever becomes bodyweightSkill at 0 kg).
The violations validator covers none of the dimensions the personas fail on: time-budget utilization, style adherence, or level-appropriateness.

### F10. Lower days diluted into core/ab circuits (critical; cut-mode-hybrid, travel-inconsistent, home-dumbbell-bench, advanced-strength)

Cut-mode-hybrid: 22 of ~100 Lower days contain zero squat/hinge/lunge/leg-press pattern (double the junior's count; found by the verifier).
Travel-inconsistent: 24/99 Lower days have 3+ core movements; a recurring 6x template is two glute-isolation cables plus three ab movements with zero quad flexion.
Home-dumbbell-bench: 41/97 Lower days have no squat pattern; 244 mostly-unloaded squat-pattern sets all year despite owned dumbbells (Goblet Squat used 8x).
Advanced-strength: "Legs" days whose heaviest load is a 30 kg leg curl, for a legs/glutes-focus user.

### F11. Verifier-discovered additional findings

- Zero direct arm work in 312 sessions (advanced-strength, critical): not one curl or triceps isolation all year in a machine-rich PPL that programs 9 lateral-raise sets per push day.
- 24 skipped sessions (11.5%) never analyzed and no generator response to misses (travel-inconsistent, critical): both deadlift days were skipped, so actual hinge-from-floor exposure was zero; the next session after a miss is just the next template.
- Weekday +1 shift (minor, ticket-worthy): all sessions land on Tue/Thu/Sat for a Mon/Wed/Fri user, and +1 across all four chosen days for home-dumbbell-bench; either a scheduler or sim date-anchor off-by-one.
- Block rollover drops a Lower session each cycle (home-dumbbell-bench, minor): 10 Upper->Upper stacks at block boundaries skew the split 107/97 and compound the leg deficit.
- Rollover rotation suggestions dump the whole catalog on blocks 5/10 (cut-mode-hybrid, minor): 54-55 item lists vs 0-7 elsewhere; a filtering/threshold bug.
- Goal identities unserved as labels: "athletic" gets 4 real power exposures/year (home-dumbbell-bench), "Endurance Hybrid" gets zero conditioning and no rep above 10 (travel-inconsistent), "hybrid in a cut" gets 16 kettlebell-swing slots as the only ballistic work (cut-mode-hybrid), "Power Specialist" never programs a barbell set below 8 reps (full-gym-intermediate, advanced-strength).
- getStronger users never see a heavy low-rep loaded prescription: every 5-rep slot lands on bodyweight regressions and holds, never on a loaded compound (home-dumbbell-bench, advanced-strength).
- Sim harness caveats (minor but load-bearing for validation): a near-static athlete model (672/912 identical "12 reps @ RPE 7" responses for advanced-calisthenics, including on holds), classification-generic load seeds, and internally inconsistent capability curves; the harness needs per-exercise plausible load ranges, hold-seconds reporting, and a varying athlete before it can validate progression fixes.

### What genuinely works (keep)

Scheduling cadence and chosen-frequency adherence are exact for all personas (modulo the weekday shift).
Session-time caps are never exceeded.
Travel-window substitution correctly produces band/bodyweight sessions.
Acute stress-spike autoregulation works for cut-mode: all 9 stress days got correctly-targeted 2-set volume trims.
Equipment resolution is mostly correct outside the dumbbell-persona kettlebell/roman-chair leak and band-on-gym-day leaks.

## Refuted claims (dropped from findings)

- "Sessions land exactly on the user's chosen days": contradicted by raw dates; every persona checked runs +1 weekday.
- "restSeconds null on all slots proves no rest prescriptions" (advanced-strength): export-schema artifact; the sim's YearExerciseExport has no restSeconds field while the production Exercise model does; underfill conclusions rest safely on estimatedMinutes instead.
- "The substitution layer reliably converts infeasible prescriptions into performable ones" (home-bodyweight-beginner): data shows symmetric swap-pairing, including infeasible movements running while carrying feasible substitutions.
- "Within-block consistency is real (~8x repeats per block)" (advanced-strength): false; median composition repetition is 2 and churn is intra-block, which makes the overload problem worse.
- "No visible adaptation to stress-spike days" (cut-mode-hybrid): false; all 9 stress-spike days received real same-day volume trims; the genuine gap is chronic periodization, not acute autoregulation, and two days flagged as underfill defects were the trim working as designed.
- "The progression engine works when given movement consistency" (home-dumbbell-bench): overstated; even weekly-repeating movements sit ~RPE 4-5 all year with the gap never closed.
- "Back-to-back days never stack two identical patterns" (home-dumbbell-bench): false; 10 consecutive Upper->Upper pairs at block rollovers.
- "Back-to-back duplicate Push days" (full-gym-intermediate): mislabeled; no two adjacent days share a composition; the real defect is a split-sequencing repeat that drops a Pull/Legs slot.
- "Pull volume is roughly half what an advanced athlete would program" (advanced-strength): overstated on weekly set count (~22-23 sets/week is normal); the true failures are load quality, the 3-exercise cap, time utilization, and zero elbow-flexion work.
- Numerous count corrections that do not flip conclusions: 22 (not 23) unique compositions; Nordics at 4x8 on 4 (not 16) days; 723 (not 891) raise/fly sets; 154 (not 145) unique exercises; 8 (not 12+) pressless Push days for full-gym vs 13 (not 7) for advanced-strength; 24 (not 27) FL co-occurrence days; 43-48 (not 50) regression days; 22 (not 11) leg-free Lower days (undercounted); 7 missed / 9 stress days (not 5/5); several evidence day-lists partly invented or narrated as performed when skipped (day 96, day 102, day 125).

## Code causes (from the three traces)

All paths relative to repo root.

1. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+MovementSelection.swift:145` - `isPrimaryMovement` returns true for any slot movement with >1 muscle group, so nearly the whole push/pull pool is "primary" (capped at 2 picks) and the accessory pool is empty or a single movement; Straight-Arm Pulldown is literally the entire full-gym pull accessory pool, hence 103x/year. Confidence: confirmed (probe-verified).
2. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift:71` - day size is fixed by absolute caps (<=2 primaries + 3 accessories + <=2 bias extras); budget is only ever used to shrink; no loop back-fills when the estimate is under budget, yet the day still gets a "Built to fit the N-minute window" note and blocks stamp estimatedDailyMinutes = budget. Confidence: confirmed.
3. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+SessionDetails.swift:157` - the estimator charges a full rest period after the LAST set of every exercise plus a separate 30s transition, double-charging per exercise; the inflated estimate trips compression on tight budgets. Confidence: confirmed.
4. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Prescription.swift:181` - the compression floor is min(2, count) and exercise removal runs BEFORE set/rest tightening, so a slightly-over-estimate 3-exercise day loses a whole movement pattern (observed: the beginner's core slot deleted 45x). Confidence: confirmed.
5. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift:42` plus `MovementSelection.swift:247-255` - `rotateDefinitions(by: sessionIndex)` round-robins the FULL pool every session with no per-block anchor persistence; previousBlock only EXCLUDES last block's picks, adding churn. Confidence: confirmed.
6. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+MovementSelection.swift:212` - `workoutEquivalenceKey` keys on canonical name only, so 3 leg-curl and 3 lateral-raise variants count as independent pool entries and can stack in one workout. Confidence: confirmed.
7. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+MovementSelection.swift:77` - `difficultyAllowed` for .used/.current only excludes .elite, so tier-0 regressions stay in advanced pools; `programScore`'s difficultyScore*10 additionally sorts beginner entries toward the pool head. Confidence: confirmed.
8. `UNBOUND/Models/Movements/MovementCatalog+ClassificationSelection.swift:91` - the style preference (barbell -20 for freeWeights) is only a sort key that rotation then discards; annual frequency = pool membership share, so the barbell bias buys zero extra appearances. Confidence: confirmed.
9. Skill-leak cluster:
   - `UNBOUND/Models/Movements/MovementCatalog+ClassificationTraits.swift:121` - "l sit tucked" hardcoded .beginner, admitting it into never-trained pools. Confirmed.
   - `UNBOUND/Models/Movements/MovementCatalog+ClassificationTraits.swift:133-134` - the tier->difficulty mapping under-grades the front-lever line (tuck = .intermediate) and Wall HSPU's tier-1 short-circuits the name-based .advanced check. Confirmed.
   - `UNBOUND/Models/Movements/MovementCatalog.swift:363` - the lever family exists as ordinary .core canonicalExercises, indistinguishable from cable crunch to the generator. Confirmed.
   - `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift:389` - weak-point bias picks the first bias-matching candidate; lever entries are the ONLY core-slot movements tagged .lats/.back, explaining cut-mode's 68x Tuck FL. Likely.
   - `UNBOUND/Models/Movements/MovementCatalog+ClassificationSelection.swift:89` - the holdControl -15 bonus sorts holds first for bodyweight users, and skill-day picks are an unrotated prefix(2). Confirmed.
   - `UNBOUND/Models/Movements/MovementCatalog+Definitions.swift:478` - every skillDrill is stamped flat .intermediate, admitting straddle-planche prep for .tried users. Confirmed.
   - `UNBOUND/Services/ProgramGeneration/DailyWorkoutResolver.swift:89` - the correct opt-in skill channel exists (tree-gated, progression-aware) and the general pool bypasses it. Confirmed design gap.
10. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift:166` - `calibrationPick` returning nil silently drops the slot with no fallback; a latent shrink path (calibration pools were adequate in the observed runs, but calibration days also underfill because slots are the only sizing input). Confidence: likely.

Not yet traced (needs its own code trace before fixing): the progression/load engine (per-classification load buckets, no autoregulation response to over-performance, holds-as-reps unit loss after calibration, calibration output not seeding targets, no deload/wave structure), the focus-area bias system (single global bias, label-only), the equipment filter leak (kettlebell/roman-chair for dumbbell users, bands on gym days), missed-session response, and the weekday +1 shift.

## Prioritized fix plan

Each item is independently shippable.
After each landed slice, rerun the 365-day x 7-persona year sim and diff the coverage stats (GateKeyPacing-style harness discipline).

### 1. Fix isPrimaryMovement and the primary/accessory pool split

Files: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+MovementSelection.swift`, `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift`.
Classify primaries via ExerciseClassification / explicit compound-anchor metadata instead of muscleGroups.count > 1; after taking 2 primaries, fill remaining picks from the entire unused eligible pool (rotation-ordered, deduped) rather than the often-empty non-primary residue.
Fixes: 2-3 exercise push/pull days (F1), Straight-Arm-Pulldown-every-pull-day and isolation-as-compound (F4), and feeds F5.
Confidence: confirmed.

### 2. Add a target-band back-fill loop to buildWorkout

File: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift`.
While estimatedWorkoutMinutes < budget - 10 and count < an experience-scaled max, append the next unused eligible definition as an accessory; when the pool is exhausted, add sets (cap 5) to accessories then primaries; run compression afterwards so the band is approached from below.
Fixes: chronic underfill for all 7 personas (F1).
Confidence: confirmed.

### 3. Fix the session-time estimator and compression ordering

Files: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+SessionDetails.swift`, `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Prescription.swift`.
Charge rest only between sets (sets*work + (sets-1)*rest) with the 30s transition as the inter-exercise gap; raise the compression floor to min(3, count); tighten rest and trim sets BEFORE deleting an exercise; only emit the "Built to fit" note when the estimate is actually near the budget.
Fixes: the beginner's 2-exercise days and false compression on 30-45 min budgets (F1).
Confidence: confirmed.

### 4. Anchor 1-2 primaries per block per template; rotate accessories only

Files: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift`, `UNBOUND/Models/Movements/MovementCatalog+ClassificationSelection.swift`.
Pick each template's primaries once per block (deterministic seed = blockNumber + template, best programScore candidate from an anchor tier where the freeWeights -20 actually decides the winner) and reuse them for every session of that template in the block; rotate anchors only at block rollover via the existing exercisesToRotate hook; rescale or zero the difficulty term so equipment intent dominates the score.
Fixes: movement churn and overload-exposure starvation (F3); makes the style preference real (F4-adjacent).
Confidence: confirmed.

### 5. Gate gymnastics skill work behind the existing opt-in channel and fix the difficulty tags

Files: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+MovementSelection.swift`, `UNBOUND/Models/Movements/MovementCatalog+ClassificationTraits.swift`, `UNBOUND/Models/Movements/MovementCatalog+Definitions.swift`, `UNBOUND/Models/Movements/MovementCatalog+ClassificationSelection.swift`, `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift`.
Drop core-lever family (tier >= 2) from general pools unless trainingStyle == .bodyweight AND the node is engaged (new `engagedSkillIds` field on ProgramGeneratorInput assembled from SkillProgressService/UserSkillTierStore); delete the "l sit tucked" .beginner hardcode; run the name-based advanced check before the tier branch (Wall HSPU); grade skillDrills from their target node instead of flat .intermediate; remove or reduce the holdControl -15 bonus and rotate skill-day picks by sessionIndex; make bias matching use the slot's primary muscle group so levers stop owning the core slot for back-biased users.
Fixes: F7 entirely, plus large chunks of F6 and F10; verify with a sim rerun asserting zero lever/planche/HSPU prescriptions for non-engaged personas.
Confidence: confirmed (the bias-matching sub-item is likely).

### 6. Family-level equivalence dedupe

File: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+MovementSelection.swift`.
Introduce a movement-family equivalence key (reuse progressionFamily where set, else an explicit family field like "leg-curl" / "lateral-raise"); dedupe the selection pool to one representative per family per session and use the family key in uniqueWorkoutDefinitions so two variants of one family never share a workout.
Fixes: same-family triplet stacking (F8) and stops family membership tripling selection share.
Confidence: confirmed.

### 7. Difficulty floor for experienced users

File: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+MovementSelection.swift`.
In `difficultyAllowed`, exclude .beginner progression-tier entries for .used/.current (better: floor by the user's demonstrated tier per progressionFamily from movement_progress); flip or zero the difficulty sort term for advanced users so "easier" no longer means "sorts first".
Fixes: the regressions-to-advanced-users half of F6.
Confidence: confirmed.

### 8. Trace and fix the progression/load engine (autoregulation + load seeding + hold units)

Files (starting points, not yet traced): `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Progression.swift`, `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Prescription.swift`, `UNBOUND/Services/ProgramGeneration/TrainingPrescriptionResolver.swift`.
Required behaviors: react to logged over-performance (reps over target at RPE <= 7 advances load or reps), seed targets from calibration output instead of per-classification buckets, cap accessory linear ramps with plausibility bounds, keep isometric prescriptions in seconds with a per-movement duration ladder, and add deload/wave structure across blocks.
Fix the sim harness first (per-exercise plausible load ranges, non-static athlete, hold-seconds reporting) so the change is actually verifiable.
Fixes: F2 and the load half of F4 - the most severe cross-persona failure class.
Confidence: speculative on mechanism (no code trace covers this area yet; trace before implementing).

### Follow-up tickets outside the fix plan

- Weekday +1 scheduling shift (determine scheduler vs sim date-anchor).
- Equipment filter leak (kettlebell/roman-chair for dumbbell-only users; bands on full-gym days) and validator coverage for time-budget/style/level dimensions.
- Focus-area system applies one global bias as a label; the second focus area is never expressed.
- Catalog the four missing calisthenics movements (Advanced Tuck Back Lever, Advanced Tuck Planche, Band-Assisted Full/Tuck Planche).
- Block rollover drops a Lower session (Upper->Upper stacking at boundaries).
- Rollover rotation suggestion dump (54-55 items on certain block transitions).
- Missed-session response: re-slot skipped patterns instead of ignoring misses.
- Calibration slot backfill for nil calibrationPick (latent shrink path).
- Goal-identity coverage: power/conditioning modalities for athletic/hybrid/endurance identities, and sub-8-rep loaded work for getStronger.
