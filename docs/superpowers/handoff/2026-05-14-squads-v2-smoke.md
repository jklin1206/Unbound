# Squads v2 — Phase 9-14 Handoff
Date: 2026-05-14
Branch: squads-v2

## What Shipped

### Phase 9: Edge Functions (3 commits)
- `supabase/functions/join_squad` — adopted from squads-impl
- `supabase/functions/detect_linked_sessions` — adopted from squads-impl
- `supabase/functions/evaluate_squad_streak` — adopted from squads-impl
- `supabase/functions/evaluate_squad_mission` — new; daily cron marks completed missions + inserts squad_activity row
- `supabase/functions/assign_weekly_honors` — new; Sunday 11pm UTC rotation; v1 picks first unhonored member per kind

### Phase 10: UI Primitives (4 commits)
- `SquadTitleBadge.swift` + `TitleBadge.swift` (dep) from squads-impl
- `SquadMemberCard`, `LinkedSessionToast`, `ActivityFeedRow`, `AffinityPickerSheet` from squads-impl
- `SquadMissionCard` — mission title, shared progress bar, reward preview
- `WeeklyHonorsStrip` — horizontal 3-card honor strip with icon + recipient + reason
- `FriendChallengeCard` — parallel progress bars (own vs opponent), days remaining; NOT a leaderboard
- `FriendChallengeCreateSheet` — opponent picker + challenge kind picker
- `FriendChallengeOutcomeToast` — `.friendChallengeExpired` listener, slide-up toast

### Phase 11: Sheets (1 commit)
- `SquadEmptyView`, `CreateSquadSheet`, `JoinSquadSheet`, `SquadMemberDetailView` from squads-impl

### Phase 12: SquadDetailView (1 commit)
- 11 sections: Header → Mission → AggregateBuild → Affinity → Streak → Roster → WeeklyHonors → ActivityFeed → SquadTitles → FriendChallenges → Footer
- ServiceContainer wired (replaces SquadService.shared direct calls)
- New @State: `currentMission`, `weeklyHonors`, `activeChallenges`, `showChallengeCreate`
- `.onReceive` handlers for `squadMissionCompleted`, `weeklyHonorReceived`, `friendChallengeExpired`
- `.friendChallengeOutcomeToast()` applied at view root

### Phase 13: Squad Tab + Universal Links (3 commits)
- `SquadTabView` from squads-impl (empty-vs-detail router)
- `HomeTabView` — Squad added as 5th tab with `figure.2` icon, tag 4
- Universal links: `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` parses `/squad/<code>` and posts `.squadInviteCodeReceived`
- `UNBOUND.entitlements` — `com.apple.developer.associated-domains: applinks:unboundapp.com`

### Phase 14: Smoke (this commit)
- Full test suite: 400 tests, 5 pre-existing failures (expected), TEST FAILED = pre-existing failures only
- Session-flow Home test: PASS — UnboundHomeViewSessionFlowTests all pass
- Grep checks: 112 squad refs, zero leaderboard strings (comment-only hit), 7 session-flow terms preserved
- Simulator smoke: app launched, 5-tab bar visible, Squad tab at position 4, Home unchanged

## Screenshot
`/tmp/squads-v2-home.png` — Home tab on launch, Squad tab visible in tab bar

## Backend Deployment Checklist (DO NOT deploy until MVP validation)

- [ ] Deploy 5 Supabase migrations (already in `supabase/migrations/`)
- [ ] Deploy 5 Edge Functions: `join_squad`, `detect_linked_sessions`, `evaluate_squad_streak`, `evaluate_squad_mission`, `assign_weekly_honors`
- [ ] Set cron schedules in Supabase dashboard:
  - `evaluate_squad_mission`: `0 2 * * *` (2 AM UTC daily)
  - `assign_weekly_honors`: `0 23 * * 0` (11 PM UTC Sunday)
- [ ] Deploy AASA to `https://unboundapp.com/.well-known/apple-app-site-association` (see comment in AniBodyApp.swift for format)
- [ ] Replace `TEAMID` in AASA with actual Apple Developer Team ID

## Known Follow-ups / Stubs

1. **All SquadBackend methods are stubbed** — `SquadBackend.shared` returns empty/throws. Real Supabase calls needed for each service.
2. **FriendChallenge per-kind progress logic** — `FriendChallengeService.recordProgress` does nothing. Per-kind metric counting is a follow-up.
3. **assign_weekly_honors v1 rotation** — picks first unhonored member per kind; real metric ranking (log counts, RPE, tier crossings) is a follow-up.
4. **SquadDetailView aggregateBuildCard** — placeholder bar chart. Real AttributeProfile per-member snapshots needed.
5. **SquadMemberDetailView roster-level attribution** — currently renders member data; attributeProfile integration pending.
6. **Universal link AASA deployment** — client-side handler is wired; server side needs marketing-site deploy.
