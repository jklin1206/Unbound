# Squads v1 Redesign — Design Spec

**Date:** 2026-05-24
**Status:** Approved for implementation planning
**Owner:** jlin

## Problem

Squads today feel weak and inconsistent. The detail screen has 11 sections competing for attention (Mission, Aggregate Build hex, Affinity, Streak, Roster, Weekly Honors, Activity feed, Squad Titles, Friend Challenges, Header, Footer) and six different reward systems with no clear headliner. Activity is read-only — users can't react or reply to a crewmate's PR. Friend Challenges exist but feel corporate. There's no spine.

This redesign replaces that surface with a tight-crew product centered on one clear loop: **see what your crew did → react / talk about it → optionally hold each other accountable through challenges.**

## North Star

Squads is **3-6 close friends doing fitness together** — not a guild, not a clan, not a leaderboard. Identity comes from the relationships, not the aesthetic. Mechanics serve the loop: visibility → conversation → accountability.

## Architecture — Two Surfaces

### Squad page (identity / dashboard)

Replaces the 11-section detail view with a 5-slab read-only dashboard:

1. **Header** — crest, squad name, member count, `🔥 N-week streak`, `[💬 Open Chat]` and `[+ Invite]` buttons
2. **Crew Streak badge slot** — visible right below header; shows current tier (none / I / II / III) and progress to next
3. **Crew** — 2-column roster grid, each tile shows avatar, presence dot, this-week session count, equipped title; tap → crewmate profile
4. **Challenges** — list of active challenges (Open and Co-op Pair); `[+ New]` button
5. **Recent** — last 3 milestones with `[See all →]` linking into chat

No Aggregate Build hex, no Affinity card, no Weekly Honors slab, no Squad Titles row. These are cut.

### Chat (the live surface)

Full-screen, pulled up via the `[💬 Open Chat]` button. **One thread per squad** with polymorphic messages — some are user-typed text, some are app-generated milestone cards (workouts, PRs, vow seals, challenge events). All ordered by time. Compose bar at bottom.

Reactions on any message or card (fixed emoji set: 🔥 💪 👏 ❤️ 👀). Replies are just messages in the thread — no separate "comment thread" sub-surface. Block + report flow on long-press of any message (Apple UGC requirement).

### Crewmate profile (lightweight)

Pulled up by tapping any name (chat author, roster, challenge participant). Shows:

- Profile pic, name, equipped title
- Build hex (existing `AttributeProfile`)
- This week's session count
- Last 3 workouts (titles only — tap to expand into read-only detail)
- Accountability badge tier + progress to next
- Currently in: active challenges they're participating in

Explicitly NOT in v1: badges shelf (only the one accountability badge exists), sealed-vows shelf, "with-you" record/joint history.

## Verbs (4)

### 1. Open Challenge

Any crewmate posts a challenge with a title (e.g. "Pushups in 60s"), optional due date, posts it to chat. Other crewmates tap `[Join]`, then later tap `[Submit Score]` and type a number. Live scoreboard updates as scores come in. When the window closes (or all joiners have submitted), the highest score wins. Posts a "challenge result" card to chat.

- **Verification:** honor system. All scores public, reactions/comments enabled on each submission, peer pressure is the moderator. (Witness-confirm feature deferred to v2.)
- **Reward:** +10 XP for joining, +25 XP for winning. No named badge.

### 2. Co-op Pair Challenge

Any crewmate invites one other crewmate to a shared goal: **N sessions in N days** (the only configurable goal type in v1 for this challenge mode). Invitee has 24h to `[Accept]` or `[Decline]`. While active, the challenge card in chat updates with both crewmates' progress bars. If both hit the target → both win XP and a +1 to their Accountability badge counter. If either misses → no XP, no counter increment. Cards have a "Rematch" CTA on miss.

- **Reward:** +50 XP per cleared challenge; +1 toward Accountability badge

### 3. Share Saved Workout

Open a Saved Workout from your library → tap "Share" → pick a crewmate (or "post to crew chat"). Lands as a card in chat. Recipient taps `[Add to my library]` to clone. Cloned workout is independent — no sync with original.

