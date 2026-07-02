# Views/Squads

The SQUAD tab: squad creation/joining, the squad detail surface (crew roster, weekly mission, season board, shared activity), 1v1 friend challenges, shared routine drops, and squad-scoped toasts.
`SquadTabView` is the tab root and also handles the `https://unboundapp.com/squad/<code>` universal-link join path.
Every screen follows the calm-list language: flat rows on the page background, `MetaLine` metadata, `CalmSectionHeader` headers, and a single fill-only raised surface for the active object (the weekly mission, the viewer's own row).

## Files

| File | What it is |
|---|---|
| `SquadTabView.swift` | Tab root; routes empty vs detail, handles universal-link squad codes. |
| `SquadEmptyView.swift` | No-squad state with create/join entry points. |
| `CreateSquadSheet.swift` | Sheet for creating a squad (name + crest picker). |
| `JoinSquadSheet.swift` | Sheet for joining a squad by code. |
| `SquadDetailView.swift` | The main squad screen container: identity header + Crew/Mission/Season underline tabs. |
| `SquadDetailView+Data.swift` | Extension: data loading/refresh; real squads pull cross-member logs via the `squad_member_workout_logs` RPC. |
| `SquadDetailView+Header.swift` | Extension: empty state + crest mark helpers. |
| `SquadCrewTab.swift` | Extension: Crew tab — live-now row, squad streak, roster list, recent activity, shared routines. |
| `SquadChallengesTab.swift` | Extension: Mission tab — weekly co-op mission + 1v1 challenges (pending accept/decline, live duels). |
| `SquadSeasonTab.swift` | Extension: Season tab — season board, weekly honors, season rewards, squad titles. |
| `SquadMemberRow.swift` | One roster member as a calm list row (presence dot, last trained, weekly sessions). |
| `SquadMemberDetailView.swift` | Drill-in profile for a member: stats, build, recent workouts, challenges. |
| `SquadMissionCard.swift` | Current squad mission: mono progress readout, thin bar, top contributors. |
| `SquadMissionCelebrationView.swift` | Full-screen takeover when the weekly squad mission completes; claim grants Arcs via `CurrencyWalletStore` (ledger-deduped by mission sourceId). |
| `SquadMissionPickSheet.swift` | Captain-only sheet listing the 5 co-op mission kinds; tap a kind → `onPick` + dismiss. |
| `SquadLeaderboardViews.swift` | `SquadStreakHeroView`, `SquadBoardView`, `SquadSeasonRewardsView` — streak/leaderboard/season surfaces. |
| `ActivityFeedRow.swift` | One line of squad activity (trained a workout, joined, streak, linked session, title). |
| `FriendChallengeRow.swift` | One 1v1 challenge row: pending invite (accept/decline/withdraw) or live duel with comparative bar. |
| `FriendChallengeCreateSheet.swift` | Sheet to create a 1v1 challenge: pick opponent, challenge kind, and (for Heaviest Lift) the lift. |
| `FriendChallengeOutcomeToast.swift` | Bottom toast fired on `.friendChallengeExpired` (`.friendChallengeOutcomeToast()` modifier). |
| `LinkedSessionToast.swift` | Toast + modifier for linked-session (training together) notices. |
| `AffinityPickerSheet.swift` | Captain-only sheet for the squad's monthly affinity axis (squad options menu). |
| `SquadLogoViews.swift` | Squad logo mark, picker, and edit sheet. |
| `SquadRoutineDropViews.swift` | `SquadRoutineDropRow` — a shared routine as a calm row with Save/Today actions. |

## Where to find X

- **Join via link or code** → `SquadTabView.swift` (universal links) + `JoinSquadSheet.swift`.
- **Workout sharing (what squadmates see after you train)** → activity entries render in `ActivityFeedRow.swift` (posted by `TrainingCompletionService`); per-member stats come through `SquadDetailView+Data.swift`.
- **Friend challenge lifecycle UI** → `FriendChallengeCreateSheet.swift` → `FriendChallengeRow.swift` (accept/decline/withdraw) → `FriendChallengeOutcomeToast.swift`.
- **Leaderboard / season rewards / honors** → `SquadLeaderboardViews.swift` + `SquadSeasonTab.swift`.
- **Shared routines (routine drops)** → `SquadRoutineDropViews.swift`, listed by `SquadCrewTab.swift`; share entry point lives in the Program tab's Saved Workouts list.
- **Member data fetching (RLS-gated RPC)** → view side in `SquadDetailView+Data.swift`; backend lives in Services (not this folder).
