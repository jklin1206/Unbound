# UNBOUND Program Canvas + 28-Day Arc — Design Spec

Date: 2026-05-24 (decisions locked 2026-05-24)
Status: design spec — see Phase Plans index at bottom for executable agent plans.

## Goal

Make Program feel like a smart workout canvas with a strong default.

UNBOUND should help users who don't know what to do at the gym, without locking out users who already have their own workouts. The app should generate a good default, let users edit it deeply, learn from anything they log, and reward proof from every training route.

The program should feel like:

> Start with a smart plan. Change anything. Log real work. UNBOUND tracks your standards and keeps the next step clear.

(Note: the original draft tagline used "UNBOUND learns" — reworded here to "tracks" so the user-facing copy doesn't imply AI-as-coach, since AI is deliberately scoped out of training decisions.)

---

## Locked Decisions

These 12 decisions resolve the open ambiguities from the original draft. They are binding for Agent A/B/C/D below.

| # | Decision | Replaces |
|---|---|---|
| 1 | **User-facing cycle is "Arc" (28 days).** Drop "monthly" everywhere user-facing. Internal code/assets may keep `monthly_arc` naming for now (badge art is already on disk under that name). | "Monthly program implemented as 28-day arc" |
| 2 | **Wave 2 user gate = snooze-to-undo.** Changes apply with a reason label; each item is per-row revertible for the rest of the Arc. No blocking modal. | "No silent changes" left ambiguous |
| 3 | **Wave 2 starts on Day 15.** Half the Arc. Engine accumulates ~6–12 logged sessions before adjusting for most schedules. | Wave timing undefined |
| 4 | **Saved Workouts are local-only in v1.** Persisted on-device. Cloud sync on roadmap. Device-loss is acceptable v1 risk; surface a "your saved workouts live on this phone" line in the editor. | Open question |
| 5 | **Retroactive prereq clearing uses explicit per-prereq metadata.** Each prerequisite carries `autoClearFromHigherProof: Bool` and `directProofFamily: enum` (reps / hold / mobility / form). Engine only auto-clears when the achieved proof's family matches. Static holds, mobility drills, and form patterns stay direct-proof-required by default. | "Compatible prerequisites" hand-wave |
| 6 | **Reason-label copy is pure templates, no AI.** Reason payloads are a structured enum; each enum case has a static localized template string. Zero hallucination risk; translation-ready from day 1. | AI authorship ambiguity |
| 7 | **Calibration starting choice is switchable any day, no penalty.** "Use UNBOUND suggested" vs "Start from my workouts" is a Day-1 default. User can log either type any day during Calibration. Engine treats whatever is logged as that day's input. | "Branching" ambiguity |
| 8 | **Missing-workout metric: % of scheduled sessions missed in a rolling 7-day window.** "Missed week" = ≥80% of scheduled sessions skipped within rolling 7 days. Density-correct across 3×/wk and 6×/wk users. | "Missed 1 week" undefined |
| 9 | **A/B rotation = session-role match within user's split.** Engine tags each scheduled day with a role (e.g., `pull`, `upper`, `squat_focus`, `full_body`). A/B variants must share the day's role. Works for PPL, Upper/Lower, Full-Body, Bro, and custom splits. | "Same training family" undefined |
| 10 | **Fatigue model is region-aware.** Engine tracks weekly volume per body region (pull / push / legs / core / posterior chain / shoulders). Skill blocks and vows add load to the regions they target; accessory trim is region-specific. Cross-region adds don't conflict; same-region adds trigger a region-specific trim with a warning. | "Reduce accessory volume" undefined |
| 11 | **Multi-rank reward UX = sequential beat collapsing to a tally.** Each cleared standard flashes briefly in sequence (~1s each), then collapses to a summary card with the full list. One cinematic emblem ignition at the end, not per-standard. | "One clean moment" undefined |
| 12 | **Custom workout edge cases.** Rest-day custom workout = bonus (logged + counted for proof, doesn't break rest-day signal). Two-a-day = both sessions log; engine picks the higher-quality one as the day's primary for Wave 2 signal. | Edge cases unaddressed |

### Carried over from the original draft (unchanged)

- The first program button is **Start Calibration Week**.
- Onboarding gathers the schedule. Don't ask for it again unless the user edits it.
- Everyone starts with Calibration Week.
- Calibration Week is not a beginner week — it's a proof-gathering week.
- Users can mix suggested and custom workouts during Calibration.
- Tutorial deferred; should walk through the full app later, not drip-feed.
- Saved custom sessions are called **Saved Workouts**.
- Exercise + Saved-Workout library appears during editing, not as a permanent Program tab destination.
- Checkpoint Scan (formerly "Monthly Scan") is skippable but highly rewarded. See terminology note in §4.
- AI is limited to Checkpoint summary copy and free-text scan interpretation. Training generation, progression, swaps, skill placement, proof, and rewards stay deterministic.
- Any meaningful change to load, reps, sets, exercise, volume, or intensity needs a visible reason.
- If a user logs their own workout instead of the suggested one, it counts as that day's replacement.
- Checkpoint Scan preserves heavily customized user workouts by default; it adjusts targets and suggestions around them.
- Vows are weekly optional add-ons. Easy vows append work; harder vows replace or reduce accessory volume so the session stays recoverable.
- Skills are inserted as blocks inside real workouts, not kept as a disconnected fantasy layer.
- Skill/rank proof runs after every logged workout forever, not only during Calibration.
- Higher proof can retroactively clear logical prerequisites (per Decision 5 metadata).

---

## Product Model

Program has three valid user paths that all live in the same Program tab:

1. **Follow the default**: user wants UNBOUND to tell them what to do.
2. **Customize the default**: user keeps the generated structure but swaps, reorders, removes, adds, and saves workouts.
3. **Bring their own workouts**: user schedules and logs their own sessions while UNBOUND tracks progress, proof, rewards, and suggestions.

These are not separate app modes. The same Program system supports all three.

---

## End-to-End Flow

### 1. After Onboarding

Program opens to a clear first state:

- Primary CTA: **Start Calibration Week**
- Copy: "Use suggested workouts or your own workouts. This week teaches UNBOUND your standards."
- Secondary explanation: schedule comes from onboarding and can be edited later.

After tapping **Start Calibration Week**, the user picks a starting source:

- **Use UNBOUND suggested workouts**
- **Start from my workouts**

This is a Day-1 default only. Per Decision 7, the user can log either type any day without penalty.

If the user has no Saved Workouts yet and chooses their own workouts, route directly into the workout builder/editor.

### 2. Calibration Week

A 7-day proof-gathering period.

**Purpose**
- establish real loads, reps, RPE, exercise standards
- teach the app what movements the user actually performs
- detect equipment, pain, preference mismatches
- allow existing skill standards to unlock immediately
- create usable targets for the first 28-day Arc

**Behavior**
- Suggested workouts are conservative and standard-finding focused.
- Custom workouts logged during Calibration count equally.
- Advanced users are not asked to do fake beginner work — their logged work proves their starting point.
- The app does not over-explain day-by-day tutorial content yet.

**Completion** — show a Calibration Summary:
- standards learned
- best performances
- skill standards unlocked
- missing data areas (e.g., zero pull data → flag, prompt to add a pull session)
- first 28-day Arc recommendation

### 3. The 28-Day Arc

After Calibration, the engine creates the user's first **Arc** — a 28-day cycle. Subsequent Arcs follow each completed Arc, optionally gated on a Checkpoint Scan (§4).

Internally, the Arc uses two adaptive waves:

- **Wave 1 (Day 1–14):** stable setup, clean logging, baseline confirmation
- **Wave 2 (Day 15–28):** gentle adjustments based on completed logs

Per Decision 2, Wave 2 surfaces every adjustment with a reason label and a per-row revert. The user is never blocked by a modal; they can undo any specific change for the rest of the Arc.

**Wave 2 may adjust** (with reason label + per-row revert):
- suggested load
- target reps
- target RPE
- set count
- accessory volume (region-scoped per Decision 10)
- weak-point add-ons
- skill block placement
- vow fatigue budget
- deload / travel / short-session modifiers

**Wave 2 may never silently:**
- replace the user's favorite workouts
- swap major exercises without a reason
- change the split shape
- remove custom sessions
- force the user into a new goal

### 4. Checkpoint Scan (renamed from "Monthly Scan")

**Terminology note:** the original draft called this the "monthly scan," which conflicts with UNBOUND's existing body-scan feature (photos, MuscleHeatGroup, etc.). We use **Checkpoint Scan** (or just **Checkpoint**) for the end-of-Arc review. The body-scan capture remains called **Body Scan** when referred to as a standalone capability.

Checkpoint is a checkpoint, not a surprise rewrite. It is **skippable**, but highly rewarded:

- reward Checkpoint completion
- show a better coach summary
- update body / photo progress
- improve next-Arc suggestions
- unlock better weak-point targeting

**If skipped**
- preserve current structure
- continue conservative progression from workout logs
- do not block the user from training

**If completed**
- AI may summarize messy free-text input (this is the AI's full scope here)
- deterministic rules decide the next Arc, suggestions, skill focus, and adjustment pressure
- present a review before changes apply

---

## Program Tab Requirements

**New-user and ongoing-user views share this priority order:**

1. Today's workout (or today's replacement)
2. Start/resume CTA
3. Edit CTA
4. Short reason labels for any active Wave 2 adjustments
5. Weekly schedule
6. Current Arc context strip (e.g., "Arc 3 · Day 17 · Wave 2")
7. Vow / add-on status
8. Skill focus blocks when routed today

**The Program tab is not a permanent library dashboard.** The library appears when editing.

**Ongoing-user spec** (Open Cycle 13 in original review — resolved here): Same skeleton as the new user. The Arc context strip replaces the new-user "Start Calibration Week" CTA once Calibration is complete. Mid-Arc Day-N view: Today's workout card on top, schedule strip below, Arc progress bar at top of the tab.

---

## Editing Requirements

The workout editor should feel like changing a canvas, not walking through a wizard.

**Required actions**
- drag to reorder exercises
- tap exercise to swap
- add exercise
- remove exercise
- edit sets/reps/RPE/load target
- save current workout as a Saved Workout
- replace today's generated workout with a Saved Workout
- schedule Saved Workouts into the week

**Swap sheet**
- opens immediately from tapping an exercise
- includes search
- includes suggested replacements
- filters by compatibility
- shows unavailable / avoid / equipment warnings
- has a small persistence control: **Today** / **Keep using**

If the user changes many exercises today, do not force them through repeated confirmations. Persistence controls are light and batch-friendly.

---

## Saved Workouts

Saved Workouts are user-owned templates, **stored locally on-device in v1** (Decision 4).

They support:
- title
- blocks/exercises
- order
- target sets/reps/RPE
- preferred equipment
- intended training area or slot (mapped to a session-role tag per Decision 9)
- optional A/B relationship

Saved Workouts can be scheduled into the 28-day Arc.

Checkpoint Scan preserves Saved Workout structure by default and adjusts around it.

---

## A/B Rotation

A/B workouts reduce boredom while preserving intent.

Per Decision 9, the engine tags each scheduled day with a **session role** within the user's split. A/B variants must share that role.

**Valid examples (any split)**
- Push A / Push B (PPL)
- Upper A / Upper B (U/L)
- Full-Body A / Full-Body B (FB)
- Pull-vertical A / Pull-vertical B (movement-pattern split)
- Bro-Chest A / Bro-Chest B (Bro split)

**Invalid behavior**
- Push turning into Legs
- a 3-day PPL user receiving mismatched weekly intent
- random variety that breaks progression tracking

The engine rotates variants only inside the same session role.

---

## Nutrition Scope

Nutrition supports training expectations; it is not a diet product.

**Include**
- protein target (computed from bodyweight; capture during onboarding with a generic-range fallback if user declines)
- hydration target
- optional light training-fuel / carbs guidance
- height/weight internally only if helpful (no BMI, no calorie totals)

**Avoid for v1**
- BMI language
- full calorie tracking
- rigid meal plans
- food policing

Nutrition context can reduce or increase progression pressure, but the program does not shame the user for not tracking food.

---

## Skill Integration

Skills become trainable blocks inside the Program canvas.

**Entry points**
- onboarding/scan skill focus
- Skill Tree action: add to program
- Program editor add block
- Weekly Vow

**Skill block types**
- **Primer**: low-fatigue prep before the workout
- **Main Skill**: primary focus near the start of a workout
- **Accessory Skill**: after main lifts
- **Mobility/Recovery Skill**: after workout or on a lighter day

**Region-aware fatigue (Decision 10):** each block carries a `regionLoad: {region: load}` map. When a hard skill block or hard vow is added, the engine recomputes the weekly region budget and trims accessories only in the affected regions.

Reason label example:

> Your pull volume jumped this week, so pull accessories were trimmed. Legs untouched.

**Multi-skill across regions is supported.** Two skills in different regions don't conflict; two in the same region trigger a region-specific trim with a warning.

---

## Proof + Rewards Engine

The proof engine runs after every logged workout forever.

**Inputs**
- generated Program workout
- edited Program workout
- Saved Workout
- custom workout
- skill practice
- Weekly Vow
- retest / trial
- imported workout later

**Engine checks**
- skill standards cleared
- logical prerequisites cleared
- multi-rank advancement
- best performances
- titles / rewards unlocked
- next suggested standard

### Retroactive Prerequisite Clearing (Decision 5)

Higher proof can clear lower logical prerequisites **only when families match**.

Every prerequisite carries:
- `autoClearFromHigherProof: Bool` (default `true` for rep/strength prereqs in the same exercise line; default `false` for mobility, static holds, and form drills)
- `directProofFamily: ProofFamily` (`reps`, `hold`, `mobility`, `form`, `eccentric`, etc.)
- `proofFamilyCovered: Set<ProofFamily>` (what families this prereq's direct proof actually validates)
- `safetyRequired: Bool` (locks auto-clear regardless of other flags)

Example: 12 strict pull-ups clear all lower pull-up rep standards (same family: reps) but do **not** clear Dead Hang 30s (family: hold) or shoulder mobility drills (family: mobility).

### Reward Screen

End-of-workout rewards show:
- standards cleared
- skill unlocks
- multi-rank up
- attributes gained
- vows completed
- new bests
- optional next program suggestion

**Multi-rank UX (Decision 11):** sequential beat — each cleared standard flashes briefly (~1s each) in sequence, then collapses into a summary card with the full list. One cinematic emblem ignition at the end, not per-standard.

Reward card actions:
- Add next standard to Program
- Keep current Program
- View Skill Tree

---

## AI Scope

AI is used only where language is messy and human interpretation helps.

**Allowed**
- Checkpoint Scan summary
- free-text scan interpretation into structured signals
- the single end-of-Arc "how the Arc went" paragraph (coach voice)

**Not allowed**
- exercise selection
- set/rep/load prescriptions
- progression rules
- skill proof
- rank unlocks
- swap compatibility
- deload logic
- vow fatigue budgeting
- **reason-label copy on Wave 2 / Checkpoint changes** (Decision 6 — pure templates)

All AI outputs must be converted into structured signals and passed through deterministic validation before affecting training.

---

## Deterministic Engine Responsibilities

The deterministic engine owns:
- Calibration Week generation
- 28-day Arc generation
- Saved Workout scheduling
- session resolution
- swap suggestions
- exercise compatibility
- A/B rotation (session-role match — Decision 9)
- progression changes
- Wave 2 adjustments (per Decisions 2, 3)
- deload / travel / short-session modifiers
- skill block placement
- region-aware fatigue budgeting (Decision 10)
- proof and unlock evaluation
- reward payloads (sequential-beat metadata — Decision 11)

---

## Required User-Visible Explanations

Show reasons for:
- load lowered
- load raised
- reps changed
- set count changed
- exercise swapped
- accessory removed
- vow replacing accessory volume
- skill block inserted
- deload applied
- missed-session pressure reduction
- Checkpoint Scan recommendation

Reason labels are short and templated (Decision 6). Details live behind a tap.

---

## Missing-Session Policy (Decision 8)

Metric: % of scheduled sessions missed in a rolling 7-day window.

| Missed % (rolling 7d) | Action |
|---|---|
| < 50% | continue normally |
| 50–79% | continue, lower pressure slightly, surface a "soft check-in" prompt |
| ≥ 80% | offer ramp week (do not force) |
| ≥ 80% sustained 14+ days | recommend recalibration week |

Recalibration is offered, not forced, unless current data is too stale to prescribe safely.

---

## Cross-Cutting Rules for Agents

- Do not silently change the user's workout structure.
- Do not make AI the source of truth for training.
- Do not split custom workouts into a separate app mode.
- Do not make the Program tab a library dashboard.
- Do not make Checkpoint Scan mandatory.
- Do not block skill/rank proof behind Calibration Week.
- Reason-label copy is templated, never AI-authored.
- Every agent adds/adjusts tests for its slice.
- Every agent runs the relevant Xcode simulator test slice.
- Final integration runs the full simulator suite (owner: Agent A, since the engine sits at the bottom).

---

## Still-Open Product Questions

Items intentionally deferred — none block agent kickoff:

1. Exact visual design of the first Calibration Week entry screen.
2. Exact reward values for completing Checkpoint Scan.
3. How detailed the nutrition card should be in the first implementation.
4. Internal arc labels shown to the user (e.g., "Arc 1," "Cycle 1," "Block 1" — leaning Arc).
5. How much of the full tutorial belongs before Calibration Week vs. after first workout completion.

---

## Phase Plans Index

Each agent has a dedicated executable phase plan. All four are scoped so they can be run independently after the file-touch matrix is respected.

| Agent | Phase Plan | Owns |
|---|---|---|
| **A** | [`2026-05-24-arc-engine-agent-a.md`](2026-05-24-arc-engine-agent-a.md) | Program domain, 28-day Arc, Wave 1/2, region-aware fatigue, Checkpoint→engine signal pipeline, scheduler |
| **B** | [`2026-05-24-program-editor-agent-b.md`](2026-05-24-program-editor-agent-b.md) | Program tab UX, editor, swap sheet, Saved Workouts local persistence, A/B by session role |
| **C** | [`2026-05-24-skill-proof-agent-c.md`](2026-05-24-skill-proof-agent-c.md) | Skill blocks as first-class blocks, proof engine, retroactive prereq metadata, sequential-beat reward UX |
| **D** | [`2026-05-24-checkpoint-scan-agent-d.md`](2026-05-24-checkpoint-scan-agent-d.md) | Checkpoint Scan (skippable + rewarded), AI summary boundary, structured signal pipeline, nutrition scope |

**Integration owner:** Agent A runs the full-suite simulator pass at the end (the engine sits at the bottom of every flow).
