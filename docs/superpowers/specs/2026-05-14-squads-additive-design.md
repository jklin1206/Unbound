# Squads — Additive Design (sub-project #6)

**Status:** Spec.
**Branch:** New `squads-v2` off current `program-redesign` HEAD.
**Reference:** `/Users/jlin/Documents/toji/UNBOUND-squads/` — 46 commits of the original squads-impl with full Supabase backend, RLS, Edge Functions, Realtime polling fallback, 7 model types, 4 services, 11 UI views, 17 phases of work. Most of it is directly salvageable.

---

## Goal

Ship UNBOUND's social layer:
1. **Invite-only crews of 3–8 people** built around real friends/training partners
2. **Linked workouts** as the killer mechanic — squad members training in overlapping time blocks earn shared XP
3. **Squad Missions** — cooperative weekly goals with shared progress bar, badges on completion (NO ranking, NO last place)
4. **Weekly Honors** — rotating recognition categories so different members get spotlighted (identity-based, not competitive)
5. **Friend Challenges** — opt-in, expiring 1-week head-to-head challenges between squad members (small badges/titles/emotes, no permanent rankings)

## Hard philosophy constraints

Per memory `project_unbound_squad_competition_philosophy` (NEW, written today):

- **NO permanent leaderboards.** No ranked ordering of squad members. No "last place."
- **Squad success is ALWAYS the headline** — individual recognition rotates through Weekly Honors.
- **Friend challenges expire** in 1 week. No MMR/ELO/persistent ranks.
- **Identity-based recognition only.** Honors named like "Iron Will" / "Comeback Arc" / "Clutch Performer" — celebratory, not competitive.

Per memory `project_unbound_squads_linked_workouts`:
- Invite-only, 3–8 members
- Killer mechanic = linked workouts (overlapping time blocks)
- Never social-media-feed energy
- Individual still owns their arc; squad amplifies, never competes
- Shared atmosphere systems, not shared mandatory trials

## Hard additive constraint

