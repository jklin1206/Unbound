# Views/Squads

The SQUAD tab: squad creation/joining, the squad detail surface (roster, missions, leaderboards, activity feed, chat), 1v1 friend challenges, and squad-scoped toasts. `SquadTabView` is the tab root and also handles the `https://unboundapp.com/squad/<code>` universal-link join path.

## Files

| File | What it is |
|---|---|
| `SquadTabView.swift` | Tab root; routes empty vs detail, handles universal-link squad codes. |
| `SquadEmptyView.swift` | No-squad state with create/join entry points. |
| `CreateSquadSheet.swift` | Sheet for creating a squad. |
| `JoinSquadSheet.swift` | Sheet for joining a squad by code. |
| `SquadDetailView.swift` | The main squad screen container. |
| `SquadDetailView+Data.swift` | Extension: data loading/refresh for the detail screen. |
| `SquadDetailView+Header.swift` | Extension: header composition. |
| `SquadDetailView+Sections.swift` | Extension: body sections (roster, mission, honors, feed…). |
| `SquadCrewTab.swift` | Extension: Crew tab content — squad streak section, crew roster, routine drops. |
| `SquadChallengesTab.swift` | Extension: Challenges tab content — weekly co-op mission section + friend challenges. |
| `SquadSeasonTab.swift` | Extension: Season tab content — squad leaderboard board + season rewards. |
| `SquadMemberCard.swift` | Roster grid card for one member. |
| `SquadMemberDetailView.swift` | Drill-in detail for a single member. |
| `SquadMissionCard.swift` | Current squad mission: title, shared progress bar, reward preview. |
| `SquadMissionCelebrationView.swift` | Full-screen takeover when the weekly squad mission completes; claim grants Arcs via `CurrencyWalletStore` (ledger-deduped by mission sourceId). |
| `SquadMissionPickSheet.swift` | Captain-only sheet listing the 5 co-op mission kinds; tap a kind → `onPick` + dismiss. |
| `SquadLeaderboardViews.swift` | `SquadStreakHeroView`, `SquadBoardView`, `SquadSeasonRewardsView` — streak/leaderboard/season surfaces. |
| `WeeklyHonorsStrip.swift` | Horizontal strip of 3 weekly honor cards (between roster and feed). |
| `ActivityFeedRow.swift` | One row of the squad activity feed. |
| `SquadChatView.swift` | Squad chat: message bubbles, preview row, `ChallengeDashboardRow`. |
| `FriendChallengeCard.swift` | 1v1 challenge card — side-by-side parallel progress bars (NOT a leaderboard). |
| `FriendChallengeCreateSheet.swift` | Sheet to create a 1v1 challenge: pick opponent from roster + challenge kind. |
| `FriendChallengeOutcomeToast.swift` | Bottom toast fired on `.friendChallengeExpired` (`.friendChallengeOutcomeToast()` modifier). |
| `LinkedSessionToast.swift` | Toast + modifier for linked-session (training together) notices. |
| `AffinityPickerSheet.swift` | Sheet for picking a squad affinity. |
| `SquadLogoViews.swift` | Squad logo mark, picker, and edit sheet. |
| `SquadRoutineDropViews.swift` | Routine-drop card + the squad console visual language (background, accent shapes, panel style). |

## Where to find X

- **Join via link or code** → `SquadTabView.swift` (universal links) + `JoinSquadSheet.swift`.
- **Add/change a section on the squad screen** → `SquadDetailView+Sections.swift`.
- **Friend challenge lifecycle UI** → `FriendChallengeCreateSheet.swift` → `FriendChallengeCard.swift` → `FriendChallengeOutcomeToast.swift`.
- **Leaderboard / season rewards** → `SquadLeaderboardViews.swift`.
- **Squad-console panel styling reused across cards** → `SquadRoutineDropViews.swift` (`SquadPanelStyle`).
- **Member data fetching (RLS-gated RPC)** → view side in `SquadDetailView+Data.swift`; backend lives in Services (not this folder).