### 4. React + reply

Tap any message or card in chat to add a reaction. Tap the compose bar to add a reply. Reply lands inline at bottom of the thread (no nesting / no threading).

## Auto-post to chat (firehose model)

Every one of these events creates an auto-posted card in the squad chat:

- Workout completed (Sam's Push Day, 48 min)
- PR achieved (Front Lever Negatives +2s)
- Binding Vow sealed
- Challenge created (Open or Co-op Pair)
- Challenge joined (Open only)
- Challenge score submitted (Open only)
- Challenge cleared / missed (Co-op Pair) or result declared (Open)
- Accountability badge tier earned
- Crew Streak badge tier earned

Each card supports reactions + replies. No "share to chat?" gate — every workout posts. (Mute-your-session-pre-post is a possible v2 affordance if firehose feels noisy in practice.)

## Badges (2, both with tiered progress)

### Accountability badge (personal)

- **Trigger:** clearing a challenge (either type counts; Open requires winning, Co-op Pair requires both clearing)
- **Tiers:** I = 1 clear, II = 5 clears, III = 25 clears
- **UI:** small badge icon + tier roman numeral, with a progress bar to the next tier. Shows on user's profile + their roster tile on the squad page

### Crew Streak badge (squad-wide)

- **Trigger:** every member trains ≥1 session in a Mon–Sun week
- **Tiers:** I = 5 consecutive weeks, II = 12 weeks, III = 26 weeks
- **Reset:** if any single crewmate misses a week, the streak resets to 0 (full reset, not pause)
- **New members:** a member who joins mid-week is excluded from that week's streak check; they count starting the following Mon–Sun
- **UI:** badge slot directly below squad header; shows current tier (or "no badge yet"), current consecutive-weeks count, and weeks-to-next-tier
- **Auto-posts** to chat when a tier is reached, and when the streak resets (so the crew knows)

## XP

Simple flat counter, no levels.

- +10 XP per logged workout
- +50 XP per Binding Vow seal
- +10 XP per Open challenge join, +25 XP per Open challenge win
- +50 XP per Co-op Pair challenge clear

Lives on user profile as a single number. Future XP→level progression is out of scope.

## Hard caps

- **6 members per squad** (no premium upsell for v1)
- **1 squad per user**
- **Open challenge:** max 6 joiners (matches squad cap; creator counts as a joiner if they participate)

## Data model (sketch)

New / modified Swift types:

| Type | Action | Notes |
|---|---|---|
| `SquadMessage` | **Create** | Polymorphic: `kind: .text \| .workout \| .pr \| .vowSeal \| .challengeEvent \| .savedWorkoutShare`. Each kind has a payload struct. Replaces `SquadActivityEntry`. |
| `SquadMessageReaction` | **Create** | `id, messageId, userId, emoji, createdAt` |
| `OpenChallenge` | **Create** | `id, squadId, creatorId, title, dueAt?, createdAt, status` + `joiners: [OpenChallengeJoiner]` |
| `OpenChallengeJoiner` | **Create** | `id, challengeId, userId, score?, submittedAt?` |
| `CoopPairChallenge` | **Create** | Replaces `FriendChallenge`. `id, squadId, creatorId, partnerId, targetSessions, windowStart, windowEnd, status, creatorProgress, partnerProgress` |
| `SavedWorkoutShare` | **Create** | `id, savedWorkoutId, sharedById, sharedAt`. Referenced by `SquadMessage.kind = .savedWorkoutShare` |
| `AccountabilityBadgeState` | **Create** | `userId, clearedCount, currentTier` |
| `CrewStreakBadgeState` | **Create** | `squadId, consecutiveWeeks, currentTier, weekIsoLast` |
| `Squad` | **Modify** | Add `crewStreakBadgeState` field reference; remove `affinityAxis` and `affinitySetAt` (cut feature) |
| `SquadMember` | Keep | No changes |
| `SquadPresence` | Keep | Existing live-training presence |
| `SquadActivityEntry` | **Remove** | Replaced by `SquadMessage` |
| `SquadMission` + `SquadMissionService` | **Remove** | Cut entirely; no replacement in v1 |
| `WeeklyHonor` + `SquadHonorsService` | **Remove** | Cut |
| `FriendChallenge` + `FriendChallengeService` | **Migrate** | Replaced by `CoopPairChallenge` |
| `SquadTitleID` + `SquadTitleCatalog` | **Remove** | Cut |

Persistence: Supabase (existing pattern). `SquadMessage` and reactions use Supabase Realtime channel per `squadId` for live updates — same mechanism as existing `SquadPresence`.

## Migration from existing Squads

Users with active squads will see:

1. The 5-slab squad page on next launch (existing squads preserved)
2. Their `SquadActivityEntry` history is **not migrated** to `SquadMessage` (clean slate — chat starts empty when v1 ships)
3. Existing `FriendChallenge` records: cancel any active ones and post a "Friend Challenges have moved to the new Squad chat" system card
4. Existing `SquadMission`, `WeeklyHonor`, `SquadTitle` records: dropped silently (these features no longer exist)
5. Existing `squadStreakWeeks` counter: reused for the new Crew Streak badge — users who already have a streak get an instant Tier I badge if ≥5

Pre-migration notice: post a system card to existing squads 7 days before the v1 ship date saying "Squads is getting an update. Your active mission and honors will reset."

## Explicit YAGNI (not in v1)

- ❌ Crew Quest (squad-wide shared goal — folded `SquadMission` into nothing)
- ❌ Weekly Recap auto-post
- ❌ Passive Linked Session detection (existing concept removed from spec)
- ❌ Named badge catalog ("Locked In," "Outpaced," etc.)
- ❌ Competitive pair challenges (only co-op for pair)
- ❌ Routine head-to-head, Binding Vow co-seal as challenge types
- ❌ Rich profile (with-you record, badges shelf, sealed-vows shelf)
- ❌ Mirror Week, tag in workout notes, nudge to train
- ❌ Aggregate Build hex, Affinity selection
- ❌ Witness-confirm on Open Challenge submissions
- ❌ XP → level progression
- ❌ Squad customization beyond name (no crest editor, no color picker)
- ❌ Multi-squad support
- ❌ Cloud sync of Saved Workouts (Shared workouts are point-in-time copies)
- ❌ Read receipts, typing indicators, edit/delete messages, media uploads in chat

## Engineering estimate

~5 weeks total, broken into 4 implementation phases (suggested split — actual phasing to be decided in the plan):

| Phase | Scope | Estimate |
|---|---|---|
| **P1 — Spine + data migration** | New squad page (5 slabs), `SquadMessage` model + Realtime, drop SquadMission/WeeklyHonor/SquadTitle, migration banner | 1.5 wks |
| **P2 — Chat surface** | Full-screen chat view, compose, reactions, auto-post pipeline for workouts/PRs/vow seals, block+report | 1.5 wks |
| **P3 — Challenges** | Open challenge + Co-op pair challenge models, create flows, lifecycle, score submission, auto-post cards in chat | 1 wk |
| **P4 — Badges + share + profile + polish** | Accountability badge state + UI, Crew Streak badge state + UI, Share Saved Workout flow, lightweight profile view | 1 wk |

Infra: zero new infra. Uses existing Supabase + Realtime + APNs.

## Open questions for the implementation plan

1. **Reaction emoji set** — locked at 5 (🔥 💪 👏 ❤️ 👀) or configurable per user? Default: locked.
2. **Compose char limit** — recommend 280 chars (Twitter-like, prevents wall-of-text). Confirm in plan.
3. **Notifications policy** — recommend push on: new challenge invite, challenge cleared/missed, badge tier earned, replies to your message. NOT on: every auto-posted workout. Confirm in plan.
4. **Cap-at-6 enforcement** — what happens if a squad already has >6 members in existing data? Recommend: grandfather but block new joins.
5. **Open challenge expiry** — if a challenge has a due date and not everyone submits, when is it declared? Recommend: at due date, declare from whoever submitted; if zero submissions, cancel silently.

These don't block writing the plan but should be answered before the first commit.
