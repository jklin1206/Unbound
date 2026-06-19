# Database

The local-first document store: a file-backed JSON database with a Firestore-like interface. This is the authoritative local layer; cloud mirroring happens above it via `SyncedDatabase` (see `../Sync/`).

## Files

| File | Purpose |
| --- | --- |
| `DatabaseService.swift` | Actor-based file-backed JSON store at `Documents/Database/<collection>/<documentId>.json`; queries filter in-memory. Actor isolation serializes read-modify-write so concurrent updates can't lose writes. |
| `DatabaseServiceProtocol.swift` | The CRUD + query contract (`create`/`read`/`update`/`delete`/`query`) shared by the local store, `SyncedDatabase`, and mocks. |
| `MockDatabaseService.swift` | In-memory dictionary-backed implementation for tests. |

## Where to find X

- **Where local documents live on disk** → `DatabaseService.swift` (layout comment at top).
- **The interface services depend on** → `DatabaseServiceProtocol.swift`.
- **Writes that should also sync to Supabase** → use `SyncedDatabase` in `../Sync/`, not `DatabaseService` directly.
- **Test doubles** → `MockDatabaseService.swift`.
