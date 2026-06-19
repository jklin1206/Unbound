# WorkoutLog

Workout-log persistence (local and outbox-synced), in-progress session drafts/autosave, and small set-logging helpers (rest prescription, rest-timer notification, previous-set ghost values).

## Files

| File | Purpose |
| --- | --- |
| `MockWorkoutLogService.swift` | In-memory `WorkoutLogServiceProtocol` (+ compatibility-history writer) for tests. |
| `RestNotifier.swift` | Schedules the one active rest timer as a local notification so it alerts outside the app; `RestNotifying` protocol for tests. |
| `RestPrescription.swift` | Default rest seconds per set: honors a sane explicit `Exercise.restSeconds`, else compound (150s) vs isolation (90s) by name keywords. |
| `SetPrefill.swift` | The per-set "previous" ghost above the steppers: last session's matching set → last set → working weight → nil. |
| `SupabaseWorkoutLogService.swift` | Cloud-synced log persistence through `SyncedDatabase` + outbox (local write authoritative, SyncEngine drains the cloud upsert). |
| `TrainingSessionDraftStore.swift` | File-backed JSON persistence for `TrainingSessionDraft` (ISO-8601, pretty-printed). |
| `WorkoutDraftStore.swift` | Local autosave of an in-progress `ActiveWorkoutSession` (`workout-draft.json`) — survives app kill; Supabase save still only on COMPLETE. |
| `WorkoutLogService.swift` | Local-only `WorkoutLogServiceProtocol` implementation over `DatabaseService` (collection `"workoutLogs"`). |
| `WorkoutLogServiceProtocol.swift` | Protocols: CRUD (`updateLog`/`fetchLogs`/`fetchRecentLogs`/`deleteLog`) + `WorkoutLogCompatibilityHistoryWriting` (side-effect-free history write for already-completed progression). |

## Where to find X

- **Saving / fetching completed workout logs** → `SupabaseWorkoutLogService.swift` (synced) or `WorkoutLogService.swift` (local-only); contract in `WorkoutLogServiceProtocol.swift`.
- **Mid-workout crash safety / draft restore** → `WorkoutDraftStore.swift` (active session) and `TrainingSessionDraftStore.swift` (session draft).
- **Rest timer behavior** → `RestPrescription.swift` (how long) + `RestNotifier.swift` (the notification).
- **The grey "previous" numbers when logging a set** → `SetPrefill.swift`.
