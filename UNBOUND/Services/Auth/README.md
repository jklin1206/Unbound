# Auth

Authentication (Sign in with Apple via Supabase, plus email/password tunneled through Supabase native auth) and the one-time migrations that move a pre-auth anonymous user's local data onto their Supabase UID.

## Files

| File | Purpose |
| --- | --- |
| `AuthService.swift` | Supabase-backed auth: `signInWithIdToken(.apple, ...)`, UserDefaults-cached `currentUserId` for synchronous reads, session listener, triggers the legacy-UUID migration on first Apple sign-in. |
| `AuthServiceProtocol.swift` | Protocol: `currentUserId`/`isAuthenticated`/`authStatePublisher` + sign-in/out, create, `deleteAccount`. |
| `LocalToSupabaseMigration.swift` | One-time background re-key of all local JSON docs from the anonymous UUID to the Supabase UID, then best-effort cloud upload (local stays source of truth). |
| `MockAuthService.swift` | Canned `"mock-user-123"` auth for tests/previews. |
| `Migration/UserDataMigrationCoordinator.swift` | Coordinates per-collection migration (workout logs, working weights, skill progress, scans) with a `UserDataMigrationSummary`; only a fully clean run sets the completed flag, so half-migrations retry next launch. |
| `Migration/UserDataMigrationStores.swift` | Production local/synced store adapters (`UserDataMigrationLocalStoring`) the coordinator reads/writes through. |

## Where to find X

- **Who am I / am I signed in (synchronously)** → `AuthService.swift` (`currentUserId` cache); contract in `AuthServiceProtocol.swift`.
- **What happens on first Apple sign-in for a legacy local user** → `LocalToSupabaseMigration.swift`, then the per-collection pass in `Migration/UserDataMigrationCoordinator.swift`.
- **Account deletion** → `AuthServiceProtocol.swift` (`deleteAccount`) implemented in `AuthService.swift` (server side is the `delete_account` Edge Function).
- **Faking auth in tests** → `MockAuthService.swift`.
