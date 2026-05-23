# Offline-First Sync: Unified Outbox — Design

**Date:** 2026-05-17
**Status:** Approved (user waived written-spec review gate; proceed to implementation)
**Branch:** program-redesign

## Problem

UNBOUND is a fitness app used in gyms with poor connectivity. The Program
layer (`ProgramStore`) is already local-first and well-built, but the **edit
side-stores that personalize the program are local-only with zero cloud
sync**:

- `ProgressionStateStore`, `ExercisePreferenceService`, `ProgramBlockStore`
  talk directly to the local file `DatabaseService`.
- A coach action (swap exercise → `ExercisePreference`, insert deload →
  `ProgressionState`) is therefore lost on reinstall and never reaches the DB.
- The program syncs; the modifiers that make it personal do not.

Each cloud-backed service also hand-rolls its own try-Supabase / catch /
fall-to-local logic (inconsistently — `SupabaseWorkoutLogService` was patched
ad hoc; the side-stores were missed entirely). There is no shared flush
mechanism, no flush-on-reconnect, and no durable queue.

## Locked Decisions

1. **Device model:** single device + safe restore. No simultaneous
   multi-device editing. No conflict resolution — last-writer-wins by
   `(collection, docId)`.
2. **Identity:** durable account always exists (email/Google/Apple sign-in is
   enforced post-onboarding). No trainable state is created before a durable
   account, so restore always has an account to key on.
3. **Sync layer:** one unified outbox/sync queue. Local write is instant and
   authoritative; the change is enqueued and flushed to Supabase on
   foreground / reconnect / debounced retry. Pull only on sign-in/restore and
   the rollover signal. Never poll on app open.
4. **Rollover:** scan-gated with grace + fallback. Prefer a fresh scan at the
   block boundary; prompt for it; auto-roll with existing data after a 5-day
   grace window so the user is never stuck on a stale block.
5. **Implementation:** Approach A — generic operation-log outbox.

## Architecture

Three planes, single-device, local-authoritative:

- **Read plane** — UI/services always read the local `DatabaseService` (file
  JSON). Never touches network. (Already true today.)
- **Write plane** — every mutation goes through one choke point: write the
  doc to the local `DatabaseService` atomically, then append an
  `OutboxEntry`. No network in the hot path.
- **Sync plane** — `SyncEngine` drains the outbox to Supabase on triggers,
  and performs a one-time full pull on sign-in/restore.

**No-polling guarantee:** reads never hit the network; pulls happen only on
sign-in/restore and the rollover signal. Steady-state app open = zero network
reads.

## Components

| Component | Role |
|---|---|
| `OutboxEntry` | `{ id: UUID, userId, collection, docId, op: .upsert \| .delete, payloadJSON: Data?, enqueuedAt: Date, attempt: Int }`. `payloadJSON` is the encoded doc for upsert, nil for delete. |
| `OutboxStore` | Durable append-only queue persisted to disk via atomic writes; survives crash/relaunch. API: `enqueue(entry)`, `peekBatch(limit)`, `ack(ids)`, `moveToDeadletter(id)`, `pendingCount`. **Coalescing:** `enqueue` replaces any prior un-synced entry for the same `(collection, docId)` (last-writer-wins; keeps the queue bounded). |
| `SyncedDatabase` | Decorator over `DatabaseService` conforming to `DatabaseServiceProtocol`. `create/update/delete` → local write **then** enqueue. Injected wherever stores accept `DatabaseServiceProtocol`. Enqueue lives in the shared write path, so a store cannot be forgotten. |
| `SyncEngine` | `flush()` (drain outbox → Supabase, ack on success, exponential backoff on failure, single-flight), `restore(userId)` (full pull, populate local), trigger wiring (foreground via scenePhase, reconnect via NWPathMonitor, debounced post-enqueue). |
| `RemoteSync` | Thin protocol over `SupabaseDatabase`: `upsert(collection, docId, json)`, `delete(collection, docId)`, `pull(collection, userId) -> [docs]`. The scattered `Supabase*Service` wrappers collapse into this. |
| `RolloverCoordinator` | Scan-gated-with-grace orchestration; wraps existing `BlockRolloverScheduler` / `BlockRolloverService`. |

