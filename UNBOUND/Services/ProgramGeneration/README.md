# Services/ProgramGeneration

Generates personalized 28-day training Arcs and one-week Calibration blocks from a user's scan, profile, progression state, and equipment — entirely on-device with no AI or network calls. The output is a `TrainingProgram`; every decision is a pure function of the `ProgramGeneratorInput` struct so generation is auditable, repeatable, and testable.

| File | Purpose |
|---|---|
| `ProgramGenerationServiceProtocol.swift` | Protocol: `generateProgram(analysis:userProfile:) async throws -> TrainingProgram` |
| `ProgramGenerationService.swift` | Production service: assembles `ProgramGeneratorInput` from live services then calls `DeterministicProgramGenerator.generate`. Entry point for scan-triggered and onboarding-triggered generation. |
| `MockProgramGenerationService.swift` | In-memory stub for tests. |
| `DeterministicProgramGenerator.swift` | Core pure enum; input → `TrainingProgram`. Schedules days, picks exercise pools, stamps nutrition + recovery defaults. |
| `DeterministicProgramGenerator+MovementSelection.swift` | Exercise pool selection logic (equipment filtering, split-day matching). |
| `DeterministicProgramGenerator+Prescription.swift` | Sets/reps/RPE prescription derivation per movement. |
| `DeterministicProgramGenerator+Progression.swift` | Seeding `ProgressionState` into prescriptions before generation. |
| `DeterministicProgramGenerator+Schedule.swift` | Maps a `Split` onto user-chosen training days, producing `ProgramDay` sequence. |
| `DeterministicProgramGenerator+SessionDetails.swift` | Session duration, difficulty, and metadata stamping. |
| `DeterministicProgramGenerator+WorkoutBuilder.swift` | Assembles individual `Workout` objects from movement lists and prescriptions. |
| `DeterministicProgramGenerator+Metadata.swift` | Top-level `TrainingProgram` metadata (name, description, arcs). |
| `ArcGenerator.swift` | Converts a completed Calibration Week into Arc 1, and chains subsequent Arcs using `CheckpointOutcome` load bias. |
| `BlockRolloverService.swift` | Orchestrates the 2-week block rollover: resolves bias refresh + exercise rotation, then generates the next program. |
| `BlockRolloverScheduler.swift` | Pure helpers: maps Arc start date → current day number, detects when rollover is due. |
| `RolloverCoordinator.swift` | Decides and executes the monthly rollover; prompts for a fresh scan or auto-rolls after a grace window. |
| `ProgramBlockStore.swift` | Actor-backed persistence for `ProgramBlock` records (`program_blocks` collection). |
| `ProgramPhaseEngine.swift` | Computes the current training phase (Accumulation/Intensification/Realization/Deload) from progression + recovery signals. |
| `ProgramScheduler.swift` | Routes training focuses to Push/Pull/Legs/Core/Skills/Conditioning/Rest day categories; user-customizable weekly schedule. |
| `SplitLookup.swift` | Deterministic `(buildIdentity, frequency)` → `Split` (ordered day templates). Calisthenic vs weights branch. |
| `DayTemplate.swift` | Enum of day-level training templates (push, pull, legs, upper, lower, fullBody, skill, weakPoint). |
| `DailyWorkoutResolver.swift` | Resolves a `TrainingSessionDraft` for a specific program day, applying equipment overrides and deload factors. |
| `DailyWorkoutResolver+DraftModifiers.swift` | Draft-level modifiers (short-session trim, trial prep injection). |
| `DailyWorkoutResolver+MovementHelpers.swift` | Equipment filtering and movement catalog lookups within the resolver. |
| `DailyWorkoutResolver+SkillBlocks.swift` | Skill-day block construction inside the resolver. |
| `DailyWorkoutResolver+WorkoutModifiers.swift` | Workout-level load/rep adjustments (deload factor, travel override). |
| `TrainingPrescriptionResolver.swift` | Overlays live `ProgressionState` weights onto a `TrainingSessionDraft` at session start. |
| `MacroCalculator.swift` | Pure Mifflin-St Jeor BMR × activity-factor macro calculator; cut mode reduces calories by 15%. |
| `NutritionTargetCalculator.swift` | Personalized hydration + protein targets from bodyweight and recent session history. |
| `WaveAdjuster.swift` | Applies mid-block wave adjustments (volume/intensity modulation) to an existing program. |
| `LoadBiasApplier.swift` | Applies a validated Checkpoint `loadAdjustmentBias` to next-Arc prescriptions (RPE + volume). |
| `WeakPointBiaser.swift` | Converts focus-area inputs into per-muscle-group weights; drives accessory selection bias. |
| `RegionFatigueBudget.swift` | Tracks cumulative regional fatigue from planned workouts, skill blocks, and vows to prevent overload. |
| `ExerciseRefreshRule.swift` | Rotates exercises that have been prescribed for 3+ consecutive blocks without a tier unlock or plateau deload. |
| `AccessoryBiasRefreshRule.swift` | Gates whether next-block accessory bias refreshes from new focus input or carries forward from the previous block. |
| `SessionRoleTagger.swift` | Pure classifier: assigns a `SessionRole` (push, pull, legs, etc.) to a workout or program day. |
| `RationaleBuilder.swift` | Pure builder: constructs the user-facing "Why this program" `ProgramRationale` from generator inputs. |
| `ExerciseEquipmentClassifier.swift` | Facade mapping exercise names to equipment categories (barbell/dumbbell/machine/bodyweight) for filtering. |
| `SupabaseProgramService.swift` | Cloud persistence bridge: saves generated programs to Supabase and patches `current_program_id` on the user row. |

## Where to find X

| Task | File(s) |
|---|---|
| Change how a new program is built | `DeterministicProgramGenerator.swift` + its `+` extensions |
| Change how Arcs chain or apply Checkpoint signals | `ArcGenerator.swift` |
| Change when / how the block rolls over | `BlockRolloverService.swift`, `RolloverCoordinator.swift`, `BlockRolloverScheduler.swift` |
| Change macro or nutrition targets | `MacroCalculator.swift`, `NutritionTargetCalculator.swift` |
| Change how exercise rotation or bias works | `ExerciseRefreshRule.swift`, `AccessoryBiasRefreshRule.swift`, `WeakPointBiaser.swift` |
