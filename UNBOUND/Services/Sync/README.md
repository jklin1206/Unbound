# Services/Sync

Local-first offline sync spine: every mutation writes the local store first, then enqueues an `OutboxEntry`; `SyncEngine` drains the outbox to Supabase. `SyncedDatabase` is the single choke point — all services that need sync use it instead of `DatabaseService` directly. `SyncTriggers` fires flushes on network reconnect and after a short debounce following each write.

| File | Purpose |
|---|---|
| `SyncedDatabase.swift` | `DatabaseServiceProtocol` decorator: forwards reads/writes to the local store, enqueues an outbox upsert or delete after every mutation. |
| `SyncEngine.swift` | Single-flight drain: pops outbox entries and applies them to Supabase via `RemoteSync`; retries up to `maxAttempts`; logs to dead-letter on exhaustion. |
| `SyncTriggers.swift` | Owns flush triggers: NWPathMonitor reconnect event and a 2-second debounce on `.outboxDidEnqueue`. |
| `OutboxStore.swift` | Durable FIFO of pending `OutboxEntry` values; persisted as atomic JSON; coalesces by `(collection, docId)` to keep the queue bounded. |
| `OutboxEntry.swift` | Unit of work: one pending upsert or delete for a single document, carrying the changed field names and encoded payload. |
| `RemoteSync.swift` | Protocol + `SupabaseRemoteSync` implementation; maps local collection names to Supabase table names via `SyncCollectionMap` and calls the `sync_merge_row` RPC. |
| `DocumentMerger.swift` | Pure field-level merge: overlays only the listed changed fields from `source` onto `base`, preventing whole-document LWW clobbers. |

## Where to find X

| Task | File(s) |
|---|---|
| Write a record that syncs to Supabase | Use `SyncedDatabase.shared` instead of `DatabaseService.shared` |
| Add a new collection to the sync mapping | `RemoteSync.swift` (`SyncCollectionMap`) |
| Change retry / dead-letter behaviour | `SyncEngine.swift` |
| Change flush trigger timing | `SyncTriggers.swift` |
| Field-level merge conflict resolution | `DocumentMerger.swift` |
