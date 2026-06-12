# Services/Database

File-backed local-first JSON document store. Replaces Firestore with an on-device layout (`Documents/Database/<collection>/<documentId>.json`). All reads and writes are actor-isolated for safe concurrent access. Services that also need cloud sync use `SyncedDatabase` (in `Services/Sync`) as a decorator on top of this layer.

| File | Purpose |
|---|---|
| `DatabaseServiceProtocol.swift` | Protocol: `create`, `read`, `update`, `delete`, `query` (field equality filter with optional ordering and limit). |
| `DatabaseService.swift` | `actor` implementation: serializes all CRUD via actor isolation; queries load all documents in a collection into memory and filter in-process. |
| `MockDatabaseService.swift` | In-memory `[collection: [id: Data]]` implementation for tests; conforms to `DatabaseServiceProtocol`. |

## Where to find X

| Task | File(s) |
|---|---|
| Read or write local documents | `DatabaseService.swift` |
| Write documents that also sync to Supabase | `Services/Sync/SyncedDatabase.swift` |
| Add a new collection or query pattern | `DatabaseServiceProtocol.swift`, `DatabaseService.swift` |
