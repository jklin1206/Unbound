# Scan Redesign — "Create Your Own Arc" Design

**Status:** Brainstormed 2026-05-13. Awaiting user review before plan-writing.

**Goal:** Replace the AI-body-rating scan flow with a monthly transformation checkpoint that reads BuildIdentity from the trained attribute system, never derives stats from photos, and ships an onboarding hex-tilt layer that seeds the user's starting build tendency.

**Sub-project:** #3 of the UNBOUND product redesign. Absorbs the seeding portion of the originally-scoped sub-project #7 (Onboarding rewrite).

**Approach:** One-shot swap. `BodyAnalysisService` (Gemini grader) is deleted. New `ScanCheckpointService` + `ScanNarrativeService` + `BuildSeedingService` + `BuildHexHUD` are added. Existing onboarding chapters (Arc/LifeChange/Chapter/CommitVision/Atmosphere/profile steps) are preserved untouched. The hex tilt is layered onto a small set of existing steps.

---

## Product directive (governing principles)

These come from the user 2026-05-13 and govern every implementation decision below:

1. **The scan is NOT a body-rating engine.** Progression is earned through training (workouts, consistency, benchmarks, skills, trials, attribute progression). The scan is a visual checkpoint, a transformation anchor, onboarding flavor, and progression storytelling — never the source of truth.
2. **Everyone starts near baseline.** Onboarding calibration + optional self-report + optional benchmark seed *modest* starting tendencies. No inflated stats, no genetic ranking, no fantasy class selection.
3. **AI never grades the body.** Optional lightweight narrative only, written around already-derived structured data. No medical, attractiveness, or scientific claims.
4. **Cadence is the loop.** Daily = training. Weekly = trials. Monthly = scan evolution.
5. **The viral payoff is "look how my build evolved over time"** — earned, not assigned.

Memory anchors: [[project_unbound_scan_not_source_of_truth]], [[project_unbound_create_your_own_arc]], [[project_unbound_scan_philosophy]], [[project_unbound_scans_never_show_setbacks]], [[project_unbound_attribute_system_spec]].

---

## Architecture

### New types

```swift
/// Per-axis tendency adjustments produced by onboarding answers.
/// Added to the baseline BuildIdentity (35/100 per axis) to seed the user's
/// starting build. Magnitudes are capped so everyone stays near baseline.
struct BuildSeed: Codable, Equatable {
    var power: Int
    var agility: Int
    var control: Int
    var endurance: Int
    var mobility: Int
    var explosiveness: Int

    static let zero = BuildSeed(power: 0, agility: 0, control: 0,
                                endurance: 0, mobility: 0, explosiveness: 0)
}

/// A monthly scan record. Replaces BodyAnalysis. Photos are visual proof;
/// the BuildIdentity snapshot is read FROM the attribute system, never
/// derived from the photo.
struct ScanCheckpoint: Codable, Identifiable {
    let id: String
    let userId: String
    let createdAt: Date
    let photo: PhotoAsset                 // front only
    let buildIdentitySnapshot: BuildIdentity
    let narrative: String                 // Claude Haiku output (2-3 sentences)
    let deltaFromPrior: BuildIdentityDelta?
}

/// Per-axis change between two BuildIdentity snapshots. Used by Nth-scan
/// payoff. Setbacks (negative deltas) are NEVER surfaced to the user as
/// regression copy — see project_unbound_scans_never_show_setbacks.
struct BuildIdentityDelta: Codable, Equatable {
    let perAxis: [BuildAxis: Int]         // signed; UI filters to non-negative
    let primaryGrowthAxis: BuildAxis?     // largest positive delta
}
```

### New services

- **`BuildSeedingService`**
  Inputs: `OnboardingFlowViewModel` state — training history, exercise style, goal picks, build-seed picks, optional benchmark.
  Output: A seeded `BuildIdentity` written into `AttributeService` as the user's baseline.
  Pure deterministic math; no LLM, no photo. Seeding math defined in the **Seeding math** section below.

