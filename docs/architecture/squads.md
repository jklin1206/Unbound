# Squads Architecture

Status: active source-of-truth as of 2026-06-02.

## What Squads Owns

Squads is the competitive accountability layer. It owns crew membership, rank comparison, simple friend challenges, and local-only debug squads for development users.

It does not own workout completion. Finished workout logs enter through `TrainingCompletionService`, then squad mission and challenge services consume that canonical event.

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

Friend challenge creation exposes only kinds with honest client progress support: `mostSessions` and `earlyRiser`. The model still decodes the legacy/planned enum cases so old rows do not break, but the app must not create challenges whose rules are placeholders.

The primary squad UI should stay focused on roster rank cards and 1v1 challenges. Do not add chat, reactions, message feeds, weekly heat, honors, or mission strips to that screen unless the product explicitly moves back toward a broader social layer.

## Planned Or Legacy Challenge Kinds

These kinds may appear from older data or backend experiments, but are not creatable in the app until their evidence source exists:

| Kind | Missing evidence |
|---|---|
| `noMissedDays` | full streak recomputation from workout history |
| `firstToFinishTrial` | trial completion events |
| `mostAlignedSessions` | workout axis metadata |
| `proteinGoal` | nutrition tracking |

When one of these becomes real, add the evidence source first, then add the progress policy, then expose it in `FriendChallenge.Kind.creationOptions`.
