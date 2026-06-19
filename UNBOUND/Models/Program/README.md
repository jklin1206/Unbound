# Models/Program

Training-program model types: the generated program itself (days, waves, arcs), per-exercise progression state, and the user-facing knobs that shape it (training style/context, weight policy, cut mode, travel override, coach actions).

| File | Contents |
| --- | --- |
| `CoachAction.swift` | `CoachAction` — actionable coach suggestions (with `SwapScope`: session / week / programme). |
| `CutMode.swift` | `CutMode` — cut-phase toggle with start date and soft-cap weeks. |
| `Program.swift` | `TrainingProgram`, `ProgramDay`, `DifficultyLevel`, `Wave` / `ArcState` / `Arc` periodization types, `ProgramBodyRegion`. |
| `ProgramBlock.swift` | `ProgramBlock` — a persisted numbered block of a program for a user. |
| `ProgramRationale.swift` | `ProgramRationale` + nested `Decision` — why the generator made each program choice; `ProgramRationaleCopy` for display strings. |
| `ProgramSurfaceState.swift` | `ProgramSurfaceState` — what the Program tab surface shows (noProgram / loading / loadError / blockComplete…); proof-state enums and `ProgramProofProgramFactory`. |
| `ProgressionState.swift` | Per-exercise progression: `ProgressionState`, `BlockType`, `ProgressionPrescriptionBias`, `ExerciseClassification`, `ProgressionAdvance`, `ProgressionFamilyState`, `TierUnlock`, related notification names. |
| `TrainingFeedbackMode.swift` | `TrainingFeedbackMode` — how much feedback the user wants during training. |
| `TrainingStyle.swift` | `TrainingStyle` plus the program training-context system: scope/mode enums, `ProgramTrainingContextSelection` / `Resolution` / `Resolver`. |
| `TrainingWeightPolicy.swift` | `TrainingWeightUnit` (kg/lb) and `WeightPlatePolicy` — plate-rounding rules for prescribed weights. |
| `TravelOverride.swift` | `TravelOverride` / `TravelDay` — bounded bodyweight plan that replaces normal program days while traveling. |
| `Weekday.swift` | `Weekday` — Monday–Sunday enum with localized short/long labels. |

## Where to find X

- Program / day / wave / arc shape → `Program.swift`.
- Why the generator chose something (rationale copy) → `ProgramRationale.swift`.
- Per-exercise progression tracking and advances → `ProgressionState.swift`.
- Plate rounding or kg/lb unit handling → `TrainingWeightPolicy.swift`.
- Travel-mode replacement days → `TravelOverride.swift`.
- Program tab empty/loading/error surface states → `ProgramSurfaceState.swift`.