Session-flow Home modules unchanged. The Squad gets its OWN new tab (#5), so Home doesn't restructure. The contextualStack on Home may surface squad notifications (linked session detected, mission progress, honor received) but the session-flow modules stay intact.

## Out of scope

- Push notifications beyond linked-session — for v1 ship in-app delivery; APNs is follow-up.
- Squad chat / messaging — explicit non-goal (per "no social media energy").
- Public discovery — invite-only via deep-link share, no browse.
- Squad photos beyond initial seed image — keep lightweight.

---

## Architecture overview

### Tab bar

5 tabs: Home / Program / Skills / Profile / **Squad** (new). Squad tab uses `figure.2` SF Symbol.

### Backend

Full Supabase stack (per user decision "deploy backend now, no users right now"):

**5 tables (already specced in `squads-impl` migrations):**
- `squads` (id, name, captain_id, affinity_axis, invite_code, max_size, squad_streak_weeks, created_at)
- `squad_members` (squad_id, user_id, joined_at, captain bool, equipped_title, build_identity_snapshot)
- `squad_presence` (user_id pk, squad_id, workout_started_at, expires_at) — 3h TTL
- `squad_activity` (id, squad_id, user_id NULLABLE for system events, kind, payload jsonb, created_at)
- `linked_sessions` (id, squad_id, user_ids array, started_at, ended_at, created_at)

**3 new tables (Squad Missions + Honors + Friend Challenges):**
- `squad_missions` (id, squad_id, week_iso, mission_kind, target, current_progress, completed_at)
- `squad_weekly_honors` (id, squad_id, week_iso, honor_kind, recipient_user_id, awarded_at)
- `friend_challenges` (id, challenger_id, challenged_id, squad_id, challenge_kind, started_at, expires_at, winner_user_id)

**Edge Functions:**
- `join_squad` — invite code → membership (with capacity + duplicate checks)
- `detect_linked_sessions` — webhook on workout_logs insert → finds overlapping presence → creates linked_session
- `evaluate_squad_streak` — nightly cron, weekly cadence rollup
- `evaluate_squad_mission` — daily cron, checks mission progress vs target
- `assign_weekly_honors` — Sunday-night cron, picks rotating honor recipients

All migrations applied to prod Supabase. All Edge Functions deployed via `supabase functions deploy`. Real backend live in dev.

### Swift architecture

**Models (mostly exist in squads-impl reference branch):**
- `Squad`, `SquadMember`, `SquadPresence`, `SquadActivityEntry`, `SquadActivityKind`, `SquadActivityPayload`, `SquadState`, `SquadTitleID`
- **NEW:** `SquadMission` (id, squadId, weekIso, kind, target, progress, completedAt)
- **NEW:** `WeeklyHonor` (id, squadId, weekIso, kind, recipientUserId, awardedAt) + `WeeklyHonorKind` enum (mostConsistent / ironWill / clutchPerformer / mostImproved / comebackArc / earlyBird / nightGrinder / trialFinisher / supportBuff)
- **NEW:** `FriendChallenge` (id, challengerId, challengedId, squadId, kind, startedAt, expiresAt, winnerUserId) + `FriendChallengeKind` enum (mostSessions / noMissedDays / firstToFinishTrial / mostAlignedSessions / earlyRiser / proteinGoal)

**Services (in `UNBOUND/Services/Squads/`):**
- `SquadService` + protocol + production + mock (createSquad, joinSquad, leaveSquad, setAffinity, loadCurrentSquad, aggregateBuildHexValues, state)
- `SquadActivityService` + protocol — records activity entries, observes Trial completions to auto-record
- `SquadPresenceService` + protocol — markInWorkout / clearPresence + Supabase Realtime subscription (with polling fallback)
- `SquadMissionService` + protocol — generateThisWeek(squadId:), recordProgress(...) (called by WorkoutLogService), checkCompletion()
- `SquadHonorsService` + protocol — assignWeeklyHonors(squadId:weekIso:) callable by cron, records to store, posts notifications
- `FriendChallengeService` + protocol — createChallenge, recordProgress, evaluateOnExpire, listActive(userId:)
- `LinkedSessionEvaluator` — applies +20% XP bonus when linked session detected
- `SquadStore` — local UserDefaults cache of `SquadState`
- `SquadBackend` + `SquadBackendProtocol` + `MockSquadBackend` — thin Supabase wrapper (same pattern as in squads-impl)

**UI (in `UNBOUND/Views/Squads/`):**

Squad tab structure:
- `SquadTabView` — root tab content. Routes to `SquadEmptyView` if no squad, `SquadDetailView` if member.
- `SquadEmptyView` — hero copy "Train with your crew" + Create / Join CTAs
- `CreateSquadSheet` — name input, 30-char limit, calls `SquadService.createSquad`
- `JoinSquadSheet` — invite code input (6-char A-Z0-9), supports `prefilledCode` from universal links
- `SquadDetailView` — the main squad screen (sections below)

SquadDetailView sections (top → bottom):
1. **Header card** — squad name + member count + Invite button (share sheet with deep link)
2. **Squad Mission card** — this week's shared goal with progress bar + reward preview
3. **Aggregate Build hex** — squad's combined build (NOT user's individual hex)
4. **Affinity card** — current axis + tier progress + Captain-only Edit button
5. **Squad streak row** — weekly streak counter
6. **Roster grid** — `SquadMemberCard` per member with live presence chips
7. **Weekly Honors strip** — current week's honors with recipient avatars
8. **Activity feed** — `ActivityFeedRow` for trial completions, linked sessions, member joins, mission progress, honors awarded
9. **Squad Titles row** — earned squad-level titles
10. **Friend Challenges section** — active opt-in challenges between squad members
11. **Footer settings** — Leave squad + captain-only Rename/Edit affinity

Member detail:
- `SquadMemberDetailView` — read-only member profile (BuildIdentity hex, equipped TitleBadge, Ascendant Skills list, recent activity filtered to that member)

Linked session payoff:
- `LinkedSessionToast` — slide-up toast on `.linkedSessionDetected` notification, auto-dismiss 3s. Restrained — not the chain-motif cinematic.

