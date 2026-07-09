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
| `Migration/UserDataMigrationCoordinator.swift` | Coordinates per-collection migration (workout logs, working weights, skill progress, scans, sessionXP, rank, level, movement/loads/families docs, rewards, achievements) with a `UserDataMigrationSummary`; only a fully clean run sets the completed flag, so half-migrations retry next launch. |
| `Migration/UserDataMigrationStores.swift` | Production local/synced store adapters (`UserDataMigrationLocalStoring`) the coordinator reads/writes through, plus the sessionXP and rank re-key stores. |
| `Migration/UserDataMigrationStores+Progress.swift` | Collection-doc domain re-keys: overall-level XP ledger (max-XP + receipts union) and the local-only `movement_progress`/`progression_states`/`progression_families` docs (model merge / higher-load / higher-tier), each mirrored to the users doc under the new id. |
| `Migration/UserDataMigrationStores+Rewards.swift` | UserDefaults domain re-keys: wallet/shop/cosmetics and titles/vows/badges, both replaying their `*CloudBackup` restore merge with the legacy user's snapshot so sign-in and reinstall share one merge path. |

## Where to find X

- **Who am I / am I signed in (synchronously)** → `AuthService.swift` (`currentUserId` cache); contract in `AuthServiceProtocol.swift`.
- **What happens on first Apple sign-in for a legacy local user** → `LocalToSupabaseMigration.swift`, then the per-collection pass in `Migration/UserDataMigrationCoordinator.swift`.
- **How level / movement tiers / working loads / wallet / titles survive sign-in** → `Migration/UserDataMigrationStores+Progress.swift` (collection docs) and `Migration/UserDataMigrationStores+Rewards.swift` (UserDefaults domains); merge semantics live in each domain's `*CloudBackup` service.
- **Account deletion** → `AuthServiceProtocol.swift` (`deleteAccount`) implemented in `AuthService.swift` (server side is the `delete_account` Edge Function).
- **Faking auth in tests** → `MockAuthService.swift`.
