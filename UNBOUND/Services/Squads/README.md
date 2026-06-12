# Services/Squads

Manages all squad and friend-challenge functionality: creating/joining squads, real-time workout presence, co-op weekly missions, linked-session XP bonuses, squad titles, activity feeds, and 1v1 friend challenges. Squad tables live in Supabase (not the local `DatabaseService`); `SquadBackend` isolates every Supabase call so tests run fully in-memory.

| File | Purpose |
|---|---|
| `SquadServiceProtocol.swift` | Protocol for core squad CRUD: create, join, leave, setAffinity, setLogo, aggregateBuildHex. Also defines `SquadError`. |
| `SquadService.swift` | Production `@MainActor` service owning squad mutation logic; wires store + backend + loopReconciler. |
| `SquadBackendProtocol.swift` | Protocol abstracting all Supabase squad-table calls. |
| `SquadBackend.swift` | Supabase implementation of `SquadBackendProtocol`. |
| `MockSquadBackend.swift` | In-memory mock for tests. |
| `SquadStore.swift` | UserDefaults-backed cache of `SquadState` per userId. |
| `LocalSquadDirectory.swift` | UserDefaults cache storing `Squad` + `[SquadMember]` records; used for offline squad reads. |
| `SquadUserIdentity.swift` | Converts string user IDs to UUID; produces a deterministic debug UUID in DEBUG builds for non-UUID local IDs. |
| `SquadPresenceService.swift` | Reads/writes the `squad_presence` Supabase table to show which members are currently in a workout. |
| `SquadPresenceServiceProtocol.swift` | Protocol for presence read/write. |
| `SquadActivityService.swift` | Records squad-level activity events (completions, title unlocks, joined, linked sessions); listens to NotificationCenter for upstream events. |
| `SquadActivityServiceProtocol.swift` | Protocol for activity recording. |
| `SquadActivityBackend.swift` | Supabase implementation for fetching/writing squad activity rows. |
| `SquadActivityBackendProtocol.swift` | Protocol abstracting squad activity Supabase calls. |
| `MockSquadActivityBackend.swift` | In-memory mock for tests. |
| `SquadLoopReconciler.swift` | Closes two previously-inert squad loops: linked-session +20% XP bonus and squad title counter increments, driven on each squad load. |
| `SquadLoopStore.swift` | UserDefaults persistence for the loop reconciler's dedup set and counters (linked session IDs, streak weeks). |
| `LinkedSessionEvaluator.swift` | Applies the +20% XP bonus when a squad partner's workout overlaps the user's; enforces non-stacking with the affinity +10% bonus. |
| `SquadMissionService.swift` | Generates, reads, and evaluates completion of the weekly co-op squad mission. |
| `SquadMissionCatalog.swift` | Static catalog of weekly mission templates; picks a template deterministically from squad ID + ISO week. |
| `FriendChallengeService.swift` | Creates and evaluates 1v1 Heaviest Lift friend challenges within a squad. |
| `FriendChallengeProgressPolicy.swift` | Pure policy: determines whether a workout log counts as progress toward a friend challenge. |
| `SquadHonorsService.swift` | Records and fetches weekly honor entries for a squad. |
| `SquadTitleService.swift` | Wires `SquadTitleThresholdEvaluator` into persisted state; posts `.squadTitleUnlocked` when new squad titles are crossed. |
| `SquadTitleThresholdEvaluator.swift` | Pure evaluator: computes which squad title thresholds are crossed given current counters. |
| `SquadTitleCatalog.swift` | Maps `SquadTitleID` to display names and unlock criteria. |
| `SquadMessageService.swift` | Actor-backed service for reading/writing squad messages; merges remote + local caches. |
| `SquadMessageBackend.swift` | Supabase implementation for squad message table calls. |

## Where to find X

| Task | File(s) |
|---|---|
| Squad create/join/leave logic | `SquadService.swift`, `SquadBackend.swift` |
| Linked-session +20% XP bonus | `SquadLoopReconciler.swift`, `LinkedSessionEvaluator.swift` |
| Weekly co-op mission generation/completion | `SquadMissionService.swift`, `SquadMissionCatalog.swift` |
| Who is currently working out (presence) | `SquadPresenceService.swift` |
| Squad titles unlock conditions | `SquadTitleThresholdEvaluator.swift`, `SquadTitleCatalog.swift` |