Friend Challenge UI:
- `FriendChallengeCard` — compact card showing active challenge + own progress + opponent progress (NOT ranked — just two parallel bars)
- `FriendChallengeCreateSheet` — captain or member selects an opponent + challenge kind from preset list, 1-week duration
- `FriendChallengeOutcomeToast` — toast when challenge expires showing winner with small badge/emote reward

---

## UI integration

### New tab
`HomeTabView` adds `SquadTabView` as 5th tab. `figure.2` SF Symbol. Tag = 4.

### Home contextualStack
Adds 1-2 new card types (rendered IN the existing slot, never displacing session-flow):
- `LinkedSessionNudgeCard` — appears when a squad member is currently in a workout ("Marcus is training right now — start your session in the next 5 min for a linked bonus")
- `SquadMissionProgressCard` — appears when squad is close to completing mission (75%+ progress) to nudge the final push

These cards do NOT compete with ScanDueCard, ActiveTrialCard, etc. The contextualStack already prioritizes by recency/relevance.

### Universal links
`https://unboundapp.com/squad/<code>` opens the app, switches to Squad tab, presents `JoinSquadSheet` with `prefilledCode`. Same handler as squads-impl.

---

## Squad Mission system (NEW)

### Mission generation

Every Monday, `SquadMissionService.generateThisWeek(squadId:)`:
1. Reads squad size, affinity axis, last week's completion state
2. Picks a mission template from a catalog (~12 templates) weighted by what makes sense for the squad
3. Templates include:
   - "Complete X aligned sessions as a crew" (X = 4 × squad_size)
   - "Finish X capstones together" (X = squad_size — one capstone each)
   - "Hit X focus sessions" (X = 6 × squad_size)
   - "Earn X tier crossings between you" (X = squad_size / 2)
   - "Stack X linked sessions" (X = 3, requires 2+ members)
   - "All X members hit a workout 4+ times this week" (perfect attendance)
4. Inserts row into `squad_missions` table.

### Progress tracking

`WorkoutLogService.saveLog` calls `SquadMissionService.recordProgress(log:userId:)`:
- Looks up active mission for user's squad
- Increments progress based on mission kind (e.g. aligned-sessions mission counts only aligned-axis logs)
- If progress reaches target: marks completed, posts `.squadMissionCompleted` notification

### Completion payoff

