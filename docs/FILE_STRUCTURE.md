# UNBOUND File Structure

This is the first map to read before traversing the repo. It explains what each directory owns, where source-of-truth code lives, and which folders are local scratch versus shippable app state.

## Top-Level Map

| Path | Role | Notes |
| --- | --- | --- |
| `UNBOUND/` | iOS app target source, bundled assets, resources | Most day-to-day product work happens here. |
| `UNBOUNDTests/` | Unit and integration tests for the app target | Mirror app subsystem names when adding tests. |
| `project.yml` | XcodeGen source of truth | Regenerate the Xcode project instead of hand-editing `project.pbxproj`. |
| `UNBOUND.xcodeproj/` | Generated Xcode project | `project.pbxproj` is ignored because it is generated. |
| `docs/` | Durable architecture, specs, handoffs, audits | Active maps live at the docs root; dated plans/specs are historical context. |
| `scripts/` | Local maintenance and generation scripts | Scripts should be repeatable and safe to run from the repo root. |
| `supabase/` | Supabase project config and migrations | Keep database changes traceable here. |
| `trailer/` | Separate trailer/remotion-style web project | Treat as its own sub-project. |
| `docs/legacy/` | Archived code/docs kept only for historical context | Nothing here is active app source. Move old platform code here instead of leaving it under `UNBOUND/`. |
| `generated-reward-assets/` | Checked-in reward asset source/output set | Do not mix one-off previews here unless they are meant to ship. |
| `generated-skill-media/` | Checked-in skill media source/output set | Keep naming aligned with `SkillIcons` and skill IDs. |
| `onboarding-preview/` | Preview/support media for onboarding | Promote only intentional shipped assets into `UNBOUND/Assets.xcassets`. |
| `LocalArtifacts/` | Ignored local build, audit, preview, and research output | Safe place for generated junk. |
| `exports/` | Ignored local export target | Use for videos, screenshots, and temporary share assets. |

## App Target Map

| Path | Owns |
| --- | --- |
| `UNBOUND/App/` | App entry point, top-level bootstrapping, dependency setup. |
| `UNBOUND/Models/` | Domain types, catalogs, value objects, skill/rank/movement definitions. Prefer this for pure data shape. |
| `UNBOUND/Services/` | Business logic, persistence, APIs, ingest, sync, ranking, rewards, logging. Prefer this for side effects. |
| `UNBOUND/ViewModels/` | Screen and flow state that coordinates models/services for SwiftUI. |
| `UNBOUND/Views/` | SwiftUI screens and reusable visual components. Keep business rules out when possible. |
| `UNBOUND/Utilities/` | Small shared helpers, extensions, localization helpers. Avoid turning this into a second services layer. |
| `UNBOUND/Assets.xcassets/` | Shipped image/color asset catalog. Every asset here should have a resolver or direct `UIImage/Image` load path. |
| `UNBOUND/Resources/` | Localized strings, sounds, raw resource files, and resource-specific docs. |
| `UNBOUND/assets/brand/` | Brand source assets outside the Xcode asset catalog. Promote only runtime-needed files into `Assets.xcassets`. |

## Active Source Of Truth

| System | Primary files |
| --- | --- |
| App shell | `UNBOUND/App/UnboundApp.swift` |
| Movement library | `UNBOUND/Models/MovementCatalog.swift`, with legacy gym seeds in `UNBOUND/Models/ExerciseCatalog.swift` |
| Skill tree | `UNBOUND/Models/SkillTree.swift`, `UNBOUND/Models/SkillTreeContent.swift`, `UNBOUND/Models/SkillTreeContent/Tiers/` |
| Skill progress | `UNBOUND/Services/SkillProgress/SkillProgressService.swift` |
| Ranking and proof | `UNBOUND/Models/SkillTier.swift`, `UNBOUND/Services/Ranking/RankService.swift`, `UNBOUND/Services/Ranking/ProofEngine.swift` |
| Session completion ingest | `UNBOUND/Services/TrainingCompletionService.swift` |
| Program generation | `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift`, `ProgramPhaseEngine.swift`, `DailyWorkoutResolver.swift`, `ProgramBlockStore.swift` |
| Program state | `UNBOUND/Services/Program/ProgramStore.swift`, `UNBOUND/ViewModels/ProgramViewModel.swift` |
| Progression | `UNBOUND/Services/Progression/ProgressionEngine.swift`, `MovementProgressService.swift`, `AutoDeloadService.swift` |
| Attributes | `UNBOUND/Services/Attributes/AttributeService.swift`, `AttributeIngest.swift` |
| Rewards | `UNBOUND/Models/WorkoutRewardSequence.swift`, `UNBOUND/Views/Components/Unbound/WorkoutRewardSequenceView.swift`, `UNBOUND/Views/Components/Unbound/WorkoutRewardComponents.swift` |
| Routines | `UNBOUND/Models/Routine.swift`, `RoutineStep.swift`, `UNBOUND/Services/Routine/` |
| Localization | `UNBOUND/Resources/Localizable.xcstrings`, `UNBOUND/Utilities/Localization/` |

