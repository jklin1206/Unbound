# Auth

Authentication (Sign in with Apple and Google via Supabase `signInWithIdToken`, plus email/password tunneled through Supabase native auth) and the one-time migrations that move a pre-auth anonymous user's local data onto their Supabase UID.

`isCloudLinked` is the distinction the app routes on: every launch auto-provisions an anonymous local UUID so data has a key during onboarding, so "has a `currentUserId`" is NOT the same as "signed in".
Only a real Supabase session flips `isCloudLinked`, which is what gates the forced post-paywall "protect your progress" screen (`App/RootView.swift` + `Views/Auth/`).

## Files

| File | Purpose |
| --- | --- |
| `AuthService.swift` | Supabase-backed auth: `signInWithIdToken(.apple/.google, ...)` (Apple via `ASAuthorizationController`, Google via `GIDSignIn`), UserDefaults-cached `currentUserId` for synchronous reads, `isCloudLinked` for the forced-auth gate, session listener, triggers the legacy-UUID migration on first sign-in (`adoptSupabaseSession`). |
| `AuthServiceProtocol.swift` | Protocol: `currentUserId`/`isAuthenticated`/`isCloudLinked`/`authStatePublisher` + `signInWithApple`/`signInWithGoogle`/email sign-in/out, create, `deleteAccount`. |
| `LocalToSupabaseMigration.swift` | One-time background re-key of all local JSON docs from the anonymous UUID to the Supabase UID, then best-effort cloud upload (local stays source of truth). |
| `MockAuthService.swift` | Canned `"mock-user-123"` auth for tests/previews. |
| `Migration/UserDataMigrationCoordinator.swift` | Coordinates per-collection migration (workout logs, working weights, skill progress, scans) with a `UserDataMigrationSummary`; only a fully clean run sets the completed flag, so half-migrations retry next launch. |
| `Migration/UserDataMigrationStores.swift` | Production local/synced store adapters (`UserDataMigrationLocalStoring`) the coordinator reads/writes through. |

## Where to find X

- **Who am I / am I signed in (synchronously)** → `AuthService.swift` (`currentUserId` cache); contract in `AuthServiceProtocol.swift`.
- **What happens on first Apple sign-in for a legacy local user** → `LocalToSupabaseMigration.swift`, then the per-collection pass in `Migration/UserDataMigrationCoordinator.swift`.
- **Account deletion** → `AuthServiceProtocol.swift` (`deleteAccount`) implemented in `AuthService.swift` (server side is the `delete_account` Edge Function).
- **Faking auth in tests** → `MockAuthService.swift`.
