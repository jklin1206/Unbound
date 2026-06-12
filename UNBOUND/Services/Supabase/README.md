# Services/Supabase

Thin infrastructure layer: the single `UnboundSupabase.client` singleton (project `xwoemvkzrnnsvtupxctu`) and `SupabaseDatabase`, a typed wrapper for Postgres table operations with RLS enforcement and snake_case encoding. All other services that need direct Supabase table access go through `SupabaseDatabase`; higher-level domain services (WorkoutLog, Squads, etc.) layer on top of it or `SyncedDatabase`.

| File | Purpose |
|---|---|
| `SupabaseClient.swift` | Defines `UnboundSupabase` enum holding the shared `Supabase.Client` instance, plus matched `dbEncoder`/`dbDecoder` with snake_case key strategies and ISO 8601 date handling. |
| `SupabaseDatabase.swift` | Typed wrapper around `UnboundSupabase.client`; provides generic `fetch`, `insert`, `update`, `delete` helpers; short-circuits with `notAuthenticated` when no session is present. |

## Where to find X

| Task | File(s) |
|---|---|
| Access the raw Supabase client | `SupabaseClient.swift` (`UnboundSupabase.client`) |
| Add a new typed Postgres query | `SupabaseDatabase.swift` |
| Change the JSON encoding strategy for DB writes | `SupabaseClient.swift` (`dbEncoder`) |
