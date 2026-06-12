# Squads v2 — Tabbed Layout, Co-op Missions, Real Rewards

**Date:** 2026-06-11
**Status:** Approved design, pending implementation plan
**Builds on:** 2026-05-24-squads-v1-redesign-design.md

## Problem

1. `SquadDetailView` stacks 8 sections in one scroll (header, streak hero, crew grid, challenges, board, season rewards, routine drops, leave footer). Too vertical; nothing has room to breathe.
2. All challenges are 1v1 (`friend_challenges`). There is no cooperative squad-wide goal, even though the `squad_missions` table, `get_squad_mission_progress` RPC, and `detect_linked_sessions` edge function already exist unused.
3. Winning a challenge grants nothing — no Arcs, no XP, no cosmetics, just a toast and a leaderboard counter. The reward celebration engine (`WorkoutRewardSequenceView`, `RewardCelebrationView`) exists but is never fed squad events.
4. Of 6 1v1 challenge kinds, only 2 work (Most Sessions, Early Riser); the other 4 are dead code shown nowhere.

## Decisions (jlin-approved 2026-06-11)

| Question | Decision |
|---|---|
| Scope | All three in one pass: tabs + co-op missions + rewards |
| Tab layout | 3 tabs under a pinned compact header: CREW / CHALLENGES / SEASON |
| Mission kinds at launch | total_weight, total_sessions, total_reps, crew_coverage, train_together (PR energy moved to the 1v1 side — jlin 2026-06-11) |
| Mission reward | Arcs payout per member + season-track progress (NO rank XP — preserves single-source rank) |
| Mission selection | Captain picks weekly from the 5 kinds; server auto-assigns a rotating kind Monday night if unpicked |
| Celebration | Dedicated full-screen `SquadMissionCelebrationView` for all members |
| 1v1 rewards | Small Arcs payout to the winner |
| 1v1 menu | Delete the 4 dead kinds; ship 5 real kinds: Most Sessions, Early Riser, Most Weight, Most Reps, Heaviest Lift (pick an exercise; score = best single-set weight on it this week, MAX semantics) |
| Live join | "Squadmate is training now — jump in" row on Crew tab (presence-driven) |
| Out of scope | Push notifications, synced/real-time shared workout rooms, squad-exclusive cosmetic art, skill-proof + dawn-patrol + hold-time mission kinds (bench for later seasons) |

## 1. UI Restructure

`SquadDetailView.swift` becomes a thin shell:

- **Pinned compact header** (always visible): squad logo, name, invite button, one meta line (streak · crew X/8 · season). Tagline and header CTAs removed. Leave Squad moves to an ellipsis menu in the header — the destructive footer button is deleted.
- **Segmented control** in the calm-list language: fill-only `activeSurface` raised segment, no bars/underlines.
- **CREW tab** (`SquadCrewTab.swift`): live-join row (when a squadmate's presence shows mid-workout: "<name> is training now — jump in", tap starts a session) → streak hero → member grid with live badges → routine drops.
- **CHALLENGES tab** (`SquadChallengesTab.swift`): mission hero card (kind, progress bar, target, days left, per-member contribution chips; captain sees the weekly mission chooser when none exists; non-captains see "captain is choosing" state) → 1v1 challenge rows → new-challenge entry.
- **SEASON tab** (`SquadSeasonTab.swift`): squad board leaderboard → season rewards track → season-winner banner.

Tab restructure ships first as a pure re-layout (no behavior change) so it can be look-checked on sim before backend work.

## 2. Backend — wake up `squad_missions`

**Mission kinds** (`mission_kind` text values): `total_weight`, `total_sessions`, `total_reps`, `crew_coverage`, `train_together`.

**New table `squad_mission_contributions`:**
`id`, `mission_id` FK, `user_id` FK, `amount` int, `source_log_id` uuid, `created_at`; unique `(mission_id, user_id, source_log_id)` for dedup. Powers per-member breakdowns in the hero card + celebration screen, and the crew-coverage computation. `squad_missions.current_progress` stays the rolled-up number.

**RPCs** (SECURITY DEFINER, gated on `is_squad_member`, per the established cross-user recipe):

- `record_squad_mission_progress(p_mission_id, p_amount, p_source_log_id)` — inserts contribution (dedup on conflict), recomputes `current_progress`; for `crew_coverage`, progress = count of members with sessions ≥ per-member target, computed inside the RPC. Sets `completed_at` when target crossed (idempotent).
- `pick_squad_mission(p_squad_id, p_kind)` — captain-only; creates the `(squad_id, week_iso)` row with target auto-scaled to roster size (scaling table is a plan-time balance checkpoint with jlin).

**Auto-fallback:** scheduled job (pg_cron or scheduled edge function) Monday night creates a rotating-kind mission for any squad without one for the new ISO week.

**Train together:** `detect_linked_sessions` edge function additionally calls mission progress recording when the active mission kind is `train_together`. No client delta.

## 3. Client mission loop

- `SquadMissionService` (fetch current mission + contributions, captain pick, record progress) + `SquadMissionProgressPolicy` mirroring `FriendChallengeProgressPolicy`.
- Hooked into the same post-workout completion point where `FriendChallengeService.recordProgress` runs.
- Deltas per kind: `total_weight` = Σ weight×reps, `total_reps` = Σ reps, `total_sessions` = 1, `crew_coverage` = 1 (server interprets against per-member target), `train_together` = server-side only.

## 4. Rewards + celebration

- **Mission complete →** each member receives an Arcs payout via `CurrencyWalletStore.grant` with `sourceId: "squad_mission:<id>"` (same client-grant + sourceId-dedup pattern sessions use) and the squad's season reward track advances one tick. Arcs amounts: plan-time balance checkpoint.
- **`SquadMissionCelebrationView`** — full-screen takeover: squad crest, mission kind + final stat, per-member contribution bars, animated Arcs counter, claim button. Presented on next app open / squad-tab visit while a completed mission has an unclaimed payout for the current user.
- **1v1 wins** pay a small Arcs grant (`sourceId: "friend_challenge:<id>"`); the outcome toast upgrades to a compact reward card.

## 5. 1v1 menu rework

- Delete `noMissedDays`, `firstToFinishTrial`, `mostAlignedSessions`, `proteinGoal` — model cases, policy branches, and any UI copy, in the same commit (no parked dead code). Tolerant decoding for any historical rows of those kinds (display-only, settle as-is).
- Add `mostWeight`, `mostReps` riding the same delta computations built for missions, plus `heaviestLift`: an exercise-scoped duel — `friend_challenges` gains a nullable `exercise_name` column set at creation, the score is each player's best single-set weight on that exercise during the window (progress uses MAX semantics, not accumulation).
- Final menu: Most Sessions, Early Riser, Most Weight, Most Reps, Heaviest Lift — every visible kind creatable and counting.

## 6. Phasing & verification

1. **UI tabs** — pure restructure; sim screenshot via `--unbound-open-squad`; device-arch build gate.
2. **Backend missions** — migrations + RPCs + cron; deno tests (captain gate, member gate, dedup, coverage math, completion idempotency); deploy gated on jlin's `supabase db push`.
3. **Client mission loop** — unit tests on `SquadMissionProgressPolicy` deltas; live `db query --linked` round-trip test.
4. **Celebration + rewards** — grant dedup tests; sim screenshot of celebration (new launch-arg harness entry).
5. **1v1 rework** — kind deletion + 3 new kinds; policy unit tests; tolerant-decode test.
6. **Live-join row** — presence-driven row + navigation hook; sim screenshot.

Each phase: build green (sim + device-arch), suite green, screenshot where UI changed, commit with explicit-path staging.