- **`ScanNarrativeService`**
  HTTP client to Claude API. Model: **`claude-haiku-4-5-20251001`**. Two prompts:
  - `firstScanNarrative(buildIdentity:)` → 2-3 sentence anchor narrative.
  - `evolutionNarrative(prior:, current:, delta:)` → 2-3 sentence evolution narrative.
  Falls back to a deterministic templated string on API failure. Server-side proxy follows the same auth pattern as the existing Gemini client.

- **`ScanCheckpointService`** (orchestrator)
  `commit(photo:)`:
    1. Reads current `BuildIdentity` from `AttributeService` (never from photo).
    2. Loads the prior `ScanCheckpoint` for delta.
    3. Persists photo + snapshot locally + iCloud.
    4. Calls `ScanNarrativeService` (Haiku) with the structured data.
    5. Returns the assembled `ScanCheckpoint`.

- **`ScanCheckpointStore`**
  Persistence layer mirroring the existing scan persistence pattern, but for `ScanCheckpoint` instead of `BodyAnalysis`.

### New views

- **`BuildHexHUD`** — small shared SwiftUI overlay rendering the current seeded hex; observes the relevant slice of `OnboardingFlowViewModel`. Pure presentation, no business logic.
- **`ScanCadenceGate`** — entry surface from home; renders the soft-lock countdown card when <30 days, else passes through.
- **`ScanWritingArcView`** — replaces `Step_ScanAnalyzing`. ~2.5s cinematic beat with ember intensification; holds until `ScanCheckpointService.commit` resolves.
- **`FirstScanArcCard`** — first-scan payoff.
- **`NthScanEvolutionCard`** — evolution payoff. Reuses already-shipped `ScanBuildDeltaCard` from sub-project #1 Phase 1d.
- **`ScanPayoffView`** — rewritten body; switches on first-vs-Nth and renders the right card.

### Deletions

- `BodyAnalysisService`
- `BodyAnalysisPrompt`
- `BodyAnalysis` model
- `Step_Verdict` (Gemini-driven verdict view)
- Side-angle capture branch in `Step_ScanLive` and its panel in `Step_ScanReview`
- Existing `ScanPayoffView` body (header / photoCard / narrativeCard / focusPill / retakeHint / overallScore plumbing)

Before any file deletion, run the colocated-types check from [[feedback_check_colocated_types_before_deleting]]:

```bash
grep -nE "^enum |^struct |^class |^protocol |^extension " path/to/File.swift
```

If any file contains types beyond the deletion target, extract them first.

### Data flow

1. **Onboarding**: User completes the existing onboarding chapters. On reaching the new `BuildSeedingService` boundary (immediately before `Step_Chapter_Scan`), the service reads the flow VM and writes the baseline `BuildIdentity` into `AttributeService`.
2. **First scan** (still inside onboarding): `Step_Chapter_Scan` → `ScanLiveView` → `ScanReviewView` → `ScanWritingArcView` → `ScanCheckpointService.commit` → `FirstScanArcCard`.
3. **Subsequent scans** (from home): Home scan tile → `ScanCadenceGate` → capture flow → `NthScanEvolutionCard`.
4. **BuildIdentity evolves over time through training** — every logged set advances the trained attributes per the sub-project #1 attribute system. The scan reads the current state; it never writes BuildIdentity.

---

## Onboarding hex tilt (additive layer)

The hex tilt is layered onto the **existing** onboarding flow without restructuring it. The "Create Your Own Arc" framing is already partially in the codebase (`Step_Arc01_Opening` already says "BEGIN YOUR ARC").

### What is preserved untouched

`Step_Arc01_Opening`, `Step_Arc02_Problem`, `Step_Arc03_Path`, all `LifeChange` slides, all `Chapter` interstitials, `Step_CommitVision` (day30/day90/today), `OnboardingAtmosphere`. All profile data steps (age/gender/height/weight/equipment/frequency/days/time/sessionLength/diet/sleep/stress/priorAttempts/commitment/name/notifications) are preserved untouched.

