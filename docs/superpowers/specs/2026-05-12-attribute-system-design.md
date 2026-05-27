# UNBOUND Attribute System — Design Spec

**Date:** 2026-05-12
**Sub-project:** #1 of 7 (Attribute System)
**Status:** Locked — ready for implementation plan

This is the data foundation for the broader UNBOUND vision rewrite. It replaces the current 4-axis `StatScore` (Strength / Stamina / Technique / Vitality) with an emergent 6-axis Build hex driven by per-exercise contribution vectors.

---

## Why this exists

The current `StatScore` model and the home Stats grid don't move the product. Numbers update but nothing meaningful is communicated to the user. The new vision reframes attributes as **build identity** — what your training has shaped you into, surfaced through a hex chart that becomes the spine for:

- emergent archetypes (sub-project #2)
- Build Analysis scan redesign (sub-project #3)
- Ascension tier profile ring (sub-project #4)
- Trials contribution math (sub-project #5)

Nothing else can be designed correctly until this layer is locked.

---

## Scope

### In scope (this sub-project)

1. 6-axis attribute data model with peak + current values per axis.
2. `AttributeService` that ingests session logs and computes profiles deterministically.
3. Per-exercise + per-skill-node contribution vectors authored in the catalog.
4. Profile Build card (hex + 3×2 readout grid).
5. Home Build chip (compact hex + build-name preview).
6. Scan Build Δ panel (split before/after, per-axis Δ strip) — *limited* version that uses the same hex/data; full scan redesign stays in sub-project #3.
7. Removal of dead `StatScore` / `MuscleGroupTier*` / home Stats grid.
8. Onboarding seed-survey screen (optional self-report, max +15 prefill).
9. Per-attribute rank-up animation (`TierBloomToast` for sub-rank; cinematic for Unbound/Ascendant crossings).

### Explicitly out of scope (other sub-projects own these)

- Emergent archetype narrative naming ("Phantom Variant" etc.) — #2.
- Scan verdict tone rewrite, photo-flow changes, share-card design — #3.
- Ascension Tier ring — #4.
- Trials layer — #5.
- Squad / social — #6.
- Onboarding rewrite (full reframe) — #7.

---

## Locked product decisions

| # | Decision | Value |
|---|---|---|
| 1 | Attribute set | **Power · Agility · Control · Endurance · Mobility · Explosiveness** (hex, 6 axes) |
| 2 | Storage model | **Hybrid peak + current per attribute** (mirrors existing `LiftRank` pattern) |
| 3 | Numeric scheme | **0–100 scalar internal**, tier label overlay via existing `SubRank`/`RankTitle` |
| 4 | Training → attribute mapping | **Per-exercise tags** (catalog-authored contribution vectors) |
| 5 | Decay model | **Gentle drift, peak-independent.** 7-day grace, then linear interpolation toward floor over a 30-day window. Floor (70% of peak) reached exactly at 37d idle. Tempo identical regardless of starting level. |
| 6 | Surface priority | **Profile primary** (full hex + readout), **Home preview** (chip), **Scan deep dive** (Δ panel) |
| 7 | Rollout strategy | **Greenfield alongside, 4 phases** (1a → 1d) |
| 8 | StatScore lifecycle | **Removed in Phase 1c/1d** (user confirmed "the existing doesn't do anything") |
| 9 | Build chip tap target | **Profile**, scrolled to Build card |
| 10 | Onboarding seed survey | **Phase 1a scope** (single screen, max +15 prefill on 1–2 picks) |
| 11 | Rank-up animation | **Phase 1b scope**, reuses `TierBloomToast` + existing cinematic rules |

---

## Data model

```swift
// MARK: - Attribute identity
enum AttributeKey: String, CaseIterable, Codable, Sendable {
    case power, agility, control, endurance, mobility, explosiveness

    var displayName: String      // "Power", "Agility", ...
    var shortCode: String        // "POW", "AGI", "CTL", "END", "MOB", "EXP"
    var trainsCopy: String       // "Heavy compounds, sub-6 reps" (for onboarding survey)
}

// MARK: - One axis of the user's profile
struct AttributeValue: Codable, Sendable, Equatable {
    var peak: Double             // 0...100, monotonically increasing
    var current: Double          // 0...100, drifts toward floor
    var lastContributionAt: Date

    var floor: Double            { peak * 0.70 }
    var subRank: SubRank         { SubRank.nearest(for: current / 100 * 17) }
    var rankTitle: RankTitle     { subRank.title }
    var peakSubRank: SubRank     { SubRank.nearest(for: peak / 100 * 17) }
    var peakRankTitle: RankTitle { peakSubRank.title }
}

// MARK: - User's full 6-axis state
struct AttributeProfile: Codable, Sendable, Equatable {
    let userId: String
    var values: [AttributeKey: AttributeValue]
    var computedAt: Date

    func value(for key: AttributeKey) -> AttributeValue
    var dominant: AttributeKey         // highest peak — drives build-name + sub-project #2
    var weakest: AttributeKey          // for "growth area" copy
    var isBalanced: Bool               // max − min < 15 → build name = "Balanced"
}

// MARK: - Static catalog metadata
struct AttributeContribution: Codable, Sendable, Equatable {
    let weights: [AttributeKey: Double]   // each 0.0...1.0, must sum to 1.0 ± 0.01
}
```

**Catalog augmentation**
- `ExerciseLibraryItem` gains `contribution: AttributeContribution`.
- `SkillNode` (in `SkillTreeContent`) gains `contribution: AttributeContribution`.
- Contributions live in a companion JSON file (`Resources/AttributeContributions.json`) loaded at app start. Easier to review/diff than Swift dict literals.

**Tier vocabulary**
- Reuses the existing 9-tier `RankTitle`: Initiate / Novice / Apprentice / Forged / Veteran / Master / Vessel / Unbound / Ascendant.
- Reuses existing 18-step `SubRank` for granular ordering.
- Reuses existing `Assets.xcassets/RankTitles/rank_title_*` badges for per-axis profile rows. No new asset work.

**Persistence**
- One Firestore document per user at `users/{uid}/attributeProfile`. Single read on home appear; single write on session finish.
- Local SwiftData mirror via existing `DatabaseService` pattern.
- Snapshot pattern — no per-session deltas stored. Deterministic recomputability via `recomputeFromHistory()`.

---

## Service layer

```swift
@MainActor
final class AttributeService: ObservableObject {
    @Published private(set) var profile: AttributeProfile

    private let db: DatabaseService
    private let catalog: ExerciseCatalog
    private let skillContent: SkillTreeContent

    func ingest(_ session: WorkoutLog) async throws
    func ingest(_ skillSession: UserSkillProgress.Session) async throws

    func snapshot(asOf date: Date = .now) -> AttributeProfile
    func snapshotForScan(_ scanId: String) async throws    // pins profile at scan time

    func recomputeFromHistory() async throws               // migration + debug tool
}
```

Subscribes to `SessionFinishedEvent` alongside the existing `SessionXPService` and `RankService`. Each runs independently. No coupling.

Emits `AttributeRankUpEvent` whenever an axis crosses a `RankTitle` threshold during ingest. Consumed by Phase 1b animation layer.

---

## Math

### Per-session contribution

**Ingest order matters.** Always project the profile forward to `session.finishedAt` (applying decay) *before* adding session gains. New sessions build on the already-decayed `current` value, not on stale pre-decay numbers from days ago.

```
sessionIntensity(session) = session.intensity / 100        // existing field, normalize to ~0...1
GAIN_CONSTANT = 4.0                                        // tuned so hard session moves dominant axis ~2–3 pts

// 1. Roll forward (apply decay since lastContributionAt → session.finishedAt)
profile = snapshot(asOf: session.finishedAt)

// 2. Compute per-attribute deltas from session contents
sessionEffortMass = Σ effortMass(entry) for entry in session.exercises

for each exerciseEntry in session.exercises:
    contribution = catalog.lookup(exerciseEntry.key).contribution
    exerciseEffort = effortMass(exerciseEntry) / sessionEffortMass     // 0...1, share of session
    for (key, weight) in contribution.weights:
        delta[key] += sessionIntensity × exerciseEffort × weight × GAIN_CONSTANT

// 3. Apply deltas on top of the decayed current values
for each (key, delta) in deltas:
    profile.values[key].current = min(100, profile.values[key].current + delta)
    if profile.values[key].current > profile.values[key].peak:
        profile.values[key].peak = profile.values[key].current
    if delta > 0:
        profile.values[key].lastContributionAt = session.finishedAt
```

`effortMass(entry)`: weight × reps × sets for lifts; duration × intensity for cardio/skill holds. Reuses the existing SessionXP effort accumulator — no new field on `WorkoutLog`.

`sessionEffortMass`: sum across all entries in the session. If a session has only one exercise, `exerciseEffort` = 1.0. If `sessionEffortMass == 0` (empty session), ingest is a no-op.

### Drift math (on read, pure)

Percentage-based interpolation toward the floor. Decay tempo is the **same for every user regardless of peak level** — a low-Power user and a high-Power user both reach 70%-of-peak after the same elapsed idle time.

```
GRACE_DAYS = 7
DECAY_WINDOW_DAYS = 30

fn snapshot(asOf t: Date) -> AttributeProfile:
    for each (key, value) in profile.values:
        floor = value.peak * 0.70
        daysIdle = max(0.0, fractionalDaysBetween(value.lastContributionAt, t))
        effectiveIdleDays = max(0.0, daysIdle - GRACE_DAYS)
        decayProgress = min(1.0, effectiveIdleDays / DECAY_WINDOW_DAYS)
        value.current = floor + (value.current - floor) * (1.0 - decayProgress)
```

Properties this guarantees:

- **No decay** during the first 7 idle days (`decayProgress == 0`).
- **Smooth glide** toward floor over the next 30 days.
- **Floor reached exactly** at 37 days idle (`decayProgress == 1.0`, `value.current == floor`).
- **Peak-independent tempo** — low-level users don't decay faster than high-level users.
- Drift is per-axis (leg day raises lower-body attributes while upper-body drifts).
- Pure on read. No timers, no Cloud Functions.
- Uses fractional days (computed from seconds-elapsed / 86_400) so the curve is continuous across a single day, not step-wise.

### Initial state

- All six attributes default to `peak = current = 0`, `lastContributionAt = .now`.
- Onboarding seed survey (Phase 1a) — user picks 1–2 attributes describing their current training. Each pick adds **+15** to both `peak` and `current` for that attribute. Hard ceiling on seed = 15.

---

## Surface designs

(Visual reference: `surfaces-v5.html` produced during brainstorming, stored under `.superpowers/brainstorm/*/content/`. Five iteration screens captured the decision path: `attribute-set.html` → `surfaces.html` → `surfaces-v2.html` → `surfaces-v3.html` → `surfaces-v4.html` → `surfaces-v5.html`.)

### Profile Build card (primary)

**Layout**
- Card with violet border treatment (`card-new` styling).
- Top: full hex chart (200×200), peak as dashed gray outline, current as filled violet shape. Six axis labels (POW/AGI/CTL/END/MOB/EXP) in mono.
- Build-name line below hex (e.g., "Power-leaning Hybrid" or "Balanced").
- 3×2 grid of axis cells. Each cell:
  - Code (e.g., POW) + value (e.g., 72)
  - Thin horizontal bar (value%)
  - Rank-title badge (e.g., MASTER) using existing `rank_title_*` asset family

**Build name** (Phase 1b minimum rule)
```
if profile.isBalanced:           "Balanced"
else:                            "\(dominant.displayName)-leaning Hybrid"
```
Sub-project #2 replaces this with richer narrative archetypes.

### Home Build chip

- Small card with 92px hex chip on the left, "Build" label + build name on the right, chevron `›`.
- Sits between Rank card and Today's Mission.
- Tap → Profile (scrolled to Build card).
- Slot was occupied by the old 4-axis Stats grid; same PR (Phase 1c) removes it.

### Scan Build Δ panel

- Sits in existing Scan results view.
- Hidden if `attributeHistorySnapshots.count < 2`.
- Layout:
  - "Build · Arc Evolution" header
  - Build-name evolution headline: `from (gray) → to (violet)`
  - Split: Scan 1 hex (110px, gray) on left, Scan N hex (110px, violet) on right, divider arrow
  - 6-column Δ strip below (signed integer deltas per axis; <5 styled as flat gray)
  - "SHARE BUILD EVOLUTION ›" CTA (Phase 1d wires share sheet with placeholder image; real share-card design = sub-project #3)

### Onboarding seed survey screen (Phase 1a)

- Single screen, inserted late in existing onboarding flow (before final summary).
- Copy: "How would you describe your training right now? Pick up to 2."
- 6 toggle chips, one per attribute. Each chip shows `displayName` + `trainsCopy` (e.g., "POWER — heavy compounds, sub-6 reps").
- "Continue" button. Skip-able. No mandatory pick.
- Write happens at "Continue": for each selected attribute, set `peak = current = 15`, `lastContributionAt = .now`.

### Rank-up animation (Phase 1b)

Emission rule (in `AttributeService.ingest`):

| Crossing kind | Example | Event payload `level` | UI response |
|---|---|---|---|
| Sub-rank within a tier (E- → E, E → E+, etc.) | `SubRank.eMinus → .e` | `.subRank` | **None** — sub-ranks stay silent per cinematic-asymmetry rule |
| Tier crossing within E/D/C/B/S buckets | `RankTitle.apprentice → .forged` | `.tier` | `TierBloomToast` (small, scoped to the changed axis) |
| Tier crossing into A-tier | `RankTitle.master → .vessel`, `.vessel → .unbound`, `.unbound → .ascendant` | `.aTier` | Full chain-shatter cinematic (existing component) |

`AttributeRankUpEvent` carries `{ axis: AttributeKey, fromTitle: RankTitle, toTitle: RankTitle, level: Level }` where `Level` is the table's third column. Subscribers in Profile / Home views dispatch animations off `level`. Never elevate.

---

## Phasing

| Phase | Scope | Ship size | Acceptance |
|---|---|---|---|
| **1a — Foundation** | Models + service + ingest path + catalog JSON + onboarding seed screen + `AttributeRankUpEvent` emission | ~1.5 days, PR ~700 LOC + JSON | Catalog vectors sum-test green · ingest unit tests green · drift edge cases tested · seed survey writes correct prefill · no UI regression elsewhere |
| **1b — Profile Build card** | `ProfileBuildCard.swift`, `AttributeHex.swift` reusable component, rank-up animation subscriber | ~1 day, PR ~500 LOC | Profile renders for empty/mid/saturated profiles · rank-up bloom fires correctly · snapshot tests committed |
| **1c — Home swap** | `HomeBuildChipCard.swift`, delete `UnboundHomeView` Stats grid section, remove `HomeViewModel` StatScore refs | ~0.5 day, PR ~250 LOC (deletion-heavy) | Home renders without stats grid · Build chip taps to Profile · manual QA confirms no layout overflow |
| **1d — Scan Δ + cleanup** | `ScanBuildDeltaCard.swift`, scan snapshot pinning, delete `StatScore.swift` + `MuscleGroupTier*.swift` + `MuscleHeatmap*.swift` + `MuscleHeatGroup.swift` | ~1 day, PR ~500 LOC additions / ~800 LOC deletions | Scan card renders for 2+ snapshot users · hides cleanly for first scan · project compiles with zero `StatScore` refs · TestFlight E2E confirms session → home → profile → scan flow |

---

## Testing strategy

**Catalog integrity (Phase 1a)**
- Every `ExerciseLibraryItem.contribution.weights.values.sum() == 1.0 ± 0.01`.
- Every `SkillNode.contribution.weights.values.sum() == 1.0 ± 0.01`.
- Every `AttributeKey` appears in at least one contribution vector (no orphan axes).

**Ingest math (Phase 1a)**
- Property test: monotonic increase, ≤100 ceiling, peak lifts when crossed.
- Empty session no-op.
- 30-day fixture replay → expected dominant axis.

**Drift math (Phase 1a)**
- `snapshot(asOf: lastContributionAt)` returns identical values (`daysIdle == 0`).
- `snapshot(asOf: +7d)` returns identical values (grace period, `decayProgress == 0`).
- `snapshot(asOf: +22d)` (mid-window, 15 days into decay) → `current == floor + (preDecayCurrent − floor) × 0.50`.
- `snapshot(asOf: +37d)` → `current == floor` exactly.
- `snapshot(asOf: +90d)` → `current == floor`, clamped (never below).
- Peak-independence: identical decay curve for `peak=20` and `peak=90` axes given the same idle interval.
- Per-axis independence: a session contributing only to POW does not reset other axes' `lastContributionAt`.
- Ingest order: a session at `t = lastContributionAt + 14d` decays first, then applies gains — assert `profile.current` after ingest equals `floor + (preDecayCurrent − floor) × (1 − (14−7)/30) + delta`.

**UI snapshots (1b/1c/1d)**
- `ProfileBuildCard`: empty / mixed (v5 example) / saturated.
- `HomeBuildChipCard`: empty / mixed / saturated.
- `ScanBuildDeltaCard`: 2-scan / 5-scan histories.

**End-to-end manual QA (per PR merge)**
- Fresh user → onboarding (with + without seed survey selections) → first session → home shows non-zero hex.
- Power-only week → POW dominant, build name "Power-leaning Hybrid."
- Mixed week → "Balanced" if max−min < 15.
- Skip 7 days → reopen → currents identical to last close (grace period).
- Skip 37 days → reopen → currents at floor (70% of peak) across all axes, peaks unchanged.
- Train at day 14 of idle → gains land on partially-decayed current, not pre-decay value.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Bad contribution vectors → wrong builds emerge | Medium | High | Catalog JSON reviewed before Phase 1a merge. ~50 entries, 30 min skim. |
| Skill session ingest path missed → calisthenics underweighted | Medium | High | Phase 1a checklist enforces both `WorkoutLog` and `UserSkillProgress.Session` paths; unit test covers both. |
| Drift feels punishing despite gentle math | Low | Medium | TestFlight feedback loop. Knobs (`floor %`, `decayPerDay` slope) tunable in one place. |
| StatScore deletion breaks a forgotten consumer | Low | Medium | Phase 1d audit step. `grep StatScore` across project. Compile-time safety net. |
| Hex render perf on rank-up animation | Low | Low | SwiftUI Path-based shapes; profile if surprises. Defer bloom if needed. |
| User confusion: "where did my stats go?" | Medium | Low | Phase 1c TestFlight changelog: "Stats grid replaced with Build. Open Profile for full breakdown." |
| Onboarding seed prefill inflates starting position | Low | Low | Hard cap at +15; replay tests assert real training overtakes seed within ~2 weeks. |

---

## Sub-project handoffs

What this sub-project leaves for downstream work:

- **#2 Emergent Archetype**: consumes `AttributeProfile.dominant` + the full axis distribution to compute narrative build names. Replaces Phase 1b's simple `"-leaning Hybrid"` rule.
- **#3 Scan redesign**: extends `ScanBuildDeltaCard` into the full Build Analysis view; uses `attributeHistorySnapshots` already pinned in Phase 1d.
- **#4 Ascension Tier ring**: independent of attributes; uses streak + journey time. May read peak distribution for prestige flavoring.
- **#5 Trials**: trial contribution math reads `AttributeProfile` to apply build-specific bonuses.
- **#7 Onboarding rewrite**: subsumes the seed survey added in Phase 1a; survey screen may be reframed but the data write stays compatible.
