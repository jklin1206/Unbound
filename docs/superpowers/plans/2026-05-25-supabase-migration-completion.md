# Supabase Migration Completion

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** Finish the local→Supabase migration started in `LocalToSupabaseMigration.swift`. Pre-Supabase users currently lose their workout logs, working weights, and skill progress on sign-in. This plan ports the three remaining stores to Supabase tables, runs the migration once per user, and verifies idempotency so re-runs are safe.

**Architecture:** Three independent migrators (`WorkoutLogsMigrator`, `WorkingWeightsMigrator`, `SkillProgressMigrator`), each idempotent (UserDefaults flag per user + per migrator). Run sequentially on first authenticated sign-in after the upgrade. Local data stays in place after migration in case Supabase fails — only delete after a successful follow-up sync.

**Tech stack:** Swift, Supabase Postgrest, XCTest.

---

## Scope

In:
- `WorkoutLogsMigrator` — local `workoutLog` files → `workout_log` Supabase table
- `WorkingWeightsMigrator` — local working-weight JSON → `working_weight` table
- `SkillProgressMigrator` — local skill progress JSON → `skill_progress` table
- Migration coordinator that runs all three sequentially
- DDL for the three tables (if not already present)
- Idempotency: skip if already migrated for this user
- Failure handling: log error, don't delete local data, retry on next launch

Out:
- Two-way sync (this is a one-shot port)
- Conflict resolution (no remote data exists pre-migration)
- Migration UI / progress bar (silent background task)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `db/migrations/20260525_user_data_tables.sql` | **Create/Verify** | DDL for `workout_log`, `working_weight`, `skill_progress` if not already present |
| `UNBOUND/Services/Auth/Migration/WorkoutLogsMigrator.swift` | **Create** | Reads local workout logs, batch-inserts to Supabase |
| `UNBOUND/Services/Auth/Migration/WorkingWeightsMigrator.swift` | **Create** | Same shape for working weights |
| `UNBOUND/Services/Auth/Migration/SkillProgressMigrator.swift` | **Create** | Same shape for skill progress |
| `UNBOUND/Services/Auth/LocalToSupabaseMigration.swift` | **Modify** | Becomes the coordinator. Remove the TODO at line 3. Run the three migrators on first sign-in. |
| `UNBOUND/Services/Auth/AuthService.swift` | **Modify** | After successful sign-in, call `localToSupabaseMigration.runIfNeeded(userId:)`. |
| `UNBOUND/UNBOUNDTests/Services/WorkoutLogsMigratorTests.swift` | **Create** | Migrate, verify rows in mock Supabase, re-run is no-op |
| `UNBOUND/UNBOUNDTests/Services/WorkingWeightsMigratorTests.swift` | **Create** | Same |
| `UNBOUND/UNBOUNDTests/Services/SkillProgressMigratorTests.swift` | **Create** | Same |
| `UNBOUND/UNBOUNDTests/Services/MigrationCoordinatorTests.swift` | **Create** | Runs all 3 sequentially; one fails → others still attempt; coordinator records partial success |

---

## Tasks

### Task 1 — DDL for user data tables

**File:** `db/migrations/20260525_user_data_tables.sql`.

```sql
create table if not exists public.workout_log (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_payload jsonb not null,    -- whole logged workout as JSON
  performed_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_workout_log_user_performed
  on public.workout_log (user_id, performed_at desc);

create table if not exists public.working_weight (
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id text not null,
  weight_kg numeric not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

create table if not exists public.skill_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id text not null,
  tier text not null,                -- enum from SkillTier
  progress jsonb,                    -- per-tier progress data
  updated_at timestamptz not null default now(),
  primary key (user_id, skill_id)
);
```

If any of these already exist (check `db/migrations/`), skip the corresponding `create`. If existing schema differs, alter only what's missing (don't break existing rows).

**Acceptance:** Migration runs cleanly against current dev DB.

**Commit:** `db(migration): user data tables`

### Task 2 — `WorkoutLogsMigrator`

**File:** Create `UNBOUND/Services/Auth/Migration/WorkoutLogsMigrator.swift`.