The four steps in the next section (`Step11_Experience`, `Step_ExerciseStyle`, `Step_Goals`, `Step_BuildSeed`) are also preserved structurally — their content and copy stay — but they gain a `BuildHexHUD` overlay and their selections route into `BuildSeedingService`.

### Where the `BuildHexHUD` appears

- **`Step_BuildSeed`** — primary tilt moment. Hex is prominent (≈220pt). Each AttributeKey tap springs the corresponding axis with a 0.55s spring (response 0.4, damping 0.8) and a ~300ms violet pulse on the moved spoke.
- **`Step11_Experience`** — small hex pill in the corner; the years-trained multiplier subtly nudges magnitude.
- **`Step_ExerciseStyle`** — hex pill present; modality choice tilts axes live.
- **`Step_Goals`** — hex pill present; goal picks that map to a build axis tilt accordingly.

On all other onboarding steps, the HUD is absent.

### Question shape (reuses existing steps)

These are existing steps; the contribution table below defines how each one feeds `BuildSeed`.

| Step | Contribution |
|---|---|
| `Step11_Experience` | Tilt-magnitude multiplier only: `Just starting` → 0.4× · `6mo–2yr` → 0.7× · `2–5yr` → 1.0× · `5+ yr` → 1.2× |
| `Step_ExerciseStyle` | Calisthenics → +control, +mobility · Heavy lifting → +power · Olympic / explosive → +explosiveness, +power · Cardio → +endurance · Yoga / mobility → +mobility · Sports / mixed → +agility, +endurance · "Not really training yet" → no tilt |
| `Step_Goals` | Build Power → +power · Improve Movement → +agility · Become More Explosive → +explosiveness · Increase Endurance → +endurance · Improve Mobility → +mobility · Develop Control → +control |
| `Step_BuildSeed` | Up to 2 AttributeKey picks → +per axis directly |
| Optional benchmark (existing within the onboarding profile data, if logged) | Routes through normal attribute progression — same logic a logged set uses, scaled to "first contribution." Does **not** participate in the seeding cap. |

### Seeding math

- **Baseline**: every BuildIdentity axis starts at **35/100**.
- **Per-source caps**: `Step_ExerciseStyle` contributes at most **+8** to any one axis. `Step_Goals` contributes at most **+6** per axis. `Step_BuildSeed` contributes at most **+8** per axis.
- **Multiplier**: `Step11_Experience` multiplies the sum of `ExerciseStyle + Goals + BuildSeed` contributions.
- **Global cap**: Total onboarding-seeded tilt on any single axis is capped at **+18 from baseline** (so max-tilt onboarding still puts a "specialist" at 53/100 — meaningful room to grow).
- Output is a `BuildSeed`. `BuildSeedingService` produces `BuildIdentity` = baseline + seed (per axis, clamped to [0, 100]).

### Existing `Step_BuildSeed` integration

The existing step writes to `flow.seededAttributes: Set<AttributeKey>`. We add a `flow.exerciseStyleSelection`, `flow.goalSelections`, and `flow.experienceMultiplier` if not already present, then route all four through `BuildSeedingService.seed(from: flow)` at the new `BuildSeedingService` boundary.

---

## Scan capture flow

### Entry points

