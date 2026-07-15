# Progression

Progression owns how training adapts over time: programs, deloads, checkpoints, and generated workout structure.

## Active Model

The program layer answers "what should the user do next?" The completion layer answers "what did the user earn?" Keep those separate.

Generated 30-day Arcs carry a four-part loading wave (accumulation, build, intensification, planned deload). At session launch, `TrainingPrescriptionResolver` overlays the latest per-movement `ProgressionState`, so completed-session over-performance can change the next prescription without rewriting the user's authored program. Loaded movements seed from calibration/log proof; timed isometrics retain seconds and progress on movement-specific duration ladders.

## Owners

- `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift`: deterministic plan generation.
- `UNBOUND/Services/ProgramGeneration/DailyWorkoutResolver.swift`: today's workout selection.
- `UNBOUND/Services/Program/ProgramStore.swift`: active program persistence/cache.
- `UNBOUND/ViewModels/ProgramViewModel.swift`: program screen coordination.
- `UNBOUND/Services/Progression/ProgressionEngine.swift`: adaptation and progression decisions.
- `UNBOUND/Services/Progression/AutoDeloadService.swift`: deload policy.

## Cleanup Notes

Program generation is rule-heavy but not inherently complex. Split by named policy only when a policy has a distinct reason to change: movement pool, schedule, prescription, compression, checkpoint, or deload.
