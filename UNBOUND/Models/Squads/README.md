# Models/Squads

Squad (crew) social-system models: the squad itself, roster membership, live presence, the activity feed, weekly missions/honors, leaderboard seasons + rewards, squad titles, and between-friend challenges.

| File | What it contains |
| --- | --- |
| `FriendChallenge.swift` | `FriendChallenge` — a head-to-head challenge between two squad members (kind, target, window) + `FriendChallengeStats`. |
| `Squad.swift` | `Squad` — the core squad record (name, captain, affinity axis, logo) + helper extension. |
| `SquadActivityEntry.swift` | `SquadActivityEntry` — one activity-feed row (trial completed, title unlocked, linked session, member joined, …) + `SquadActivityPayload`. |
| `SquadLeaderboard.swift` | Season machinery: `SquadSeason`, `SquadStreakSummary`, `SquadBoardRow`, season rewards/winner-title types, `SquadSeasonRewardsBuilder`, `SquadLeaderboardBuilder`. |
| `SquadLogo.swift` | `SquadLogoPreset` (asset + palette) and `SquadLogoCatalog`. |
| `SquadMember.swift` | `SquadMember` — roster row (userId, joinedAt, joined display fields). |
| `SquadMission.swift` | `SquadMission` — weekly co-op mission (kind, target, progress) keyed by ISO week. |
| `SquadPresence.swift` | `SquadPresence` — "in a workout right now" presence record with expiry. |
| `SquadState.swift` | `SquadState` — the client-side aggregate: current squad, roster, presence, recent activity (capped at 50), unlocked squad titles. |
| `SquadTitleID.swift` | `SquadTitleID` — identifier for earned squad titles (pact / streak / collective-axis / affinity-tenure categories). |
| `SquadV1Models.swift` | V1 social leftovers: `SquadBadgeTier`, accountability/crew-streak badge states, `SquadMessage(+Reaction)`, `SquadRoutineDrop`, `OpenChallenge(+Joiner)`, `CoopPairChallenge`, `SavedWorkoutShare`. |
| `WeeklyHonor.swift` | `WeeklyHonor` — per-week recognition awarded to one squad member (kind + recipient). |

Where to find X:

- The top-level squad state the client hydrates → `SquadState.swift`
- Leaderboard seasons, rows, and season rewards → `SquadLeaderboard.swift`
- Weekly missions vs weekly honors → `SquadMission.swift` / `WeeklyHonor.swift`
- 1v1 friend challenges → `FriendChallenge.swift`
- Squad chat messages, routine drops, open/co-op challenges (v1 shapes) → `SquadV1Models.swift`
- Who's working out right now → `SquadPresence.swift`