- **From onboarding**: After `Step_Chapter_Scan`, advance directly into capture. Cadence gate is bypassed (this is the user's first checkpoint).
- **From home tab**: Tapping the scan tile enters via `ScanCadenceGate`.

### `ScanCadenceGate`

Soft lock + countdown. Reads `lastScanAt` from the most recent `ScanCheckpoint`.

- ≥30 days elapsed → opens straight into capture.
- <30 days → renders soft-lock card:
  - Headline: `"Next checkpoint in {n} days."`
  - Subline: `"Monthly cadence keeps the change visible."`
  - Tertiary text button (no primary CTA energy): `"Scan anyway"`. Tap → proceeds into capture.

### `ScanLiveView` (replaces `Step_ScanLive` for the standalone scan path; the onboarding-embedded version is also updated)

- Existing live preview, framing guide, capture tap, haptic.
- **Front-only.** The side-angle capture branch is deleted.

### `ScanReviewView` (replaces `Step_ScanReview`)

- Full-bleed front photo with retake / submit.
- Submit triggers `ScanCheckpointService.commit(photo:)`.

### `ScanWritingArcView` (replaces `Step_ScanAnalyzing`)

- ~2.5s cinematic beat. Text fades through:
  1. `"Writing your arc…"` (0–1.2s)
  2. `"Locking the checkpoint…"` (1.2–2.5s)
- Ember particles intensify briefly.
- Holds until `commit` resolves; if commit overshoots 2.5s, the view lingers on its final frame.
- If Claude returns an error, the deterministic templated narrative is used and the user sees no failure indicator.

### Payoff routing

After `commit` resolves, `ScanPayoffView` reads `priorCheckpoint == nil` and renders either `FirstScanArcCard` or `NthScanEvolutionCard`.

### Persistence

`ScanCheckpoint` saved via `ScanCheckpointStore` (mirrors the existing scan persistence pattern, but stores the new model). Photos: local + iCloud (existing pipeline reused).

---

## Payoff cards

### `FirstScanArcCard`

Rendered when `priorCheckpoint == nil`. Top → bottom in a single scroll container:

1. **Hero photo** — full-bleed front shot, top edge bleeds under safe area. Ember-particle overlay decays after 1.2s on appear.
2. **Title strip** — `"YOUR ARC BEGINS"` in `Font.unbound.displayM`, tracking +3, violet `animeGlow` at 0.5 intensity. Fades in 0.4s after the photo settles.
3. **`BuildHexView`** — the seeded BuildIdentity rendered prominent (≈260pt). Spring animation on appear, axes sweeping out from center over 0.7s.
4. **Narrative card** — `Color.unbound.surface`, corner radius 18, padding 18. Renders `ScanNarrativeService.firstScanNarrative(...)` output.
5. **Cadence anchor** — small footer row: `"Come back in 30 days to see how your arc evolves."`
6. **Primary CTA** — `"Begin training"` → onComplete (lands user on home).
7. **Secondary** — `"Share your start"` text link → invokes `ScanShareSheet` (out of scope this sub-project; hide behind a feature flag if not built yet).

**Not present** (explicitly removed): Strengths / Weaknesses sections, focus pills, retake hints, `overallScore`, body fat estimates, muscle assessments, any "AI analysis" framing.

**Debug**: Long-press on hex shows raw per-axis values (gated behind `DevFlags.shared.unlockAllFeatures`).

### `NthScanEvolutionCard`

Rendered when `priorCheckpoint != nil`. Top → bottom:

1. **Before/after photo split** — two stacked half-bleed images.
   - Top: prior photo with `"30 DAYS AGO"` pill.
   - Bottom: current photo with `"TODAY"` pill.
   - Tap the split → expands into full-bleed swipe-comparison sheet.
2. **Title strip** — `"YOUR ARC EVOLVED"`, same `animeGlow` treatment as First.
3. **`ScanBuildDeltaCard`** — already shipped from sub-project #1 Phase 1d. Renders split hex (prior left, current right) + per-axis Δ strip. No rework.
4. **Narrative card** — renders `ScanNarrativeService.evolutionNarrative(...)` output. Voice: *"Your Control held while Power grew 12 points — this is the bodyweight arc compounding."* Never grades, never says "AI," never mentions body fat.
5. **Cadence anchor** — `"Next checkpoint in 30 days."`
6. **CTAs** — primary `"Back to training"`, secondary `"Share evolution"` (same feature flag as First).

**Setback handling** — the hex Δ strip shows **only gains and holds**. If an axis regressed, render a quiet `"Focus area"` pill below that axis instead of a negative number. Per [[project_unbound_scans_never_show_setbacks]].

### Shared between both cards

- Pure SwiftUI views. Receive a fully-formed `ScanCheckpoint` (plus prior for Nth) as initializer input. No view-model heroics.
- Background: `Color.unbound.bg` with `OnboardingAtmosphere` intensity = 0.4.
- All copy is final. No placeholders.

---

## Trajectory step decision

`Step28_Trajectory` is **kept and retargeted**, not deleted.

- Photo-derived projection logic is removed.
- New input: current seeded `BuildIdentity` + user's `Step13_TargetFrequency` selection.
- New output: deterministic 90-day projection of where the BuildIdentity can credibly reach, derived from `AttributeContribution.json` (already exists from sub-project #1) × weekly frequency.
- Cap: never aspirational max-out; clamp to "reachable in 90 days."
- No LLM. No "AI analysis" copy.
- The Trajectory view becomes a roadmap, not a verdict.

If retargeting Trajectory introduces meaningful scope creep during planning, it can be flag-disabled and deferred to a later pass without blocking this sub-project.

---

## Home surface — cadence countdown

The home scan tile gains state derived from `lastScanAt`:

- **Day 1–22**: `Color.unbound.surface` (muted), copy `"Next checkpoint · {n} days"`.
- **Day 23–29**: Subtle violet pulse, copy `"Next checkpoint · {n} days"`.
- **Day 30+**: Active state (full violet glow), copy `"Checkpoint ready"`. Tap → enters `ScanCadenceGate` → passes through to capture.

No new home component. This is a state on the existing scan tile.

---

## Out of scope (deferred)

- Scan share sheet (gated behind a feature flag).
- Scan gallery / full scan history view.
- Other home tiles (rank card, streak chip, etc.) — untouched.
- Profile changes — untouched.
- Side-angle scan as a post-paywall unlock — deferred indefinitely.
- Apple Vision pose/silhouette alignment — deferred to a later sub-project.

---

## Testing strategy

- **`BuildSeedingServiceTests`** — exhaustive: every combination of `Experience × ExerciseStyle × Goals × BuildSeed` picks produces a `BuildSeed` that respects per-source caps and the global +18 cap. Boundary tests at 0 and max contributions. Codable roundtrip.
- **`ScanCheckpointServiceTests`** — first commit produces no delta; second commit produces correct delta. Failed `ScanNarrativeService` call falls back to template. Persistence roundtrip.
- **`ScanNarrativeServiceTests`** — request body shape matches Haiku API contract. Mock HTTP layer asserts prompt format (no raw photo in payload — only structured BuildIdentity / delta data).
- **`ScanCadenceGateTests`** — boundary cases: 29 days = locked, 30 days = open, "Scan anyway" override works.
- **Setback filter**: Given a delta with negative axes, `NthScanEvolutionCard` snapshot test shows no negative numbers — only `"Focus area"` pills.
- **Snapshot tests**: `FirstScanArcCard` (with seeded hex), `NthScanEvolutionCard` (with mixed positive/negative delta), `ScanCadenceGate` (locked + unlocked).

`xcodebuild test` is authoritative (see [[feedback_sourcekit_crossfile_noise_unbound]]).

---

## Migration order (informs the plan, not binding on it)

The plan-writing skill will lay out exact phases. Suggested order:

1. New types (`BuildSeed`, `ScanCheckpoint`, `BuildIdentityDelta`) + `BuildSeedingService` + tests.
2. `ScanNarrativeService` (Haiku client) + tests + fallback template.
3. `ScanCheckpointService` + `ScanCheckpointStore` + tests.
4. New views (`BuildHexHUD`, `ScanCadenceGate`, `ScanWritingArcView`, `FirstScanArcCard`, `NthScanEvolutionCard`, rewritten `ScanPayoffView`).
5. Wire `BuildHexHUD` into `Step_BuildSeed` / `Step11_Experience` / `Step_ExerciseStyle` / `Step_Goals`.
6. Drop side-angle from `ScanLiveView` / `ScanReviewView`.
7. Trajectory retarget.
8. Home scan-tile cadence states.
9. Delete `BodyAnalysisService` + `BodyAnalysisPrompt` + `BodyAnalysis` + `Step_Verdict` (colocated-types check first).

---

## Open questions (none blocking)

The user explicitly approved the design through Section 5. Nothing here blocks plan-writing.
