# Services/Program

Owns the local-first persistence layer for the active training program: the program itself, its per-day schedule occurrences, the user's temporary training-context overrides (today/this-week/next-block), Wave 2 adjustment undo state, and arc/wave scheduling math. All stores write JSON to Application Support and sync changes via the outbox.

| File | Purpose |
|------|---------|
| `ProgramStore.swift` | Local-first owner of the active `TrainingProgram`; writes to a JSON cache file and enqueues program upserts + `users.currentProgramId` patches to `OutboxStore` for cloud sync |
| `ProgramScheduleStore.swift` | Persists `ProgramScheduleOccurrence` records (saved/built/extra/rest sessions per day); provides upsert, replace-primary, and clear operations keyed by userId + date |
| `ProgramTrainingContextStore.swift` | Stores temporary user intent overrides (today-only, this-week, next-block context selections) that the daily resolver reads as modifiers on top of the generated block |
| `WaveAdjustmentStore.swift` | Tracks which Wave 2 adjustment IDs the user has reverted (dismissed) for a given program arc so they are not re-offered |
| `ArcScheduler.swift` | Pure functions for computing the current `ArcContext` (arc day number, wave, days remaining) and deciding when a checkpoint or next-arc rollover is due |
| `MissedSessionMetric.swift` | Evaluates a rolling 7-day missed-session ratio and maps it to a `MissedSessionState` (normal / softCheckIn / rampWeekOffered / staleRecalibrationRecommended) |

## Where to find X

| Task | File |
|------|------|
| Load or save the active training program | `ProgramStore.swift` |
| Read or write scheduled session occurrences for a date | `ProgramScheduleStore.swift` |
| Save a "train differently today/this week" override | `ProgramTrainingContextStore.swift` |
| Check whether an arc checkpoint or rollover is due | `ArcScheduler.swift` |
| Evaluate how many sessions a user has been missing | `MissedSessionMetric.swift` |