All squad members receive:
- Squad-level badge (specific to mission kind)
- Streak continuation
- Visual celebration (slide-up celebration view, NOT chain-motif cinematic — restrained)
- A small attribute boost (+3 to squad's affinity axis, applied per-member)

### UI

`SquadMissionCard` on `SquadDetailView` and `SquadMissionProgressCard` on Home contextualStack. Shows:
- Mission title + subtitle
- Shared progress bar (squad-wide, not per-member)
- Reward preview ("Earn: Squad Sigil — Iron Streak")
- Days remaining

---

## Weekly Honors system (NEW)

### Assignment

Every Sunday at 11pm UTC, `assign_weekly_honors` Edge Function:
1. For each active squad, computes metrics for the past week per member
2. Picks 3 honors (3 different categories) and assigns each to the highest-metric member for that category
3. Constraints:
   - No member can receive 2+ honors in the same week (forces spread)
   - If two members tie, captain picks (or first-joined wins as tiebreaker)
   - If a member already received THIS honor last week, prefer a different recipient (rotation)
4. Inserts rows into `squad_weekly_honors` table

### Honor catalog

9 categories (per user spec):
- **Most Consistent** — most distinct training days
- **Iron Will** — highest avg RPE across all sessions
- **Clutch Performer** — tier crossings during the week
- **Most Improved** — biggest attribute delta vs last week
- **Comeback Arc** — returned after 7+ days inactive, then logged 3+ sessions
- **Early Bird** — most workouts started before 7am
- **Night Grinder** — most workouts started after 9pm
- **Trial Finisher** — completed Trial capstone
- **Support Buff** — linked-session count (the most "we trained together" person)

### UI

`SquadDetailView` Weekly Honors section shows 3 honor cards with recipient avatars. Tapping shows "{Member} earned {Honor} for {short reason}." Tagged "WK 20" or similar week label. NO ranking visible — just three honors and three recipients.

Per-member receipt: `.weeklyHonorReceived` notification fires when the member opens the app on Sunday/Monday — they see a TierBloomToast-style notification with their honor.

---

## Friend Challenge system (NEW)

### Lifecycle

1. **Create:** Any squad member taps "Challenge" button on another member's `SquadMemberCard` or via `FriendChallengeCreateSheet`. Selects challenge kind from a list. Server inserts row in `friend_challenges`.
2. **Live:** Both members see the challenge as a `FriendChallengeCard` on `SquadDetailView`. Two parallel progress bars (own + opponent). NOT a leaderboard — just two side-by-side bars.
3. **Expire:** Edge Function cron (or client-side check) evaluates on `expires_at`. Determines winner by metric. Posts `.friendChallengeExpired` notification.
4. **Payoff:** Winner gets a small cosmetic reward (badge / emote / title flair). Loser sees "{Winner} took this one — rematch?" with NO consolation copy that emphasizes the loss. Just a friendly tone.

### Challenge kinds

Per user spec:
- Most sessions this week (count)
- No missed days (max consecutive days with a session)
- First to finish trial (binary)
- Most aligned sessions (count of sessions hitting trial's aligned axes)
- Wake up before 8am (count)
- Protein goal challenge (requires nutrition tracking — defer if not in scope)

### Constraints

- One active challenge per pair at a time (no spam)
- Both members must opt in (challenger creates → challenged must accept via notification)
- Max 1-week duration
- No persistent rating/ranking across challenges

---

## Acceptance criteria

1. **Session-flow Home modules unchanged.** Snapshot test passes.
2. **5 tabs in tab bar.** Squad tab uses `figure.2` SF Symbol.
3. **Create/join works end-to-end** against deployed Supabase. Invite code → join squad → roster appears on both devices.
4. **Linked sessions detected** by the Edge Function when 2 members train in overlapping windows. `LinkedSessionToast` fires on both clients.
5. **Squad Mission generates on Monday, completes when target reached.** All members receive badge + boost.
6. **Weekly Honors assigned Sunday night.** 3 honors per squad, recipients vary week to week.
7. **Friend Challenge** create → 1-week duration → expire → winner gets reward. Both members see two parallel progress bars (no ranked leaderboard UI).
8. **No leaderboard anywhere.** Grep verifies: zero "leaderboard" / "ranked" / "place_N" UI strings.
9. **All trials-impl-style tests pass.** Plus new tests for Mission, Honor, FriendChallenge services.

---

## Migration order (when shipped)

1. Apply 2 Supabase migrations from squads-impl (`20260513120000_squad_schema.sql`, `20260513130000_squad_activity_nullable_user.sql`) to prod.
2. Apply 3 new migrations (`squad_missions`, `squad_weekly_honors`, `friend_challenges`).
3. Deploy 5 Edge Functions (`join_squad`, `detect_linked_sessions`, `evaluate_squad_streak`, `evaluate_squad_mission`, `assign_weekly_honors`).
4. Configure webhook on `workout_logs` insert → `detect_linked_sessions`.
5. Configure pg_cron schedules: `evaluate_squad_streak` daily, `evaluate_squad_mission` daily, `assign_weekly_honors` Sunday 11pm UTC.
6. Set up AASA file at `https://unboundapp.com/.well-known/apple-app-site-association` for universal links.

---

## Out-of-spec items (defer)

- Squad chat / messaging
- Public squad discovery
- Squad customization (custom name colors, custom sigils beyond catalog)
- Cross-squad alliances
- Tournaments
- Anti-cheat for friend challenges (not needed at this scale)

---

## Related memory
- [[project_unbound_squads_linked_workouts]] — small invite-only crews
- [[project_unbound_squad_competition_philosophy]] — NEW today — two-layer competition design
- [[project_unbound_trials_emphasis_not_workload]] — Squad Mission is the squad-level analogue
- [[feedback_unbound_additive_not_redesign]] — session-flow Home preserved (Squad is new tab, not Home restructure)
- [[feedback_unbound_user_takes_control]] — Friend Challenges opt-in only, never imposed
- [[feedback_unbound_quiet_default_dramatic_moments]] — Mission completion + honor receipt use TierBloomToast-style, not cinematic
