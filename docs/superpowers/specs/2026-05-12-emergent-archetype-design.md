# UNBOUND Emergent Archetype (BuildIdentity) — Design Spec

**Date:** 2026-05-12
**Sub-project:** #2 of 7 (Emergent Archetype)
**Status:** Locked — ready for implementation plan
**Predecessor:** [Sub-project #1 — Attribute System](./2026-05-12-attribute-system-design.md)

This sub-project replaces the chosen-at-onboarding `Archetype` enum (V-TAPER / HEAVYWEIGHT / SLEEPER / SHREDDED) with an emergent `BuildIdentity` derived from the user's `AttributeProfile`. The grounded athletic descriptor is the layer that finally lets every UI surface speak the same identity vocabulary; the `Archetype` enum and all its consumers are migrated and deleted.

---

## Why this exists

Sub-project #1 shipped the 6-axis attribute system with a placeholder `buildName` rule (`"Balanced"` or `"{Dominant}-leaning Hybrid"`). That placeholder is intentionally weak — it satisfies the data layer but doesn't carry the narrative weight needed for Profile, Home, Scan, RankUpCinematic, ReportShareView, or body-analysis copy generators. Sub-project #2 finishes the job.

In parallel, the existing `Archetype` enum is the legacy "pick your physique fantasy at onboarding" mechanism — the vision explicitly rejects it ("Discover who you become" > "Choose your physique fantasy"). User chose full replacement at brainstorm: every Archetype consumer migrates to `BuildIdentity`, then `Archetype` is deleted.

---

## Scope

### In scope (this sub-project)

1. New `BuildIdentity` value type derived from `AttributeProfile`.
2. Grounded athletic naming taxonomy — 20 distinct outputs across 5 distribution shapes.
3. Replace `AttributeProfile.buildName` implementation; keep alias for backward compat during migration.
4. Migrate every existing `Archetype` consumer across **12 files** (display, logic, cinematic, badge trigger, body analysis copy, program generation, onboarding picker).
5. Delete `Archetype` enum, `ArchetypeSpawnPoints`, `User.preferredArchetype`. Zero residual references.
6. New `AttributeKey.emphasisLifts` table for the aggregate-rank computation (replaces `Archetype.emphasisLifts`).

### Explicitly out of scope (other sub-projects / future work)

- **Earned `Title` layer** — fantasy-flavor reputation labels (Calisthenics God, Iron Monk, Sprint Demon, etc.) — separate future sub-project. Never blur with BuildIdentity (per `feedback_unbound_buildidentity_vs_titles`).
- **Scan verdict tone rewrite, photo-flow changes, share-card redesign** — sub-project #3.
- **Ascension Tier profile ring** — sub-project #4.
- **Trials, Squads** — sub-projects #5/#6.
- **Full onboarding reframe** (chapter cinematics, arc copy, paywall flow) — sub-project #7. Phase 2f does *minimum* surgery to keep onboarding working without the picker.
- **Skill-session ingest** — still deferred from sub-project #1; `UserSkillProgress.Session` doesn't exist yet.
- **Cosmetic/skin redesign** if archetype-keyed — audit + neutral swap in Phase 2c; full redesign deferred.
- **Archetype-keyed asset cleanup** (silhouette PNGs in `Resources/BodyMap/`, hero images) — leave on disk after 2g; harmless.

---

## Locked product decisions

| # | Decision | Value |
|---|---|---|
| 1 | Naming layer separation | **BuildIdentity = grounded athletic descriptor (auto-derived). Titles = earned fantasy flavor (manual unlock, separate sub-project).** Never blur. |
| 2 | Archetype enum future | **Fully replaced.** Sub-project #2 migrates every consumer + deletes the enum at end. |
| 3 | Migration scope | **All-in.** Sub-project #2 owns the full migration, not parallel coexistence. |
| 4 | Naming vocabulary per axis | POW → "Power" · AGI → "Movement" · CTL → "Control" · END → "Endurance" · MOB → "Mobility" · EXP → "Explosive" |
| 5 | Lean suffix per axis | POW → "-Oriented" · AGI/CTL/MOB → "-Focused" · END → "-Dominant" · EXP → " Athlete" (special — "Explosive" alone reads off) |
| 6 | Distribution shapes | 5 cases: `balancedAthlete` · `hybridAthlete` · `specialist` · `hybrid` · `lean` |
| 7 | Algorithm thresholds | `balancedAthlete` if `spread < 15` · `specialist` if `gap12 > 25` · `hybridAthlete` if `gap12 < 10 AND gap13 < 10` · `hybrid` if `gap12 < 10` · else `lean` |
| 8 | Total output count | 20 distinct displayName strings |
| 9 | Stability mechanism | Hysteresis is **structural** — `BuildIdentity` derives from `peak` (monotonic), so no extra logic needed |
| 10 | Persistence | None. `BuildIdentity` is a value type computed cheaply on every read. Truth lives in `AttributeProfile`. |
| 11 | Backward-compat | `AttributeProfile.buildName: String` stays as alias to `buildIdentity.displayName` for migration phases |
| 12 | Phasing | **7 phases (2a → 2g)**, each independently shippable |

---

## Data model

```swift
// MARK: - BuildIdentity
//
// Grounded athletic descriptor derived from AttributeProfile. Replaces the
// hand-picked Archetype enum (V-TAPER / HEAVYWEIGHT / SLEEPER / SHREDDED)
// across every consumer.
//
// Two-layer rule (per feedback_unbound_buildidentity_vs_titles):
//   BuildIdentity → grounded ("Power-Oriented", "Mobility Specialist").
//   Title         → expressive fantasy flavor, separate future system.

struct BuildIdentity: Equatable, Sendable {
    enum Shape: String, Codable, Sendable {
        case balancedAthlete       // spread < 15
        case hybridAthlete          // top3 within 10 pts of top1, AND gap12 < 10
        case specialist             // gap12 > 25
        case hybrid                 // gap12 < 10 AND NOT hybridAthlete
        case lean                   // 10 ≤ gap12 ≤ 25
    }

    let primary: AttributeKey?      // nil for balancedAthlete / hybridAthlete
    let secondary: AttributeKey?    // only set for .hybrid
    let shape: Shape

    var displayName: String { /* lookup — table below */ }
    var tagline: String     { /* per-shape, per-axis — table below */ }
}

extension AttributeKey {
    /// Grounded vocabulary per axis. Locked taxonomy.
    var buildVocab: String {
        switch self {
        case .power:         return "Power"
        case .agility:       return "Movement"
        case .control:       return "Control"
        case .endurance:     return "Endurance"
        case .mobility:      return "Mobility"
        case .explosiveness: return "Explosive"
        }
    }

    /// Suffix used by the .lean shape. Per-axis variation for natural English.
    var leanSuffix: String {
        switch self {
        case .power:         return "-Oriented"
        case .agility:       return "-Focused"
        case .control:       return "-Focused"
        case .endurance:     return "-Dominant"
        case .mobility:      return "-Focused"
        case .explosiveness: return " Athlete"
        }
    }

    /// Source phrase for tagline composition.
    var taglinePhrase: String {
        switch self {
        case .power:         return "heavy output"
        case .agility:       return "fast, lateral movement"
        case .control:       return "deliberate, controlled work"
        case .endurance:     return "long, sustained effort"
        case .mobility:      return "range-of-motion work"
        case .explosiveness: return "explosive, dynamic effort"
        }
    }

    /// Anchor lifts for aggregate-rank computation (Phase 2c). Replaces
    /// Archetype.emphasisLifts. Hand-authored. IDs must match
    /// `ExerciseLibrary.all` — verified at spec-write time against the
    /// committed catalog (66 entries).
    var emphasisLifts: [String] {
        switch self {
        case .power:         return ["barbell_back_squat", "conventional_deadlift", "barbell_bench_press", "barbell_ohp"]
        case .agility:       return ["bulgarian_split_squat", "lunges", "farmers_walk"]
        case .control:       return ["pull_up", "dips", "plank"]   // bodyweight + control-demanding
        case .endurance:     return ["leg_press", "leg_curl_lying", "conventional_deadlift"]   // hypertrophy + density anchors
        case .mobility:      return ["goblet_squat", "romanian_deadlift", "good_morning"]
        case .explosiveness: return ["bulgarian_split_squat", "lunges"]   // catalog has no true plyometrics yet
        }
    }
}
```

### displayName lookup table (20 outputs)

| Shape | Output template | Example |
|---|---|---|
| balancedAthlete | "Balanced Athlete" | — |
| hybridAthlete | "Hybrid Athlete" | — |
| specialist | "{vocab(primary)} Specialist" | Power Specialist · Mobility Specialist |
| hybrid | "{vocab(primary)} Hybrid" | Explosive Hybrid · Endurance Hybrid |
| lean | "{vocab(primary)}{leanSuffix(primary)}" | Power-Oriented · Endurance-Dominant · Explosive Athlete |

### tagline lookup table

| Shape | Tagline template | Example |
|---|---|---|
| balancedAthlete | "Even across every axis." | — |
| hybridAthlete | "Multi-axis athlete — no single specialty." | — |
| specialist | "Built around {taglinePhrase(primary)} — sharply focused." | "Built around heavy output — sharply focused." |
| hybrid | "Built around {taglinePhrase(primary)} with strong {vocab(secondary)}." | "Built around heavy output with strong Endurance." |
| lean | "Trending toward {taglinePhrase(primary)}." | "Trending toward heavy output." |

### Derivation algorithm

```swift
extension AttributeProfile {
    var buildIdentity: BuildIdentity {
        let sorted = AttributeKey.allCases
            .sorted { value(for: $0).peak > value(for: $1).peak }
        let top1 = sorted[0], top2 = sorted[1], top3 = sorted[2]
        let peaks = sorted.map { value(for: $0).peak }
        let spread = (peaks.max() ?? 0) - (peaks.min() ?? 0)

        if spread < 15 {
            return .init(primary: nil, secondary: nil, shape: .balancedAthlete)
        }
        let gap12 = value(for: top1).peak - value(for: top2).peak
        let gap13 = value(for: top1).peak - value(for: top3).peak

        if gap12 > 25 {
            return .init(primary: top1, secondary: nil, shape: .specialist)
        }
        if gap12 < 10 && gap13 < 10 {
            return .init(primary: nil, secondary: nil, shape: .hybridAthlete)
        }
        if gap12 < 10 {
            return .init(primary: top1, secondary: top2, shape: .hybrid)
        }
        return .init(primary: top1, secondary: nil, shape: .lean)
    }

    /// Backward-compat alias. Phases 2a–2f gradually migrate consumers to
    /// `buildIdentity` directly; this alias keeps existing call sites
    /// working in the meantime.
    var buildName: String { buildIdentity.displayName }
}
```

### Edge cases (locked behavior)

| Case | Behavior |
|---|---|
| Empty profile (all peaks = 0) | `spread = 0 < 15` → **Balanced Athlete** (correct — no signal, no false specialization) |
| Single axis trained (POW=30, rest=0) | `spread = 30`, `gap12 = 30 > 25` → **Power Specialist** |
| Two axes co-trained (POW=40, EXP=40, rest=0) | `gap12 = 0 < 10`, `gap13 > 10` → **Power Hybrid** (alphabetical/declaration-order tie-break) |
| Three axes co-trained (POW=EXP=AGI=40, rest=0) | `gap12 < 10` AND `gap13 < 10` → **Hybrid Athlete** |
| Saturated (every peak = 100) | `spread = 0 < 15` → **Balanced Athlete** |
| Threshold spread = 15 exactly | Strict `<` → escapes balanced; proceeds to gap logic |
| Threshold gap12 = 10 exactly | Strict `<` → falls to `.lean` |
| Threshold gap12 = 25 exactly | Strict `>` → falls to `.lean` |

---

## Archetype sunset map (12 consumers)

Status legend: 🟢 trivial display swap · 🟡 logic refactor · 🔴 deleted

| File | Current use | Migration |
|---|---|---|
| `Models/Archetype.swift` | The enum | 🔴 **Deleted in 2g** |
| `Models/User.swift` | `preferredArchetype: Archetype?` | 🔴 Field deleted in 2g |
| `Models/ArchetypeSpawnPoints.swift` | Archetype → starting attribute prefill | 🔴 **Deleted in 2g** — replaced by Phase 1a's onboarding seed survey |
| `Services/BodyAnalysis/BodyAnalysisService.swift` | Archetype-flavored coach copy | 🟡 **2d** — switch on `BuildIdentity.shape` |
| `Services/BodyAnalysis/LocalBodyInsightsService.swift` | Same | 🟡 **2d** |
| `Services/ProgramGeneration/MockProgramGenerationService.swift` | Stub archetype → program template | 🟡 **2e** — derive from `buildIdentity.primary`; balanced template for `balancedAthlete`/`hybridAthlete` |
| `ViewModels/BodyScanViewModel.swift` | Holds selected archetype during scan flow | 🟢 **2f** — field deleted with picker |
| `Views/Components/Unbound/ArchetypePickerCard.swift` | Onboarding pick card | 🔴 **Deleted in 2f** |
| `Views/BodyScan/ArchetypePickerView.swift` | Onboarding pick screen | 🔴 **Deleted in 2f** (kill `case archetype` in OnboardingStep + router) |
| `Views/Onboarding/OnboardingArchetypePreview.swift` | Preview hero post-pick | 🔴 **Deleted in 2f** |
| `Views/Onboarding/Steps/Step_Arc03_Path.swift` | Archetype-flavored "your path" copy | 🟡 **2f** — neutral copy (full reframe = sub-project #7) |
| `Views/Report/ReportShareView.swift` | Archetype name on share card | 🟢 **2c** — render `buildIdentity.displayName` |
| `Views/Report/BodyScoreCard.swift` | Same | 🟢 **2c** |
| `Services/Badges/BadgeService.swift` | `.archetypeChosen` trigger fired in onboarding | 🟡 **2b** — replace with `.firstBuildIdentityResolved` (fires once when `buildIdentity` leaves `.balancedAthlete`) |
| `Views/Components/Cinematic/RankUpCinematic.swift` | Takes `Archetype` for hero flavoring | 🟡 **2c** — signature accepts `BuildIdentity`; resolves Phase 1b deferral |
| `Views/Components/Cinematic/RankUpCinematicPresenter` | Loads `preferredArchetype` from profile | 🟡 **2c** — load `AttributeProfile`, read `buildIdentity` |
| `Models/RankCosmetics.swift` (if archetype-keyed) | Possibly per-archetype cosmetic | 🟡 **2c** — audit; neutral swap if needed |
| `RankService.archetypeRank(userId:archetype:)` | Aggregate rank over archetype's emphasis lifts | 🟡 **2c** — `aggregateRank(userId:)`; pulls `buildIdentity.primary` and the new `AttributeKey.emphasisLifts` table; top-3 average for balanced/hybridAthlete |

---

## Phasing

| Phase | Scope | Ship size | Acceptance |
|---|---|---|---|
| **2a — Foundation** | New `BuildIdentity.swift` · `AttributeKey.buildVocab/leanSuffix/taglinePhrase/emphasisLifts` extensions · swap `AttributeProfile.buildName` impl (alias to `buildIdentity.displayName`) | ~1 day, PR ~300 LOC | Profile/Home/Scan auto-upgrade (no UI code changes) · 10+ new BuildIdentity derivation tests pass · 2 existing buildName tests rewritten |
| **2b — Badge trigger** | `.firstBuildIdentityResolved` added to `BadgeTrigger` · `.archetypeChosen` removed · fire-site moved to `AttributeService.ingest` (fires on first `.balancedAthlete` → other transition) · catalog entries rewired | ~0.5 day, PR ~200 LOC | New transition tests pass · existing badge tests pass · manual smoke: fresh user → first session → trigger fires once |
| **2c — Cinematic + Report + RankService aggregate** | `RankUpCinematic` signature accepts `BuildIdentity` (resolves Phase 1b deferral) · `RankUpCinematicPresenter` reads `AttributeProfile` · `ReportShareView` + `BodyScoreCard` render `buildIdentity.displayName` · `RankCosmetics` audit · `RankService.aggregateRank(userId:)` replaces `archetypeRank` · `AttributeKey.emphasisLifts` consumed | ~1.5 days, PR ~600 LOC | All cinematic + report tests rewritten · aggregate rank computes correctly for each Shape · A-tier attribute cinematic now fires |
| **2d — Body analysis copy** | `BodyAnalysisService` + `LocalBodyInsightsService` switch from `Archetype`-keyed copy to `BuildIdentity.shape`-keyed copy | ~0.5 day, PR ~300 LOC | Coach-voice copy renders for every Shape · existing copy tests rewritten |
| **2e — Program generation** | `MockProgramGenerationService` + production generator: template selection from `buildIdentity.primary`; balanced template for ambiguous shapes · `ProgramTemplate.forBuildIdentity(_:)` factory | ~1 day, PR ~400 LOC | Each Shape produces a valid program · existing generator tests rewritten · no template-library changes |
| **2f — Onboarding picker deletion** | Delete `Step04_PickArchetype` (or equivalent step in `OnboardingStep` + router) · delete `ArchetypePickerCard/View`, `OnboardingArchetypePreview` · neutral-copy `Step_Arc03_Path` · remove `archetype` field from `OnboardingFlowViewModel` and `BodyScanViewModel` · grep verifies no `flow.archetype` consumers remain | ~1 day, PR ~400 LOC deletions / ~100 LOC neutral copy | Onboarding completes end-to-end without picker · existing onboarding tests rewritten · BuildSeed step (Phase 1a) still works |
| **2g — Final cleanup** | Delete `Models/Archetype.swift`, `Models/ArchetypeSpawnPoints.swift` · remove `User.preferredArchetype` · audit zero residual refs via `grep` | ~0.5 day, PR ~500 LOC deletions | `grep "Archetype" UNBOUND/ UNBOUNDTests/` returns zero · full build clean · all test suites pass |

**TestFlight checkpoint:** after 2c, the app is shippable with `Archetype` still present (silent dual-system). 2d–2g are required to remove the picker UI cleanly. Recommend TestFlight cut at end of 2c.

---

## Testing strategy

Detailed per-phase test list lives in this spec's parent design doc; abbreviated here for the implementation plan:

**Phase 2a (BuildIdentity derivation)** — *the critical test surface.* Covers algorithm correctness:
- Empty profile → `.balancedAthlete`
- Single high axis → `.specialist`
- Two co-trained → `.hybrid`
- Three co-trained → `.hybridAthlete`
- All saturated → `.balancedAthlete`
- Strict-boundary tests: spread=15, gap12=10, gap12=25, gap12=26
- All 20 displayName outputs (one per (Shape, axis) cell)
- All 5 tagline outputs
- Backward-compat: `buildName == buildIdentity.displayName`

**Phase 2b** — first-resolved-fires-once invariant. Subsequent transitions silent.

**Phase 2c** — aggregate rank for each Shape uses correct emphasis-lift set. Cinematic accepts BuildIdentity. Copy per Shape distinct.

**Phase 2d** — coach copy renders for each Shape.

**Phase 2e** — each Shape produces a valid program template.

**Phase 2f** — E2E onboarding completes without archetype picker, no `preferredArchetype` written.

**Phase 2g** — no new tests; the green build is the gate.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `RankService.archetypeRank` consumers missed during 2c → runtime nil on Profile | Medium | High | grep audit at 2c open; every caller migrated or build fails |
| `AttributeKey.emphasisLifts` table is wrong → aggregate rank off | Medium | Medium | Table hand-authored in 2c per spec above; reviewed before merge |
| Onboarding picker deletion (2f) breaks downstream step | Medium | High | grep `flow.archetype`; every reference migrated; manual E2E test |
| Program template selection maps a Shape wrong → poor user program | Medium | Medium | Default to balanced for ambiguous; existing template library unchanged |
| Badge trigger misfires after 2b | Low-medium | Low | Transition-rule unit test; TestFlight smoke |
| Archetype-keyed asset references dangle in 2g | Low | Low | 2g audit catches dangling refs; assets stay on disk (unused, harmless) |
| `BuildIdentity` flips between sessions → user confusion | Low | Low | Structural hysteresis via `peak` monotonicity |
| Test rewrites become inconsistent across phases | Medium | Medium | Each phase owns its test migration; reviewer checks rewrites with code |

---

## Sub-project handoffs

What this sub-project leaves behind for downstream work:

- **#3 Scan redesign** — `BodyAnalysisService` already uses BuildIdentity (Phase 2d); #3 reframes verdict tone + photo flow on that base.
- **#4 Ascension Tier** — independent of BuildIdentity; profile ring + journey time are separate.
- **#5 Trials** — trial scoring/contribution may read `BuildIdentity.shape` for axis weighting.
- **#7 Onboarding rewrite** — Phase 2f leaves onboarding working without the picker; full reframe (chapter cinematics, arc copy) lives in #7.
- **Future Title sub-project** — earned fantasy-flavor labels live in their own future sub-project. NEVER blur with BuildIdentity per `feedback_unbound_buildidentity_vs_titles`.
