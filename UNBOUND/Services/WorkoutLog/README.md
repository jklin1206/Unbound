# Services/WorkoutLog

Stores and retrieves completed workout logs, autosaves in-progress session drafts, prefills sets from prior sessions, and fires rest-timer notifications. `WorkoutLogService` is the local-file-backed implementation; `SupabaseWorkoutLogService` mirrors writes to the cloud.

| File | Purpose |
|---|---|
| `WorkoutLogServiceProtocol.swift` | Protocol: `updateLog`, `fetchLogs`, `fetchRecentLogs`, `deleteLog`; plus `WorkoutLogCompatibilityHistoryWriting` for side-effect-free history writes. |
| `WorkoutLogService.swift` | Local implementation backed by `DatabaseService`; queries the `workoutLogs` collection. |
| `SupabaseWorkoutLogService.swift` | Supabase-backed implementation; mirrors completed logs to the cloud `workout_logs` table. |
| `MockWorkoutLogService.swift` | In-memory mock for tests. |
| `WorkoutDraftStore.swift` | `@MainActor` autosave of an in-progress workout to `workout-draft.json`; survives app kill and network drop. |
| `TrainingSessionDraftStore.swift` | File-backed persistence for `TrainingSessionDraft`; used to restore a session that was interrupted mid-flow. |
| `SetPrefill.swift` | Pure helper: provides "ghost" weight/reps from the previous matching set for the in-session steppers. |
| `RestPrescription.swift` | Pure helper: derives default rest duration (150 s compound, 90 s isolation) from exercise metadata; honors explicit `Exercise.restSeconds` when sane. |
| `RestNotifier.swift` | Schedules a single local notification for the active rest timer so it fires even if the user leaves the app. |

## Where to find X

| Task | File(s) |
|---|---|
| Fetch or update a completed workout log | `WorkoutLogService.swift`, `WorkoutLogServiceProtocol.swift` |
| Restore an in-progress session after a crash | `WorkoutDraftStore.swift`, `TrainingSessionDraftStore.swift` |
| Ghost/prefill values for set steppers | `SetPrefill.swift` |
| Rest timer notification | `RestNotifier.swift`, `RestPrescription.swift` |
| Mirror logs to Supabase | `SupabaseWorkoutLogService.swift` |
