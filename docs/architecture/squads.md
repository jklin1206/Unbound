# Squads Architecture

Status: active source-of-truth as of 2026-07-02.

## What Squads Owns

Squads is the competitive accountability layer. It owns crew membership, rank comparison, simple friend challenges, workout sharing (activity feed + shared routine drops), and local-only debug squads for development users.

It does not own workout completion. Finished workout logs enter through `TrainingCompletionService`, then squad mission, challenge, and activity services consume that canonical event: `recordSquadProgress` advances the weekly mission and any active duels, and posts one `workoutCompleted` entry to `squad_activity` so squadmates see the session in the Crew tab's RECENT list.

## Row-coding contract (read before touching any squad backend row)

`UnboundSupabase.dbDecoder` uses `.convertFromSnakeCase`: it rewrites the JSON keys before matching, so every Decodable row property MUST be camelCase — a snake_case property throws `keyNotFound` and kills the whole fetch. Encodable-only bodies sent through `functions.invoke` stay snake_case (the Functions client encodes with a plain `JSONEncoder`), and `functions.invoke` responses must pass `decoder: UnboundSupabase.dbDecoder` explicitly. `SquadRowCodingConventionTests` locks both rules.

## Cross-member data

`workout_logs` is owner-only under RLS. Squadmates' training data (board stats, last-trained, member detail) comes from the gated SECURITY DEFINER RPC `squad_member_workout_logs(p_squad_id, p_since, p_per_member_limit)`; the client decodes the rows into `WorkoutLog` and reuses `SquadLeaderboardBuilder` so self and squadmates are scored by one implementation. Leaving a squad goes through `leave_squad_atomic` (captain succession + last-member disband happen server-side; the client cannot do either under RLS).

## Code Ownership

| Area | Owner |
|---|---|
| Membership, roster, invite codes, affinity | `UNBOUND/Services/Squads/SquadService.swift`, `SquadBackend.swift`, `SquadBackendProtocol.swift` |
| Local debug squads | `UNBOUND/Services/Squads/LocalSquadDirectory.swift` |
| Weekly mission model | `UNBOUND/Models/SquadMission.swift` |
| Weekly mission catalog | `UNBOUND/Services/Squads/SquadMissionCatalog.swift` |
| Mission backend progress | Supabase RPCs, triggers, and Edge Functions under `supabase/functions/*squad*` and `supabase/migrations/*squad*` |
| Mission client facade | `UNBOUND/Services/Squads/SquadMissionService.swift` |
| Activity feed persistence | `UNBOUND/Services/Squads/SquadActivityBackend.swift` |
| Activity feed orchestration | `UNBOUND/Services/Squads/SquadActivityService.swift` |
| Legacy chat persistence, not surfaced in the primary squad UI | `UNBOUND/Services/Squads/SquadMessageBackend.swift` |
| Legacy chat local fallback and orchestration | `UNBOUND/Services/Squads/SquadMessageService.swift` |
| Friend challenge model | `UNBOUND/Models/FriendChallenge.swift` |
| Friend challenge service | `UNBOUND/Services/Squads/FriendChallengeService.swift` |
| Friend challenge progress rules | `UNBOUND/Services/Squads/FriendChallengeProgressPolicy.swift` |

## Source Of Truth Rules

Weekly mission template selection must match the backend `simpleHash(squad_id || week_iso)` algorithm. Do not use Swift `Hasher` here; it is intentionally randomized between launches.

Mission progress is backend-authoritative. Client code may request progress recording, but database receipts and server-side qualification prevent duplicate or untrusted increments.

Friend challenges can be declined (challenged user) or withdrawn (challenger) only while pending — RLS permits the DELETE only when `accepted_at` and `winner_user_id` are both null, so an accepted duel runs to settlement.

The squad UI is the calm-list surface: Crew (roster, streak, recent activity, shared routines), Mission (weekly co-op mission + 1v1 challenges), Season (board, honors, rewards). Chat/reactions remain deliberately unsurfaced; `SquadMessageService` persists only the lightweight `savedWorkoutShare` messages that routine drops publish.

## Planned Or Legacy Challenge Kinds

These kinds may appear from older data or backend experiments, but are not creatable in the app until their evidence source exists:

| Kind | Missing evidence |
|---|---|
| `noMissedDays` | full streak recomputation from workout history |
| `firstToFinishTrial` | trial completion events |
| `mostAlignedSessions` | workout axis metadata |
| `proteinGoal` | nutrition tracking |

When one of these becomes real, add the evidence source first, then add the progress policy, then expose it in `FriendChallenge.Kind.creationOptions`.