```swift
@MainActor
final class WorkoutLogsMigrator {
    private let localStore: WorkoutLogStore  // existing local store; locate via grep
    private let backend: SupabaseClient      // existing Supabase client

    func runIfNeeded(userId: UUID) async throws {
        let key = "migration.workoutLogs.\(userId.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let local = localStore.all()
        guard !local.isEmpty else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        let rows = local.map { log in
            [
                "id": log.id.uuidString,
                "user_id": userId.uuidString,
                "workout_payload": try! JSONEncoder.snakeCase.encode(log),  // pseudocode
                "performed_at": log.performedAt.iso8601String,
            ] as [String: Any]
        }

        try await backend.from("workout_log").insert(rows).execute()
        UserDefaults.standard.set(true, forKey: key)
    }
}
```

Adjust the JSON encoding to match the schema. Use chunked inserts (200 rows per batch) if local data is large.

**Acceptance:** `WorkoutLogsMigratorTests` — local store has 5 logs → migrate → mock Supabase contains 5 rows → re-run is a no-op (idempotent flag set).

**Commit:** `feat(migration): WorkoutLogsMigrator`

### Task 3 — `WorkingWeightsMigrator`

**File:** Create `UNBOUND/Services/Auth/Migration/WorkingWeightsMigrator.swift`.

Same pattern as Task 2. Upsert by `(user_id, exercise_id)` composite key so re-runs are safe even without the UserDefaults flag.

**Acceptance:** Migrator test green.

**Commit:** `feat(migration): WorkingWeightsMigrator`

### Task 4 — `SkillProgressMigrator`

**File:** Create `UNBOUND/Services/Auth/Migration/SkillProgressMigrator.swift`.

Same pattern. Upsert by `(user_id, skill_id)`.

**Acceptance:** Migrator test green.

**Commit:** `feat(migration): SkillProgressMigrator`

### Task 5 — Migration coordinator

**File:** Modify `UNBOUND/Services/Auth/LocalToSupabaseMigration.swift`.

Remove the line-3 TODO. New shape:

```swift
@MainActor
final class LocalToSupabaseMigration {
    private let workoutLogs: WorkoutLogsMigrator
    private let workingWeights: WorkingWeightsMigrator
    private let skillProgress: SkillProgressMigrator
    private let logger = LoggingService.shared

    func runIfNeeded(userId: UUID) async {
        // Run all three; collect errors so one failure doesn't block the others.
        await runSafe("workoutLogs") { try await workoutLogs.runIfNeeded(userId: userId) }
        await runSafe("workingWeights") { try await workingWeights.runIfNeeded(userId: userId) }
        await runSafe("skillProgress") { try await skillProgress.runIfNeeded(userId: userId) }
    }

    private func runSafe(_ label: String, _ block: () async throws -> Void) async {
        do { try await block() }
        catch { logger.log("Migration.\(label) failed: \(error)", level: .error) }
    }
}
```

**Acceptance:** `MigrationCoordinatorTests` — three migrators succeed → coordinator green. One throws → others still run + complete. Logs capture failure.

**Commit:** `feat(migration): coordinator runs all 3 sequentially with isolated failures`

### Task 6 — Wire into `AuthService`

**File:** Modify `AuthService.swift`.

After successful sign-in (existing success path):

```swift
Task { await services.localToSupabaseMigration.runIfNeeded(userId: user.id) }
```

Fire-and-forget — migration runs in background, app proceeds. If anything fails, it'll retry on next sign-in.

**Acceptance:** Sign in as a user with local data → next Supabase query shows their data has been ported. Sign in again → no duplicate inserts.

**Commit:** `feat(auth): trigger migration on sign-in`

---

## Verification

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/WorkoutLogsMigratorTests \
  -only-testing:UNBOUNDTests/Services/WorkingWeightsMigratorTests \
  -only-testing:UNBOUNDTests/Services/SkillProgressMigratorTests \
  -only-testing:UNBOUNDTests/Services/MigrationCoordinatorTests
```

Manual sanity:
1. Seed local DB with mock workout logs / weights / skill progress on a fresh device.
2. Sign in → query Supabase tables → data appears.
3. Sign out + sign in → no duplicate rows.
