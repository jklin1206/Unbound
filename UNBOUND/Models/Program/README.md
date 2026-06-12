## Models/Program

Training program lifecycle: the generated plan, its blocks, progression tracking, coaching actions, and all the configuration enums that shape how a program is built and adapted.

| File | Purpose |
|------|---------|
| `Program.swift` | `TrainingProgram` — top-level AI-generated training plan keyed to a scan and analysis |
| `ProgramBlock.swift` | `ProgramBlock` — a numbered phase within a program; tracks start/end dates |
| `ProgramRationale.swift` | `ProgramRationale` — records why the coach made a specific adjustment (load change, exercise swap, etc.) |
| `ProgramSurfaceState.swift` | `ProgramSurfaceState` — UI-facing enum describing what the Program tab should show (rest day, training day, error, etc.) |
| `ProgressionState.swift` | Per-user per-exercise progression tracker; written by `ProgressionEngine`, read by home/session/coach views |
| `TrainingStyle.swift` | `TrainingStyle` enum — bodyweight / free weights / hybrid / machines |
| `TrainingWeightPolicy.swift` | `TrainingWeightUnit` and weight-policy rules governing how loads are expressed (kg vs lb) |
| `TravelOverride.swift` | `TravelOverride` — deterministic bodyweight plan that replaces normal training days for a bounded window |
| `CutMode.swift` | `CutMode` — flag + metadata indicating the user is in a caloric deficit phase |
| `CoachAction.swift` | `CoachAction` enum — discrete adjustments the AI coach can apply (swap, deload, rep-range change, plateau ack) |
| `TrainingFeedbackMode.swift` | `TrainingFeedbackMode` enum — silent / quick / detailed post-session feedback verbosity |
| `Weekday.swift` | `Weekday` enum — Mon–Sun, `Codable`, used for rest-day scheduling and program day mapping |

### Where to find X

- **Read or render today's training day** → `ProgramSurfaceState.swift`, `Program.swift`
- **Understand why a load was changed** → `ProgramRationale.swift`
- **Apply a coach swap or deload** → `CoachAction.swift`
- **Check travel mode / bodyweight override** → `TravelOverride.swift`
- **Track current working weights and rep targets** → `ProgressionState.swift`
- **Change available training style options** → `TrainingStyle.swift`
