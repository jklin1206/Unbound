# Views/Squads

All squad social features: the Squads tab, squad detail sections, member cards, co-op missions, 1v1 friend challenges, leaderboard, activity feed, chat, routine drops, logo picker, and creation/join flows.

| File | Purpose |
|------|---------|
| `SquadTabView.swift` | Root squads tab; handles universal-link invite codes and `SquadState` routing |
| `SquadDetailView.swift` | Main squad screen: roster, missions, challenges, leaderboard, and activity feed |
| `SquadDetailView+Actions.swift` | Action handlers (leave, share, logo edit, challenge create) on `SquadDetailView` |
| `SquadDetailView+Components.swift` | Sub-components used inside `SquadDetailView` |
| `SquadDetailView+Sections.swift` | Section builders for the squad detail scroll (presence, mission, leaderboard, etc.) |
| `SquadMissionCard.swift` | Co-op mission card: title, shared progress bar, reward preview |
| `SquadMemberCard.swift` | Roster member card: presence dot, weekly sessions, accountability badge, cosmetic tier |
| `SquadMemberDetailView.swift` | Full per-member detail sheet: profile, attribute hex, recent activity, workout logs |
| `SquadLeaderboardViews.swift` | Leaderboard + `SquadStreakHeroView` showing weekly protection status |
| `WeeklyHonorsStrip.swift` | Horizontal strip of 3 honor cards (Most Sessions, Most Consistent, Breakthrough) |
| `ActivityFeedRow.swift` | Single activity feed entry row with relative timestamp |
| `SquadRoutineDropViews.swift` | `SquadRoutineDropCard` — squad-shared routine drop with save/use-today actions |
| `FriendChallengeCard.swift` | 1v1 challenge card: side-by-side progress bars, days remaining, challenge kind |
| `FriendChallengeCreateSheet.swift` | Sheet for creating a 1v1 challenge: opponent picker, challenge kind selector |
| `FriendChallengeOutcomeToast.swift` | Bottom toast fired on `friendChallengeExpired`; slide-up/hold/fade timeline |
| `SquadChatView.swift` | Real-time squad chat with draft field, message list, and report affordance |
| `SquadLogoViews.swift` | `SquadLogoMarkView` and logo-preset rendering from `SquadLogoCatalog` |
| `SquadEmptyView.swift` | Empty state with Create Squad / Join Squad CTAs |
| `CreateSquadSheet.swift` | Squad creation form: name + logo picker |
| `JoinSquadSheet.swift` | Join-by-code sheet; pre-fills from universal-link invite code |
| `AffinityPickerSheet.swift` | Monthly affinity (attribute focus) picker for the squad |
| `LinkedSessionToast.swift` | Toast shown when a workout is linked with squad members (co-session XP bonus) |

## Where to find X

| Task | File |
|------|------|
| Change the squad roster or presence display | `SquadMemberCard.swift` + `SquadDetailView+Sections.swift` |
| Edit the co-op mission progress card | `SquadMissionCard.swift` |
| Modify the 1v1 challenge flow | `FriendChallengeCard.swift` + `FriendChallengeCreateSheet.swift` |
| Adjust the activity feed row layout | `ActivityFeedRow.swift` |
| Change the squad creation or join form | `CreateSquadSheet.swift` / `JoinSquadSheet.swift` |
| Handle universal-link invite deep linking | `SquadTabView.swift` |
