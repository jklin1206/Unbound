# Progression

Progression owns how training adapts over time: programs, deloads, checkpoints, and generated workout structure.

## Active Model

The program layer answers "what should the user do next?" The completion layer answers "what did the user earn?" Keep those separate.

## Owners

- `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift`: deterministic plan generation.
- `UNBOUND/Services/ProgramGeneration/DailyWorkoutResolver.swift`: today's workout selection.
- `UNBOUND/Services/Program/ProgramStore.swift`: active program persistence/cache.
- `UNBOUND/ViewModels/ProgramViewModel.swift`: program screen coordination.
- `UNBOUND/Services/Progression/ProgressionEngine.swift`: adaptation and progression decisions.
- `UNBOUND/Services/Progression/AutoDeloadService.swift`: deload policy.

## Cleanup Notes

Program generation is rule-heavy but not inherently complex. Split by named policy only when a policy has a distinct reason to change: movement pool, schedule, prescription, compression, checkpoint, or deload.
