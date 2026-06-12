Data models for the Squads social layer — group identity, roster, real-time presence, weekly missions, leaderboard, and between-friend challenges. Computation and persistence live in `SquadBackend` / `SquadService`; these are pure value types.

| File | Purpose |
|---|---|
| `Squad.swift` | `Squad` — core group record: id, name, captain, affinity axis, invite code, streak weeks, logo |
| `SquadV1Models.swift` | `SquadBadgeTier`, `SquadSeason`, and other v1 supporting types used by leaderboard and badge display |
| `SquadLeaderboard.swift` | `SquadSeason` interval and rank-row types for the weekly/seasonal leaderboard surface |
| `SquadLogo.swift` | `SquadLogoPreset` — preset logo definitions (id, asset name, palette) shown in squad creation |
| `SquadTitleID.swift` | `SquadTitleID` — typed identifier for squad-earned titles (linked sessions, streak, collective axis, affinity tenure) |
| `SquadMission.swift` | `SquadMission` — weekly co-op mission record with kind, target, current progress, and completion timestamp |
| `SquadMember.swift` | `SquadMember` — roster entry with joined-field enrichment (display name, equipped title, build identity) |
| `SquadPresence.swift` | `SquadPresence` — live workout presence record with expiry; `isActive` computed from `expiresAt` |
| `SquadActivityEntry.swift` | `SquadActivityEntry` — feed event (trial completed, title unlocked, member joined, streak extended, etc.) |
| `SquadState.swift` | `SquadState` — aggregate view-model snapshot: squad, roster, presence, recent activity, unlocked titles |
| `FriendChallenge.swift` | `FriendChallenge` — 1v1 exercise-scoped challenge between two squad members with per-side progress |
| `WeeklyHonor.swift` | `WeeklyHonor` — weekly peer honor award (most consistent, iron will, clutch performer, most improved) |

## Where to find X

| Task | File |
|---|---|
| Read the squad's core identity fields (name, affinity, invite code) | `Squad.swift` |
| Build or display the weekly leaderboard | `SquadLeaderboard.swift` + `SquadV1Models.swift` |
| Check whether a member is currently in a workout | `SquadPresence.swift` |
| Show the squad activity feed | `SquadActivityEntry.swift` + `SquadState.swift` |
| Display or unlock a 1v1 challenge between friends | `FriendChallenge.swift` |
| Award or display weekly honors | `WeeklyHonor.swift` |