When this table disagrees with [ARCHITECTURE.md](ARCHITECTURE.md), inspect the code first, then update both docs in the same change.

## Asset Structure

| Asset family | Location | Naming / resolver |
| --- | --- | --- |
| Rank title art | `UNBOUND/Assets.xcassets/RankTitles/`, `CinematicTiers/` | `RankTitle.assetName` / tier image calls. |
| Reward art | `UNBOUND/Assets.xcassets/RewardAssets/`, `BadgeArt/` | `WorkoutRewardSequence`, badge/reward models. |
| Skill phase icons | `UNBOUND/Assets.xcassets/SkillIcons/` | Skill IDs plus `_phaseN`; used by form/skill phase views. |
| Skill infographics | `UNBOUND/Assets.xcassets/SkillInfographics/` | Skill detail and educational surfaces. |
| Exercise visuals | `UNBOUND/Assets.xcassets/exercise_visual_*.imageset` | Dynamic. See `ExerciseVisualAsset` in `UNBOUND/Views/Components/ExerciseVisualView.swift`. |
| Mobility references | `UNBOUND/Assets.xcassets/mobility_reference_*.imageset` | `RoutineStep.reference` / routine player visuals. |
| Routine challenge art | `UNBOUND/Assets.xcassets/routine_challenge_*.imageset` | `RoutineDef` IDs and routine browsing UI. |
| Raw sounds | `UNBOUND/Resources/Sounds/` | Loaded as bundle resources, not image assets. |

Plain grep is not enough for `exercise_visual_*` assets. The app builds names dynamically from:

- `MovementCatalog` IDs such as `exercise.*`, `cardio.*`, `carry.*`, `mobility.*`, and `skill-drill.*`
- `ExerciseVisualAsset.assetNameCandidates(forMovementId:)`
- `SkillTraditionalVisualResolver` in `UNBOUND/Views/Home/SkillTraditionalVisualResolver.swift`
- Exact fallback strings in routine and skill-detail code

Run this before deleting exercise visuals:

```bash
python3 scripts/audit_exercise_visual_assets.py
```

Review any reported orphan candidates by searching both the exact asset name and the movement/skill slug it came from.

## Artifact Hygiene

Keep the repo split into four buckets:

| Bucket | Goes here | Does not go here |
| --- | --- | --- |
| Shipped source | `UNBOUND/`, `UNBOUNDTests/`, `supabase/`, `trailer/` | One-off generated previews. |
| Durable docs | `docs/`, `README.md`, `AGENTS.md` | Scratch logs and temporary reports. |
| Shipped assets | `UNBOUND/Assets.xcassets`, intentional checked-in generated asset folders | Preview videos, temporary GIFs, dead `.removed` files. |
| Local scratch | `LocalArtifacts/`, `exports/`, DerivedData paths | App source or docs that should be reviewed. |

Do not add `_trash/`, `_archive/`, `*.removed`, or root-level preview media. Git history is the archive. If context matters, write a short handoff under `docs/superpowers/handoff/` or update the relevant durable doc.

## Historical Docs

`docs/superpowers/specs`, `docs/superpowers/plans`, `docs/superpowers/handoff`, `docs/legacy/`, root `docs/PHASE*`, root `docs/WS-*`, and proposal docs contain dated implementation context unless they are linked from [ARCHITECTURE.md](ARCHITECTURE.md). They are useful for why something exists, but they are not proof that a code path is still active. Prefer these sources in order:

1. Current source code.
2. `docs/FILE_STRUCTURE.md` and `docs/ARCHITECTURE.md`.
3. Recent handoff docs.
4. Older plans/specs.

## Dead Code And Asset Checklist

Before deleting code or assets:

1. Search exact type/file/asset names with `rg`.
2. Search semantic slugs and aliases, not just exact names.
3. For `exercise_visual_*`, run `python3 scripts/audit_exercise_visual_assets.py`.
4. Check whether hits are active source, tests, generated docs, or historical plans.
5. Build if the deletion touches app source or bundled assets.
6. Call out pre-existing dead code separately from dead code created by the current change.

Useful search commands:

```bash
rg -n "OldTypeName|oldEntryPoint|old_asset_name"
rg -n "movement-slug|Skill Node Title" UNBOUND/Models UNBOUND/Views UNBOUND/Services
git status --short --untracked-files=all
```
