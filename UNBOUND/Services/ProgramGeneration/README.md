# ProgramGeneration

Deterministic, on-device training-program generation: turns scan/profile/progression inputs into a `TrainingProgram` (Calibration Week, then 28-day Arcs), resolves each day into the concrete workout draft, and handles block/arc rollover. No AI anywhere in this path — every decision is a pure function of its inputs.

## Files

| File | Purpose |
| --- | --- |
| `AccessoryBiasRefreshRule.swift` | Gates whether the next block's accessory bias refreshes from new focus input or carries forward (top-2 muscle-group match rule). |
| `ArcGenerator.swift` | Expands a completed Calibration Week program into the first 28-day Arc (preserving split shape, tagging session roles). |
| `BlockRolloverScheduler.swift` | Pure helpers mapping the active arc start date to the current day number / days remaining; `DevProgramClock` for dev time travel. |
| `BlockRolloverService.swift` | Orchestrates the 2-week-block rollover: `resolveRollover` (pure decision: bias + stale-exercise rotation) and `performRollover` (reads services, writes state). |
| `DailyWorkoutResolver.swift` | Resolves the base program day plus active modifiers (skill goals, equipment, trial prep, deload) into the draft that launches the active workout; defines `DailyWorkoutModifierContext`. |
| `DailyWorkoutResolver+DraftModifiers.swift` | Modifier pipeline for `TrainingSessionDraft`: substitution → trial prep → deload → short session. |
| `DailyWorkoutResolver+MovementSubstitution.swift` | Picks a same-slot replacement `CatalogExercise` for equipment/avoidance constraints. |
| `DailyWorkoutResolver+WorkoutModifiers.swift` | Modifier pipeline for legacy `Workout`: substitution → trial prep → skill-block taper → deload → short session. |
| `DayTemplate.swift` | Enum of what a training day emphasizes; drives split sequencing and per-day exercise pools. |
| `DeterministicProgramGenerator.swift` | Core pure generator: `ProgramGeneratorInput`/`ProgramCalibrationInput` → fully-formed `TrainingProgram`. |
| `DeterministicProgramGenerator+Metadata.swift` | Generator extension: program metadata. |
| `DeterministicProgramGenerator+MovementSelection.swift` | Generator extension: per-day exercise pool selection. |
| `DeterministicProgramGenerator+Prescription.swift` | Generator extension: sets/reps/RPE prescription. |
| `DeterministicProgramGenerator+Progression.swift` | Generator extension: progression-state-aware adjustments. |
| `DeterministicProgramGenerator+Schedule.swift` | Generator extension: weekday scheduling. |
| `DeterministicProgramGenerator+SessionDetails.swift` | Generator extension: session detail assembly. |
| `DeterministicProgramGenerator+WorkoutBuilder.swift` | Generator extension: builds the per-day `Workout`. |
| `ExerciseEquipmentClassifier.swift` | Compatibility facade — equipment categories read from MovementCatalog, unknown names fall back to the dumbbell/accessory bucket. |
| `ExerciseRefreshRule.swift` | Rotates exercises prescribed too many consecutive blocks without fresh stimulus (~3 blocks ≈ 6 weeks). |
| `LoadBiasApplier.swift` | Applies a Checkpoint `loadAdjustmentBias` (-1...1) to next-Arc prescriptions: recovery bias deloads volume/RPE, push bias raises both. |
| `MacroCalculator.swift` | Pure-function macro targets (`MacroTargets`) from bodyweight, stats, frequency, cut mode. |
| `MockProgramGenerationService.swift` | Mock `ProgramGenerationServiceProtocol` returning a canned 28-day program after a fake delay. |
| `ProgramBlockStore.swift` | Actor persistence for `ProgramBlock` records via `DatabaseService` (collection `"program_blocks"`). |
| `ProgramGenerationService.swift` | The live `ProgramGenerationServiceProtocol` implementation: calibration-first, then deterministic Arcs. |
| `ProgramGenerationServiceProtocol.swift` | Protocol: `generateProgram(analysis:userProfile:) async throws -> TrainingProgram`. |
| `ProgramPhaseEngine.swift` | Legacy evergreen phase engine — picks Accumulation/Intensification/etc. week-by-week from progression + recovery signals (distinct from `BlockRolloverScheduler`). |
| `ProgramScheduler.swift` | V3 weekly Push/Pull/Legs/Core/Skills/Conditioning/Rest routing of Program Focuses; defines `DayCategory`/`WeekPhase`; user-customizable schedule. |
| `RationaleBuilder.swift` | Builds the user-facing "Why this program" rationale from generator inputs — pure and honest, no copywriting magic. |
| `RegionFatigueBudget.swift` | Per-body-region fatigue accounting across planned/skill/vow/custom sources; recommends trims (`RegionTrimRecommendation`). |
| `RolloverCoordinator.swift` | Decides + executes the monthly rollover: prefer a fresh scan at the boundary, prompt for one, auto-roll after a grace window. |
| `SessionRoleTagger.swift` | Infers a `SessionRole` (push/pull/legs/rest/...) for a day, workout, or draft from title + muscle groups. |
| `SplitLookup.swift` | Deterministic (buildIdentity, frequency) → `Split` lookup; calisthenic branch gated on control-primary identities. |
| `SupabaseProgramService.swift` | Cloud-backed program persistence (`ProgramRemote`): saves after every generate, patches `current_program_id` on the user row. |
| `TrainingPrescriptionResolver.swift` | Overlays stored `ProgressionState` onto a draft's prescriptions so today's numbers reflect earned progression. |
| `WaveAdjuster.swift` | Applies wave adjustments to a program with a recorded rationale per change (`WaveAdjustment`/`WaveAdjustmentResult`). |
| `WeakPointBiaser.swift` | Converts focus-area inputs into per-muscle-group bias weights; biased candidate picking and accessory appends (generic over exercise type). |

## Where to find X

- **How a brand-new program gets generated** → `ProgramGenerationService.swift` → `DeterministicProgramGenerator.swift` (+ its extensions).
- **Why today's workout looks the way it does (modifiers, substitutions, deload)** → `DailyWorkoutResolver.swift` + its `+DraftModifiers`/`+WorkoutModifiers`/`+MovementSubstitution` extensions.
- **Monthly/block rollover and "days remaining"** → `RolloverCoordinator.swift`, `BlockRolloverService.swift`, `BlockRolloverScheduler.swift`.
- **Which exercises rotate or carry over between blocks** → `ExerciseRefreshRule.swift`, `AccessoryBiasRefreshRule.swift`.
- **Sets/reps/RPE numbers** → `DeterministicProgramGenerator+Prescription.swift` (generation), `TrainingPrescriptionResolver.swift` (progression overlay), `LoadBiasApplier.swift` (checkpoint bias).
- **Nutrition/macro targets** → `MacroCalculator.swift`.
