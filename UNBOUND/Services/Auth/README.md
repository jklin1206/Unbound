# Services/Auth

Sign in with Apple (via Supabase `signInWithIdToken`) and email/password authentication. On first successful Apple sign-in, triggers a one-time background migration that re-keys all local JSON documents from the pre-auth anonymous UUID to the Supabase UID and pushes them to the cloud.

| File | Purpose |
|---|---|
| `AuthServiceProtocol.swift` | Protocol: `currentUserId`, `isAuthenticated`, `authStatePublisher`, `signInWithApple`, `signInWithEmail`, `createAccountWithEmail`, `signOut`, `deleteAccount`. |
| `AuthService.swift` | Production implementation: Sign in with Apple → Supabase `signInWithIdToken`; caches the UID in UserDefaults for synchronous access; triggers `LocalToSupabaseMigration` on first sign-in. |
| `MockAuthService.swift` | In-memory stub for tests. |
| `LocalToSupabaseMigration.swift` | Re-keys local JSON documents from the legacy anonymous UUID to the Supabase UID and uploads them; the `users` collection is special-cased to create a new `UserProfile` with the Supabase UID. |
| `Migration/UserDataMigrationCoordinator.swift` | Coordinates the multi-collection migration: orchestrates workout logs, working weights, skill progress, and scans; tracks per-collection success/failure for reliable retry. |
| `Migration/UserDataMigrationStores.swift` | Data-access helpers used by the coordinator to read legacy records and write migrated records per collection. |

## Where to find X

| Task | File(s) |
|---|---|
| Sign-in / sign-out / delete account | `AuthService.swift`, `AuthServiceProtocol.swift` |
| One-time local→Supabase UID migration | `LocalToSupabaseMigration.swift` |
| Migration progress tracking and retry logic | `Migration/UserDataMigrationCoordinator.swift` |
| Current user ID (synchronous read) | `AuthService.shared.currentUserId` in `AuthService.swift` |
