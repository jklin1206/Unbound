# Supabase

The single Supabase client for the app and the typed Postgres wrapper on top of it. Other services never talk to Supabase directly — they go through `SupabaseDatabase`, `SyncedDatabase`, or a feature backend that wraps `UnboundSupabase.client`.

## Files

| File | Purpose |
| --- | --- |
| `SupabaseClient.swift` | `UnboundSupabase` — module-level singleton client (project `xwoemvkzrnnsvtupxctu`, anon key only; RLS enforces access). Provides the snake_case/ISO-8601 JSON encoder used for all Postgres writes. |
| `SupabaseDatabase.swift` | Typed CRUD wrapper around the client for Postgres tables; every method requires an authenticated user and throws `SupabaseDatabaseError.notAuthenticated` client-side before hitting the network. |

## Where to find X

- **The shared client / encoder config** → `SupabaseClient.swift`.
- **Authenticated table reads/writes from Swift** → `SupabaseDatabase.swift`.
- **Offline-synced collections** → not here; see `../Sync/` (`SyncedDatabase` + outbox).
