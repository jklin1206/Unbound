# Attribute System + BuildIdentity — Additive Design (sub-projects #1 + #2)

**Status:** Spec.
**Branch:** New `attr-system-v2` off current `program-redesign` HEAD.
**Supersedes:** `2026-05-12-attribute-system-design.md` and `2026-05-12-emergent-archetype-design.md`. Those specs assumed permission to redesign the Home hero, which was incorrect.
**Reference implementation:** `/Users/jlin/Documents/toji/UNBOUND-attr-system/` — math, models, services, tests are salvageable as-is. UI integration must follow this spec, not the reference branch.

---

## Goal

Replace the legacy 4-stat StatScore system and the picker-based Archetype system with a single training-derived identity layer:

- **6-axis Build hex** (Power / Endurance / Mobility / Strength / Conditioning / Technique) computed from real workout logs
- **BuildIdentity** (Power-Oriented, Mobility Specialist, Hybrid, etc.) auto-derived from the hex
- Both surface on Home (compact) and Profile (full)

Two redundant power systems collapse into one earned-through-training system. No user picks "what they are" anymore; the training does.

## Hard additive constraint

The current Home is an action surface. The following modules MUST render unchanged after this PR ships:

- "Move, [Name]" greeting
- "Foundation · Push is ready" subhead (Today's Mission)
- TODAY STATUS / TRAIN / [muscle group] / RANK card (top hero with gradient + level + XP bar)
- **BEGIN SESSION** large violet CTA
- SESSION PLAN list (3 exercises with RPE chips)
- COACH CUE inline card
- Week path / 21 DAY STREAK chips at bottom

A snapshot test locks this in (see Testing). If this PR alters the visible structure of these elements, it fails review.

## Out of scope

Deferred to separate specs (each gets its own brainstorm):
- Scan flow redesign (#3 — keeps existing scan screens for now)
- Ascension Tier 9-tier per-skill ladder (#4)
- Trials (#5)
- Squads (#6)

---

## Architecture

### Models (all new, no replacements)

| File | Purpose |
|---|---|
| `Models/AttributeKey.swift` | 6-axis enum + vocab + emphasis lifts per axis |
| `Models/AttributeValue.swift` | peak + current + per-axis rank-title derivation |
| `Models/AttributeContribution.swift` | per-exercise contribution vectors loaded from JSON |
| `Models/AttributeProfile.swift` | aggregate (current/peak across all axes) + dominant/weakest/buildName |
| `Models/AttributeRankUpEvent.swift` | notification payload posted when an axis crosses a tier |
| `Models/BuildIdentity.swift` | Shape enum + displayName + tagline derivation |

### Services (all new, in `Services/Attributes/`)

| File | Purpose |
|---|---|
| `AttributeCatalog.swift` | Loads `AttributeContributions.json`, parses contribution vectors |
| `AttributeDrift.swift` | Peak-independent decay math (axis values decay if axis hasn't been trained in N days) |
| `AttributeIngest.swift` | Walks a `WorkoutLog`, computes per-axis deltas, detects tier crossings |
| `AttributeProfileStore.swift` | UserDefaults-backed persistence per user, including scan history snapshot |
| `AttributeService.swift` | Protocol + production impl + mock. Wires into `ServiceContainer`. Public entry point. |

### Resources

- `Resources/AttributeContributions.json` — 66-exercise contribution catalog

### UI components (all new — these are the additive cards)

| File | Surfaces on |
|---|---|
| `Views/Components/AttributeHex.swift` | Pure renderer, used inside other cards |
| `Views/Components/AttributeRankUpToast.swift` | `.attributeRankUpToast()` view modifier; listens for `.attributeRankUpEvent`; auto-dismiss after 3s |
| `Views/Home/HomeBuildChipCard.swift` | Compact hex preview + Build name. Goes on Home. |
| `Views/Profile/BuildAttributeCell.swift` | One row: axis name + bar + numeric value + per-axis rank title pill |
| `Views/Profile/ProfileBuildCard.swift` | Full hex + buildName + 3×2 attribute grid built from BuildAttributeCell |
| `Views/Scan/ScanBuildDeltaCard.swift` | Hex split (before/after) + per-axis delta strip |
| `Views/Onboarding/Steps/Step_BuildSeed.swift` | Onboarding step replacing the archetype picker slot |

---

## UI integration

### Home (`UnboundHomeView.swift`)

- **Untouched:** Everything from the "Move, [Name]" greeting down through the COACH CUE card and streak chips.
- **Removed:** The current 4-stat 2×2 grid (`statRow` helper, Strength/Stamina/Technique/Vitality cells). Lives directly below SESSION PLAN.
- **Added:** `HomeBuildChipCard` slotted in the same vertical position the 4-stat grid occupied. Roughly same height (compact hex preview + Build name on a single card).
- **Modifier:** `.attributeRankUpToast()` applied at the view root.

### Profile (`ProfileView.swift`)

- **Removed:** The existing archetype display card (anime archetype tagline + cosmetic).
- **Added:** `ProfileBuildCard` — full hex + buildName + 3×2 per-axis grid using `BuildAttributeCell`.
- **Modifier:** `.attributeRankUpToast()` applied at the view root.

### Onboarding

- **Removed:** `Step04_PickArchetype` (anime picker view + step routing).
- **Removed:** `OnboardingArchetypePreview` view.
- **Removed:** Archetype rotation gallery from `Step_Arc03_Path`.
- **Added:** `Step_BuildSeed` in the onboarding step ordering where `Step04_PickArchetype` used to live. User picks up to 2 axes they want to tilt toward; writes a +15 prefill on each axis as the seed AttributeProfile.
- **Rewritten copy:** `Step_Arc03_Path` and `Step_Verdict` archetype-keyed copy → generic copy that uses BuildIdentity vocabulary if an identity has resolved (and falls back to neutral wording otherwise).

### Scan (`ScanPayoffView.swift`)

- **Added:** `ScanBuildDeltaCard` injected behind a ≥2-scan gate (first scan has nothing to compare).
- **No other scan changes.** Broader scan redesign is sub-project #3.

### Cinematic surfaces

- `RankUpCinematic`, `RankUpShareCard`: accept BuildIdentity instead of Archetype. Replace silhouette watermark (Archetype-keyed asset) with hex glyph at same position.

---

## Deletions

### StatScore stack
- `Models/StatScore.swift`
- `Services/Stats/StatScoreService.swift`
- All `ServiceContainer.statScore` references; replace with `attribute: AttributeServiceProtocol`
- 4-stat 2×2 grid component on Home
- StatScore display on Profile

### Archetype stack
- `Models/Archetype.swift` (recover co-located `MuscleGroup`, `ScanAngle`, `LoadingState` into their own files; verify all import sites)
- `Models/ArchetypeSpawnPoints.swift` (verify no skill-tree spawn-positioning callers remain; if any, replace with neutral default positioning)
- `UserProfile.preferredArchetype` Firestore field
- `Views/BodyScan/ArchetypePickerView.swift`
- `Views/Components/ArchetypeCard.swift`
- `Views/Components/Unbound/ArchetypePickerCard.swift`
- `Views/Onboarding/OnboardingArchetypePreview.swift`
- `Views/Onboarding/Steps/Step04_PickArchetype.swift`
- `RankService.archetypeRank(userId:archetype:)` method (replaced by `aggregateRank(userId:)`)
- `archetype:` params on all `ProgramGeneration` entry points (`ProgramBuilder`, `LocalProgramGenerator`, `DeterministicProgramGenerator`, `BlockRolloverService`, `ProgramPhaseEngine`, `SplitLookup`, `ProgramGenerationPrompt`) → `buildIdentity:`
- `BodyAnalysis.targetArchetype: Archetype` → `buildIdentitySnapshot: String?`
- `BodyAnalysisPrompt` archetype interpolation → buildIdentity label
- `Badge.archetypeChosen(Archetype)` case → `firstBuildIdentityResolved(BuildIdentity)`; badge id `archetype_chosen` → `first_build_resolved`. No migration needed — no production users.
- `Models/RankState.swift` `Archetype.emphasisLifts` extension reference (now lives on `AttributeKey`)

### Behavioral notes

- No production users exist. Firestore decode failures for hypothetical legacy records are acceptable. No badge migration table needed.
- ServiceContainer's mock variant must add the new `attribute` slot wired to `MockAttributeService`.

---

## Data flow

### Steady state

After every workout, inside `WorkoutLogService.saveLog`, after the existing ProgressionEngine + SkillProgressService + Trials hooks (in that order), call:

```swift
await AttributeService.shared.ingest(log: log)
```

`AttributeService.ingest`:
1. Walks `log.exerciseEntries`
2. Looks up each in `AttributeCatalog`
3. Accumulates per-axis contribution vectors
4. Reads existing profile from `AttributeProfileStore`
5. Applies drift (peak-independent decay since last update)
6. Adds today's contributions; updates peak per axis
7. Persists updated profile
8. For each axis that crossed a tier threshold, posts `.attributeRankUpEvent` with the axis + new tier + buildName

UI observers (`HomeBuildChipCard`, `ProfileBuildCard`, `AttributeRankUpToast`) refresh on these notifications.

### First launch (new user)

`AttributeProfileStore.load(userId:)` returns nil → `AttributeService` checks for existing `workoutLogs` via DatabaseService. If any exist, replay them through `ingest` in chronological order. This backfills the hex from real training data. After replay, drift runs forward from the most recent log timestamp.

### Onboarding flow (new user, no logs)

`Step_BuildSeed` writes a +15 prefill on user-selected axes (up to 2) into the initial AttributeProfile snapshot. Values are tuned so 3-4 real workouts overtake the prefill. The seed is annotated `seededFromOnboarding: true` in the persisted profile for observability.

---

## Acceptance criteria

A PR satisfies this spec iff:

1. **Session-flow snapshot test passes** — `UnboundHomeViewSessionFlowTests` asserts the existence and approximate position of Move/Foundation/BEGIN SESSION/SESSION PLAN/COACH CUE/streak chips on Home after the StatScore→Build swap.
2. **All test files from `attr-system-impl` pass** — 10 test files covering models, catalog, service, drift, ingest, RankService aggregate, ProfileBuildCard snapshot.
3. **Manual sim verification** — Home renders with the new chip card in the 4-stat grid's old slot; Profile renders the new ProfileBuildCard; session-flow modules visually unchanged.
4. **No StatScore or Archetype references** — `grep -rn "StatScore\|Archetype\|preferredArchetype" UNBOUND/` returns only the deleted-file diffs and import statements that should also be removed.
5. **Toast verification** — Manually log a workout (or run a fixture) that crosses an axis tier; the `.attributeRankUpToast` appears + auto-dismisses.
6. **First-launch backfill** — Existing simulator user with workout history sees a populated hex on first launch with the new build (verified manually).

---

## Testing

### Reused from `attr-system-impl`
- `UNBOUNDTests/Models/AttributeKeyTests.swift`
- `UNBOUNDTests/Models/AttributeValueTests.swift`
- `UNBOUNDTests/Models/AttributeContributionTests.swift`
- `UNBOUNDTests/Models/AttributeProfileTests.swift`
- `UNBOUNDTests/Models/BuildIdentityTests.swift`
- `UNBOUNDTests/Catalog/AttributeContributionCatalogTests.swift`
- `UNBOUNDTests/Services/AttributeServiceDriftTests.swift`
- `UNBOUNDTests/Services/AttributeServiceIngestTests.swift`
- `UNBOUNDTests/Services/RankServiceAggregateTests.swift`
- `UNBOUNDTests/Views/ProfileBuildCardSnapshotTests.swift`

### New for this spec
- `UNBOUNDTests/Views/UnboundHomeViewSessionFlowTests.swift` — snapshot or accessibility-tree assertion that the session-flow modules render in expected order. This is the additive-constraint enforcement.

---

## Architecture decisions worth flagging in the plan

These come up in implementation and the plan should call them out explicitly so the implementer doesn't re-litigate:

1. **`Archetype.swift` co-locates `MuscleGroup`, `ScanAngle`, `LoadingState`.** Per [[feedback_check_colocated_types_before_deleting]], before `git rm`, grep `^enum|^struct|^class|^protocol` on the file and split each non-archetype type into its own file.
2. **`SubRank.displayName` semantic.** The reference branch changed `displayName` to return rank-title text ("Initiate") instead of letter grade ("E-"). Keep the letter-grade `displayName` and add `rankTitleName` as a parallel property. Existing rank-letter UI must not silently shift.
3. **Program generation API change.** All entry points lose `archetype:` and gain `buildIdentity:`. Update call sites in the same commit as the API change to keep the build green.
4. **`UserProfile` Codable.** Removing `preferredArchetype` is fine; no users on disk to break. Add `seededBuildAxes: [AttributeKey]?` if BuildSeed-derived axes need to persist on the user record (decide during plan).
5. **`HomeBuildChipCard` height target.** Match the existing 4-stat grid's vertical footprint so the screen layout below (last-session recap, etc.) doesn't shift on devices with tight vertical real estate.

---

## Related memory

- [[feedback_unbound_additive_not_redesign]] — new modules slot alongside; this spec respects that by leaving the session-flow hero untouched.
- [[feedback_verify_visual_diff_before_claiming_additive]] — implementation must screenshot Home pre/post and confirm session-flow visually intact before merge.
- [[feedback_check_colocated_types_before_deleting]] — applies to Archetype.swift deletion.
- [[project_unbound_attribute_system_spec]] — original spec; supersede with this doc.
- [[feedback_unbound_buildidentity_vs_titles]] — BuildIdentity uses grounded vocab (Power-Oriented). Fantasy flavor lives in earned Titles, not here.
