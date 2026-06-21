# Sync

The offline-first sync spine: every local mutation goes through `SyncedDatabase`, which writes the local store first and enqueues an `OutboxEntry`; `SyncEngine` drains the outbox to Supabase on external triggers (foreground, reconnect, post-write debounce) with field-level merge to avoid last-write-wins clobbering.

## Files

| File | Purpose |
| --- | --- |
| `DocumentMerger.swift` | Pure field-level merge: applies only the named top-level fields from source onto base, so two devices editing different fields converge to the union. |
| `OutboxEntry.swift` | One pending change to a single document: upsert/delete op, payload JSON, and the changed-field keys used for merge on flush. |
| `OutboxStore.swift` | Durable FIFO of pending changes (single JSON array, atomic writes), coalesced by (collection, docId); includes a dead-letter queue. |
| `RemoteSync.swift` | `SyncCollectionMap` — the single source of truth for which local collections sync to which tables — plus the `RemoteSync` abstraction / Supabase implementation. |
| `SyncedDatabase.swift` | `DatabaseServiceProtocol` decorator and single choke point: local write first (authoritative), then enqueue to the outbox. |
| `SyncEngine.swift` | Single-flight drainer: flushes the outbox to the remote and restores from it; retry with `maxAttempts`, no timers or polling. |
| `SyncTriggers.swift` | Owns the flush triggers: network reconnect (NWPathMonitor) and post-write debounce; foreground flush is driven by scenePhase at the app entry. |

## Where to find X

- **"Why didn't my edit reach the cloud?"** → `SyncEngine.swift` (drain/retry/dead-letter) and `SyncTriggers.swift` (when flushes fire).
- **Adding a new synced collection** → `RemoteSync.swift` (`SyncCollectionMap` table/column mapping).
- **How concurrent edits from two devices merge** → `DocumentMerger.swift` + the `changedFields` metadata on `OutboxEntry.swift`.
- **The write path services should use** → `SyncedDatabase.swift` (never write Supabase directly for synced collections).