**`ProgramStore` integration:** keeps its local file and read model, but
`save()` enqueues a `programs` upsert + a `users.currentProgramId` patch
instead of calling `SupabaseProgramService` directly. Its `dirty/syncedAt`
fields retire — the outbox becomes the single definition of "unsynced." One
flush path.

**Supersedes:** the ad-hoc any-error local fallback added to
`SupabaseWorkoutLogService` (2026-05-17) is removed and folded into the
general `SyncedDatabase` path.

## Data Flow

**Edit (coach swaps an exercise, offline at the gym):**
`CoachActionExecutor → ExercisePreferenceService.setPreference →
SyncedDatabase.create` (local ✓, instant, UI updates) `→
OutboxStore.enqueue(upsert exercisePreferences/<id>)`. Later: app foregrounds
on wifi → `SyncEngine.flush` → Supabase upsert → ack → entry removed.

**Workout completion:** identical path — `WorkoutLog` save → `SyncedDatabase`
→ local + enqueue.

**Restore (new phone, signs in):** `SyncEngine.restore(userId)`: for each
synced collection, pull by `userId` from Supabase → write into local
`DatabaseService` → `ProgramStore.loadLocal` repopulates → app runs
local-first. Outbox empty. One-time, sign-in/fresh-install only.

## Scan-Gated Rollover with Grace + Fallback

`RolloverCoordinator`, evaluated on app foreground (cheap, all-local):

1. Compute block boundary from current `ProgramBlock.startedAt` + block
   length (existing `BlockRolloverScheduler`).
2. Before boundary: nothing.
3. At/after boundary, **fresh scan exists** (scan newer than current block
   start): run `performRollover` immediately — on-device, deterministic,
   offline-OK — consuming the scan/analysis.
4. At/after boundary, **no fresh scan:** enter `awaitingRescan`; surface the
   existing rescan CTA; start grace clock = `boundary + 5 days`.
5. **Grace expired, still no scan:** auto-roll using existing data
   (`analysis: nil` — `performRollover` already tolerates this).
6. Rollover outputs (new `TrainingProgram` with new id, new `ProgramBlock`,
   `profile.currentProgramId`) written via `SyncedDatabase`/`ProgramStore` →
   enqueued like any other write. Fully offline-capable; syncs later.
7. **Idempotency:** rollover keyed by target `blockNumber`; before
   generating, check the latest `ProgramBlock.blockNumber` so two foregrounds
   (or a relaunch mid-rollover) cannot double-roll.

## Error Handling

- **Local write fails** (disk): throw to caller, surface UI error, nothing
  enqueued. Rare; same behavior as today.
- **Flush fails** (offline / Supabase down / RLS): entry stays, `attempt++`,
  exponential backoff, retried next trigger. User never sees it — local
  already has the data.
- **Partial flush:** per-entry ack; one failed entry does not block
  independent entries.
- **Poison entry** (permanently rejected — schema mismatch): after N attempts
  move to `deadletter` + `.error` log; the queue never wedges; quiet
  diagnostic, not a user-facing block.
- **Restore partial failure:** per-collection; a failed collection retries;
  the app still runs on whatever local has. Degrade, don't crash.
- **Crash mid-flush:** entries ack'd only after a confirmed Supabase write →
  at-least-once delivery; idempotent upsert-by-docId makes redelivery safe.

## Testing

- **OutboxStore:** enqueue / coalesce by `(collection,docId)` / ack / delete
  op / survives relaunch (temp dir).
- **SyncedDatabase:** every mutation writes local **and** enqueues; read path
  unchanged; delete enqueues a delete op.
- **SyncEngine.flush:** success acks; failure retains + backs off;
  single-flight; deadletter after N.
- **RolloverCoordinator:** boundary math; fresh-scan→immediate;
  no-scan→awaiting+grace; grace-expiry→auto-roll; double-foreground = no
  double-roll. Pure core (`resolveRollover`) stays unit-testable.
- **Restore:** pull populates local; idempotent re-run; per-collection
  failure isolation.
- **Integration smoke:** offline edit → kill app → relaunch → still present +
  outbox has entry → simulate reconnect → flushed.

## Scope

**In:** `workoutLogs`, `programs` (via ProgramStore producer),
`progressionState`, `exercisePreferences`, `programBlocks`, scan checkpoints,
app-written `users` profile fields.

**Out:** real-time / multi-device merge, server-side generation, sync queue
UI, conflict resolution beyond last-writer-wins.
