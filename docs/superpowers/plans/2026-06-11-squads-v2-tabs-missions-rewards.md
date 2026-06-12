# Squads v2 — Tabs, Co-op Missions, Rewards — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the squad screen into 3 tabs, replace the cosmetic mission-kind catalog with 6 real co-op mission kinds (server-computed progress), wire Arcs + season-track rewards with a full-screen celebration, and rework the 1v1 menu to 5 working kinds.

**Architecture:** The mission pipeline already exists end-to-end (cron `evaluate_squad_mission` generates weekly rows; a `workout_logs` AFTER trigger + receipt ledgers record progress idempotently; client RPC is a belt-and-braces immediate path). We keep that skeleton and make progress **kind-aware inside `increment_squad_mission_progress_for_user`**, computing deltas server-side from the trusted `workout_logs.exercise_entries` jsonb — the client never passes amounts. Mission-kind generation parity must be updated in **three synced places**: `SquadMissionCatalog.swift`, `evaluate_squad_mission/index.ts`, and the SQL fallback in the RPC. Rewards use the existing client-side `CurrencyWalletStore.grant(_:sourceId:)` ledger (already dedup-by-sourceId, returns Bool).

**Tech stack:** SwiftUI (iOS), Supabase (Postgres migrations + Deno edge functions), XcodeGen, XCTest + deno test.

**Spec:** `docs/superpowers/specs/2026-06-11-squads-v2-tabs-missions-rewards-design.md`

---

## Ground rules for every task

- Work in an **isolated worktree** (`EnterWorktree`) — the shared tree carries concurrent edits. Cherry-pick the spec commit `3c04d266` onto the new branch first.
- After creating/deleting any Swift file: `xcodegen generate` (pbxproj is gitignored).
- Build gate: `set -o pipefail && xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5 | grep "BUILD SUCCEEDED"` and, before each phase commit that touches app code, the device-arch gate: `xcodebuild build -scheme UNBOUND -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`.
- Never run two xcodebuilds concurrently. Stage explicit paths only — never `git add -A`.
- UI claims require an on-sim screenshot via the launch-arg harness (`--unbound-open-squad`), read back with the Read tool.
- New L10n keys need real `Localizable.xcstrings` entries, edited as TEXT. (The squad views currently use raw strings — keep raw strings to match.)
- Migrations are committed but **NOT pushed to prod**; jlin runs `supabase db push` + `supabase functions deploy`.

## Balance constants (jlin checkpoint — confirm before Phase B lands)

| Constant | Proposed | Where |
|---|---|---|
| Mission complete payout | **300 Arcs/member** (sessions pay 90–750) | `SquadMissionRewardPolicy.missionArcs` |
| 1v1 win payout | **120 Arcs** | `SquadMissionRewardPolicy.duelWinArcs` |
| total_weight target | **8000 kg × memberCount** / week | catalog ×3 places |
| total_sessions target | **4 × memberCount** | catalog ×3 places |
| total_reps target | **600 × memberCount** | catalog ×3 places |
| crew_coverage | target = memberCount; per-member bar = **3 sessions** | catalog + RPC |
| train_together target | **3 linked sessions** (unchanged) | catalog ×3 places |
| pr_hunt target | **1 × memberCount** PRs | catalog ×3 places |
| pr_hunt definition | **server-side weight-PR**: log contains a non-warmup set whose `weightKg` strictly exceeds the user's max prior logged `weightKg` for the same `exerciseName` | RPC only |

---

# Phase A — Tabbed UI restructure (pure re-layout, no behavior change)

### Task A1: Tab scaffold + compact pinned header in SquadDetailView

**Files:**
- Modify: `UNBOUND/Views/Squads/SquadDetailView.swift`

- [ ] **Step 1: Add the tab enum and selection state**

At the top of `SquadDetailView` (after the existing `@State` block, `SquadDetailView.swift:22`):

```swift
    enum SquadTab: String, CaseIterable {
        case crew = "CREW"
        case challenges = "CHALLENGES"
        case season = "SEASON"
    }
    @State private var selectedTab: SquadTab = .crew
```

- [ ] **Step 2: Replace the body's stacked VStack with header + segment + tab content**

Replace the `if let squad = state.currentSquad { ... }` block inside the ScrollView (`SquadDetailView.swift:39-47`) so the structure becomes: the ScrollView stays, but header + segmented control sit ABOVE it pinned, and only tab content scrolls:

```swift
    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            squadBackdrop

            if let squad = state.currentSquad {
                VStack(spacing: 0) {
                    compactHeader(squad: squad)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    tabPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            switch selectedTab {
                            case .crew: crewTabContent(squad: squad)
                            case .challenges: challengesTabContent
                            case .season: seasonTabContent(squad: squad)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 118)
                    }
                }
            } else {
                emptyStateView
            }
        }
        // …all existing modifiers (.navigationTitle, sheets, .task, .onReceive, .confirmationDialog) stay unchanged
    }
```

- [ ] **Step 3: Write `compactHeader` (replaces `headerCard`)**

Calm-list language: single fill-only surface, no gradient border, no shadow stack, no tagline, no CTA buttons. Leave Squad and invite move here:

```swift
    private func compactHeader(squad: Squad) -> some View {
        HStack(spacing: 12) {
            editableCrestMark(squad: squad, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(squad.name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 10) {
                    metaItem(icon: "person.2.fill", text: "\(state.roster.count)/8")
                    metaItem(icon: "flame.fill", text: "\(squad.squadStreakWeeks)W")
                    metaItem(icon: "trophy.fill", text: currentSeason.title)
                }
            }

            Spacer(minLength: 0)

            if let inviteURL = squad.inviteURL {
                ShareLink(item: inviteURL) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.unbound.surface))
                }
            }

            Menu {
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label("Leave Squad", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.surface))
            }
        }
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
        }
    }
```

- [ ] **Step 4: Write `tabPicker` (fill-only activeSurface — NO bars/underlines per the calm-list rule)**

```swift
    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(SquadTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(selectedTab == tab ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selectedTab == tab ? Color.unbound.surfaceElevated : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
    }
```

- [ ] **Step 5: Define the three tab-content builders from the existing sections (move, don't rewrite)**

```swift
    @ViewBuilder
    private func crewTabContent(squad: Squad) -> some View {
        squadStreakSection(squad: squad)
        crewSection
        routineDropsSection
    }

    @ViewBuilder
    private var challengesTabContent: some View {
        challengesSection
    }

    @ViewBuilder
    private func seasonTabContent(squad: Squad) -> some View {
        squadBoardSection
        seasonRewardsSection(squad: squad)
    }
```

Then DELETE in the same commit: `headerCard(squad:)` (lines 265-393), `footerSection` (lines 667-695), `squadMetaPill` (lines 767-785), and `squadTitlesRow` usage from the header (keep `squadTitlesRow` itself and append it at the end of `seasonTabContent` — titles are a season artifact). The "NEW CHALLENGE" header CTA is gone; the challenges tab already has its own NEW button and START CHALLENGE empty-state CTA.

- [ ] **Step 6: Build + screenshot + commit**

```bash
set -o pipefail && xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5 | grep "BUILD SUCCEEDED"
# screenshot all three tabs via --unbound-open-squad, Read the PNGs
git add UNBOUND/Views/Squads/SquadDetailView.swift
git commit -m "feat(squads): 3-tab layout under pinned compact header"
```

### Task A2: Extract tab files

**Files:**
- Create: `UNBOUND/Views/Squads/SquadCrewTab.swift`
- Create: `UNBOUND/Views/Squads/SquadChallengesTab.swift`
- Create: `UNBOUND/Views/Squads/SquadSeasonTab.swift`
- Modify: `UNBOUND/Views/Squads/SquadDetailView.swift`

- [ ] **Step 1: Move section code into extensions** — to avoid threading 15 @State bindings through child structs, extract as `extension SquadDetailView` files (same pattern as `UnboundHomeView+Briefing.swift`). `SquadCrewTab.swift` holds `crewTabContent`, `squadStreakSection`, `crewSection`, `routineDropsSection`, `emptySlab`, routine-drop helpers. `SquadChallengesTab.swift` holds `challengesTabContent`, `challengesSection`, `challengeMetric`. `SquadSeasonTab.swift` holds `seasonTabContent`, `squadBoardSection`, `seasonRewardsSection`, `earnedSeasonWinnerBanner`, `squadTitlesRow`. Mark the moved members `internal` (default) instead of `private`.
- [ ] **Step 2: `xcodegen generate`, build, full squad-area test pass** (`xcodebuild test -only-testing:UNBOUNDTests/SquadMissionServiceTests -only-testing:UNBOUNDTests/TrainingCompletionSquadProgressTests …` — verify each suite actually ran).
- [ ] **Step 3: Commit** the four files explicitly.

---

# Phase B — Mission kinds v2 (backend)

### Task B1: Migration — kind-aware server-side deltas + new catalog + captain pick

**Files:**
- Create: `supabase/migrations/20260611120000_squad_mission_kinds_v2.sql`

- [ ] **Step 1: Write the migration.** Contents, in order:

**(a) Replace `increment_squad_mission_progress_for_user`** — keep all existing guards (membership, source-log ownership, current-week check, receipts dedup) but: drop the `p_delta must be 1` check (the param becomes a signal only — the function computes the real delta), drop the receipts `delta <= 100` check constraint (`alter table public.squad_mission_progress_receipts drop constraint squad_mission_progress_receipts_delta_check; alter table … add check (delta >= 0);`), and compute:

```sql
  -- after locking v_mission_id, read the mission kind
  select sm.mission_kind into v_kind from public.squad_missions sm where sm.id = v_mission_id;

  v_delta := case v_kind
    when 'total_sessions' then 1
    when 'crew_coverage'  then 1
    when 'total_weight' then (
      select coalesce(floor(sum(
        coalesce((s->>'weightKg')::numeric, 0) * coalesce((s->>'reps')::int, 0)
      ))::int, 0)
      from jsonb_array_elements(v_entries) e,
           jsonb_array_elements(e->'sets') s
      where coalesce((s->>'isWarmup')::boolean, false) = false
    )
    when 'total_reps' then (
      select coalesce(sum(coalesce((s->>'reps')::int, 0)), 0)
      from jsonb_array_elements(v_entries) e,
           jsonb_array_elements(e->'sets') s
      where coalesce((s->>'isWarmup')::boolean, false) = false
    )
    when 'pr_hunt' then (
      -- 1 if any non-warmup set beats the user's max prior weight for that exercise name
      select case when exists (
        select 1
        from jsonb_array_elements(v_entries) e,
             jsonb_array_elements(e->'sets') s
        where coalesce((s->>'isWarmup')::boolean, false) = false
          and coalesce((s->>'weightKg')::numeric, 0) > 0
          and coalesce((s->>'weightKg')::numeric, 0) > coalesce((
            select max(coalesce((ps->>'weightKg')::numeric, 0))
            from public.workout_logs pl,
                 jsonb_array_elements(pl.exercise_entries) pe,
                 jsonb_array_elements(pe->'sets') ps
            where pl.user_id = p_user_id
              and pl.id <> v_source_uuid
              and pl.completed_at is not null
              and pe->>'exerciseName' = e->>'exerciseName'
          ), 0)
      ) then 1 else 0 end
    )
    else 0   -- train_together progresses via linked sessions, not logs; legacy kinds inert
  end;

  if v_delta <= 0 then return; end if;
```

(`v_entries` is loaded in the same source-log validation select: `select wl.exercise_entries into v_entries …`.) Insert the receipt with `v_delta`; on conflict do nothing → return. Then for `crew_coverage`, instead of `current_progress + v_delta`, recompute:

```sql
  if v_kind = 'crew_coverage' then
    update public.squad_missions sm
       set current_progress = (
         select count(*) from (
           select r.user_id
             from public.squad_mission_progress_receipts r
            where r.mission_id = v_mission_id
            group by r.user_id
           having count(*) >= 3
         ) covered
       )
     where sm.id = v_mission_id;
  else
    update public.squad_missions sm
       set current_progress = sm.current_progress + v_delta
     where sm.id = v_mission_id;
  end if;

  -- close immediately (cron remains the backstop) so the celebration fires same-session
  update public.squad_missions sm
     set completed_at = now()
   where sm.id = v_mission_id
     and sm.completed_at is null
     and sm.current_progress >= sm.target;
```

**(b) Replace the deterministic SQL fallback catalog** (the `case v_template_idx` block) with the 6 new kinds — same hash, same index order as the table in "Balance constants": idx 0 `total_weight` (8000×mc), 1 `total_sessions` (4×mc), 2 `total_reps` (600×mc), 3 `crew_coverage` (mc), 4 `train_together` (3), 5 `pr_hunt` (mc).

**(c) `pick_squad_mission` RPC:**

```sql
create or replace function public.pick_squad_mission(
  p_squad_id uuid,
  p_kind text
)
returns setof public.squad_missions
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_week_iso text;
  v_member_count int;
  v_target int;
begin
  if v_uid is null then
    raise exception 'pick_squad_mission: authenticated caller required';
  end if;
  if not exists (select 1 from public.squads s where s.id = p_squad_id and s.captain_id = v_uid) then
    raise exception 'pick_squad_mission: caller is not the captain of squad %', p_squad_id;
  end if;
  if p_kind not in ('total_weight','total_sessions','total_reps','crew_coverage','train_together','pr_hunt') then
    raise exception 'pick_squad_mission: unknown kind %', p_kind;
  end if;

  v_week_iso := to_char(now() at time zone 'UTC', 'IYYY') || '-W' || to_char(now() at time zone 'UTC', 'IW');
  select count(*) into v_member_count from public.squad_members sm where sm.squad_id = p_squad_id;
  if coalesce(v_member_count, 0) < 2 then
    raise exception 'pick_squad_mission: squad needs at least 2 members';
  end if;

  v_target := case p_kind
    when 'total_weight'   then 8000 * v_member_count
    when 'total_sessions' then 4 * v_member_count
    when 'total_reps'     then 600 * v_member_count
    when 'crew_coverage'  then v_member_count
    when 'train_together' then 3
    else v_member_count  -- pr_hunt
  end;

  return query
    insert into public.squad_missions (squad_id, week_iso, mission_kind, target, current_progress)
    values (p_squad_id, v_week_iso, p_kind, v_target, 0)
    on conflict (squad_id, week_iso) do nothing
    returning *;
end;
$$;
revoke all on function public.pick_squad_mission(uuid, text) from public, anon;
grant execute on function public.pick_squad_mission(uuid, text) to authenticated;
```

**(d) Verification `do $$` block** asserting the new function signatures exist and the old delta check is gone (mirror the style at the bottom of `20260601084000_squad_progress_source_ledgers.sql`).

- [ ] **Step 2: Local apply + rollback test** against the linked db per the data-layer rule: `supabase db query --linked` with a transaction that exercises `pick_squad_mission` as non-captain (expect exception) and the delta computation on a synthetic log, then ROLLBACK.
- [ ] **Step 3: Commit** the migration.

### Task B2: Edge function catalog parity + Monday-fallback

**Files:**
- Modify: `supabase/functions/evaluate_squad_mission/index.ts:17-44`

- [ ] **Step 1:** Replace `MISSION_TEMPLATES` and `generateMission` with the 6 new kinds/targets (same order as the SQL `case` and `SquadMissionCatalog.templates` — order IS the hash contract). The cron already runs daily at 2 AM UTC and generates for any squad without a row, so "Monday-night auto-fallback" is already satisfied; no schedule change.
- [ ] **Step 2:** Run existing deno tests: `cd supabase/functions && deno test evaluate_squad_mission/ --allow-env`. Commit.

### Task B3: train_together progress from detect_linked_sessions

**Files:**
- Modify: `supabase/functions/detect_linked_sessions/index.ts`

- [ ] **Step 1:** After inserting a `linked_sessions` row, when the squad's current-week open mission has `mission_kind = 'train_together'`, increment it (service-role direct):

```ts
const { data: mission } = await supabase
  .from("squad_missions")
  .select("id, mission_kind, current_progress, target")
  .eq("squad_id", squadId)
  .eq("week_iso", weekIso)
  .is("completed_at", null)
  .limit(1)
  .maybeSingle()

if (mission?.mission_kind === "train_together") {
  // receipts dedup keyed by the linked-session id (source_log_id is text)
  const { error: receiptErr, count } = await supabase
    .from("squad_mission_progress_receipts")
    .insert({ squad_id: squadId, mission_id: mission.id, source_log_id: `linked:${linkedSessionId}`, user_id: null, delta: 1 })
  if (!receiptErr) {
    const progress = mission.current_progress + 1
    await supabase.from("squad_missions").update({
      current_progress: progress,
      ...(progress >= mission.target ? { completed_at: new Date().toISOString() } : {})
    }).eq("id", mission.id)
  }
}
```

(Adapt names to the function's actual locals when implementing; the receipts unique key `(squad_id, source_log_id)` makes the insert the dedup gate — a duplicate insert errors and skips the update. NOTE: `user_id` is nullable in the receipts table, and `source_log_id` has no FK — the `linked:` prefix namespaces it away from log uuids. The B1 migration's source-log validation lives in `_for_user`, which this path does not call.)
- [ ] **Step 2:** deno tests for the function dir; commit.

### Task B4: Backend tests

**Files:**
- Create/extend test files next to the touched functions (`evaluate_squad_mission/index_test.ts` pattern).

- [ ] Write deno tests covering: template parity table (kind list + targets per member count), and (where the existing test harness mocks supabase) the train_together receipt-dedup branch. SQL-level behavior (delta computation, crew coverage, pr_hunt) is covered by the Step B1 live rollback test script — save it as `supabase/tests/squad_mission_kinds_v2_test.sql` so it's rerunnable. Commit.

---

# Phase C — Client mission model + service

### Task C1: SquadMission.Kind v2 (with legacy mapping)

**Files:**
- Modify: `UNBOUND/Models/SquadMission.swift`
- Test: `UNBOUNDTests/Services/SquadMissionServiceTests.swift`

- [ ] **Step 1: Failing test** — new kinds decode, legacy kinds map, display formatting:

```swift
func testMissionKindV2RawValuesAndLegacyMapping() {
    XCTAssertEqual(SquadMission.Kind(rawValue: "total_weight"), .totalWeight)
    XCTAssertEqual(SquadMission.Kind(rawValue: "pr_hunt"), .prHunt)
    // legacy rows from pre-v2 weeks still decode to a sensible kind
    XCTAssertEqual(SquadMission.Kind(rawValue: "alignedSessions"), .totalSessions)
    XCTAssertEqual(SquadMission.Kind(rawValue: "perfectAttendance"), .crewCoverage)
    XCTAssertEqual(SquadMission.Kind(rawValue: "linkedSessions"), .trainTogether)
    XCTAssertNil(SquadMission.Kind(rawValue: "bogus"))
}

func testMissionProgressDisplay() {
    XCTAssertEqual(SquadMission.Kind.totalWeight.progressText(12500), "12,500 kg")
    XCTAssertEqual(SquadMission.Kind.totalSessions.progressText(7), "7 sessions")
    XCTAssertEqual(SquadMission.Kind.crewCoverage.progressText(3), "3 covered")
}
```

- [ ] **Step 2: Implement** — replace the enum (DELETE the old cases; legacy mapping lives in `init?(rawValue:)`):

```swift
    enum Kind: String, Codable, CaseIterable, Sendable {
        case totalWeight = "total_weight"
        case totalSessions = "total_sessions"
        case totalReps = "total_reps"
        case crewCoverage = "crew_coverage"
        case trainTogether = "train_together"
        case prHunt = "pr_hunt"

        init?(rawValue: String) {
            switch rawValue {
            case "total_weight": self = .totalWeight
            case "total_sessions", "alignedSessions", "focusSessions": self = .totalSessions
            case "total_reps": self = .totalReps
            case "crew_coverage", "perfectAttendance": self = .crewCoverage
            case "train_together", "linkedSessions": self = .trainTogether
            case "pr_hunt", "capstonesTogether", "tierCrossings": self = .prHunt
            default: return nil
            }
        }

        var displayName: String {
            switch self {
            case .totalWeight: return "Iron Mountain"
            case .totalSessions: return "Session Stack"
            case .totalReps: return "Rep Avalanche"
            case .crewCoverage: return "Full Crew"
            case .trainTogether: return "Linked Up"
            case .prHunt: return "PR Hunt"
            }
        }

        var subtitle: String {
            switch self {
            case .totalWeight: return "Move this much combined weight as a crew."
            case .totalSessions: return "Stack combined sessions this week."
            case .totalReps: return "Combined reps, every set counts."
            case .crewCoverage: return "Every member trains 3+ times."
            case .trainTogether: return "Train at the same time as a squadmate."
            case .prHunt: return "Set new personal records together."
            }
        }

        var systemImage: String {
            switch self {
            case .totalWeight: return "scalemass.fill"
            case .totalSessions: return "calendar.badge.checkmark"
            case .totalReps: return "repeat"
            case .crewCoverage: return "person.3.fill"
            case .trainTogether: return "link"
            case .prHunt: return "trophy.fill"
            }
        }

        func progressText(_ value: Int) -> String {
            let formatted = value.formatted(.number)
            switch self {
            case .totalWeight: return "\(formatted) kg"
            case .totalSessions: return value == 1 ? "1 session" : "\(formatted) sessions"
            case .totalReps: return "\(formatted) reps"
            case .crewCoverage: return "\(formatted) covered"
            case .trainTogether: return value == 1 ? "1 linked" : "\(formatted) linked"
            case .prHunt: return value == 1 ? "1 PR" : "\(formatted) PRs"
            }
        }
    }
```

NOTE: a custom `init?(rawValue:)` on a `String` RawRepresentable enum changes Codable decoding too (Codable goes through it) — that's exactly what we want; encoding always writes the new raw values.
- [ ] **Step 3:** Run tests, fix `SquadMissionCatalog.swift` compile errors in the same pass (Task C2 below is its content). Commit together with C2.

### Task C2: SquadMissionCatalog parity

**Files:**
- Modify: `UNBOUND/Services/Squads/SquadMissionCatalog.swift`

- [ ] **Step 1: Failing test** (parity with SQL/edge-fn table):

```swift
func testCatalogTargetsMatchBackendContract() {
    XCTAssertEqual(SquadMissionCatalog.target(for: .totalWeight, memberCount: 4), 32_000)
    XCTAssertEqual(SquadMissionCatalog.target(for: .totalSessions, memberCount: 4), 16)
    XCTAssertEqual(SquadMissionCatalog.target(for: .totalReps, memberCount: 4), 2_400)
    XCTAssertEqual(SquadMissionCatalog.target(for: .crewCoverage, memberCount: 4), 4)
    XCTAssertEqual(SquadMissionCatalog.target(for: .trainTogether, memberCount: 4), 3)
    XCTAssertEqual(SquadMissionCatalog.target(for: .prHunt, memberCount: 4), 4)
}
```

- [ ] **Step 2: Implement** — templates in HASH ORDER (`totalWeight, totalSessions, totalReps, crewCoverage, trainTogether, prHunt`), extract `static func target(for:memberCount:)`, keep `templateIndex` byte-for-byte identical. Update the parity comment to name all three synced sites.
- [ ] **Step 3:** Tests green; commit C1+C2.

### Task C3: Service — contributions fetch + completion detection

**Files:**
- Modify: `UNBOUND/Services/Squads/SquadMissionService.swift`
- Modify: `UNBOUND/Services/Squads/SquadBackend.swift` (+ `SquadBackendProtocol.swift`, `MockSquadBackend.swift`)

- [ ] **Step 1:** Add `MissionContribution` + backend fetch (receipts are member-readable):

```swift
struct MissionContribution: Codable, Equatable, Sendable {
    let userId: UUID?
    let total: Int
}
```

`SquadBackend.fetchMissionContributions(missionId: UUID) async throws -> [MissionContribution]` — select `user_id, delta` from `squad_mission_progress_receipts` filtered by `mission_id`, aggregate client-side by userId summing delta. Add to protocol + mock (empty array).
- [ ] **Step 2:** `currentMission` currently filters `.is("completed_at", value: nil)` — completed missions vanish, which breaks the celebration. Add `latestMission(squadId:)` that drops that filter (same query otherwise) and expose it on the protocol; keep `currentMission` for the active-only callers.
- [ ] **Step 3:** Simplify `recordProgress` comment block (delta is now server-computed; the +1 stays as a signal). No code change to the RPC call.
- [ ] **Step 4:** Captain pick: `SquadBackend.pickSquadMission(squadId: UUID, kind: SquadMission.Kind) async throws -> SquadMission?` calling the `pick_squad_mission` RPC, decoding `[MissionRow]` and `first?.toModel()`. Add `SquadMissionService.pickMission(squadId:kind:)` forwarding it. Mock returns a constructed mission.
- [ ] **Step 5:** Unit tests with the existing service-test doubles; run `SquadMissionServiceTests` (verify suite ran); commit.

---

# Phase D — Challenges tab UI + rewards + celebration

### Task D1: Reward policy

**Files:**
- Create: `UNBOUND/Services/Rewards/SquadRewardPolicy.swift`
- Test: `UNBOUNDTests/Services/SquadRewardPolicyTests.swift`

- [ ] **Step 1: Failing test:**

```swift
import XCTest
@testable import UNBOUND

final class SquadRewardPolicyTests: XCTestCase {
    func testMissionPayoutConstant() {
        XCTAssertEqual(SquadRewardPolicy.missionArcs, 300)
        XCTAssertEqual(SquadRewardPolicy.duelWinArcs, 120)
    }
    func testSourceIds() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        XCTAssertEqual(SquadRewardPolicy.missionSourceId(id), "squad_mission:11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(SquadRewardPolicy.duelSourceId(id), "friend_challenge:11111111-1111-1111-1111-111111111111")
    }
}
```

- [ ] **Step 2: Implement:**

```swift
import Foundation

enum SquadRewardPolicy {
    static let missionArcs = 300
    static let duelWinArcs = 120

    static func missionSourceId(_ missionId: UUID) -> String {
        "squad_mission:\(missionId.uuidString.lowercased())"
    }

    static func duelSourceId(_ challengeId: UUID) -> String {
        "friend_challenge:\(challengeId.uuidString.lowercased())"
    }
}
```

(Match the lowercase/uppercase form to what `UUID.uuidString` produces against the test — adjust test, not behavior.)
- [ ] **Step 3:** Tests green, `xcodegen generate`, commit.

### Task D2: Mission hero card + captain chooser in the Challenges tab

**Files:**
- Modify: `UNBOUND/Views/Squads/SquadMissionCard.swift` (upgrade in place)
- Modify: `UNBOUND/Views/Squads/SquadChallengesTab.swift` (from Task A2)
- Modify: `UNBOUND/Views/Squads/SquadDetailView.swift` (state + load)
- Create: `UNBOUND/Views/Squads/SquadMissionPickSheet.swift`

- [ ] **Step 1:** State + loading in `SquadDetailView`: `@State var currentMissionState: SquadMission?`, `@State var missionContributions: [MissionContribution] = []`, `@State var showMissionPick = false`. In `loadAll`/`refreshState`: `currentMissionState = await services.squadMission.latestMission(squadId:)` then contributions fetch when non-nil. (Add `squadMission` to `ServiceContainer` if not exposed — check `ServiceContainer.swift`; `SquadMissionService.shared` is referenced there already.)
- [ ] **Step 2:** Upgrade `SquadMissionCard`: replace the stale "Crew XP bonus + squad activity badge" reward line with `"\(SquadRewardPolicy.missionArcs) Arcs each on completion"`; use `kind.progressText(currentProgress)` + `progressText(target)`; add a contribution strip (horizontal bars per member, name + `kind.progressText(total)`, sorted desc — pass `[(name: String, total: Int)]` in). Calm-list: single `Color.unbound.surface` fill, no gradient progress (flat accent fill), no glow.
- [ ] **Step 3:** `SquadMissionPickSheet` — list of the 6 kinds (icon, displayName, subtitle, computed target via `SquadMissionCatalog.target(for:memberCount:)`), tap calls `services.squadMission.pickMission`, dismisses, refreshes. Only reachable by the captain.
- [ ] **Step 4:** Challenges tab composition: mission hero at top. If `currentMissionState == nil`: captain sees a "PICK THIS WEEK'S MISSION" row opening the sheet; non-captains see an `emptySlab("Captain hasn't picked this week's mission yet — auto-assigns Monday night.", icon: "flag.2.crossed.fill")`. Below: the existing `challengesSection` unchanged.
- [ ] **Step 5:** `xcodegen generate`, build, screenshot Challenges tab (empty + active states via the demo harness), commit.

### Task D3: Full-screen mission celebration

**Files:**
- Create: `UNBOUND/Views/Squads/SquadMissionCelebrationView.swift`
- Modify: `UNBOUND/Views/Squads/SquadDetailView.swift`

- [ ] **Step 1:** Build the view — full-screen, fired via `.fullScreenCover(item: $celebratedMission)`:

```swift
// UNBOUND/Views/Squads/SquadMissionCelebrationView.swift
//
// Full-screen takeover when the weekly squad mission completes.
// Claim grants Arcs via CurrencyWalletStore (ledger-deduped by mission sourceId).
import SwiftUI

struct SquadMissionCelebrationView: View {
    let mission: SquadMission
    let contributions: [(name: String, total: Int)]
    let onClaim: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false

    private var maxContribution: Int { max(contributions.map(\.total).max() ?? 1, 1) }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                Image("SquadCrest")
                    .resizable().scaledToFit()
                    .frame(width: 96, height: 96)
                    .scaleEffect(revealed ? 1 : 0.7)
                    .opacity(revealed ? 1 : 0)

                VStack(spacing: 8) {
                    Text("MISSION COMPLETE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(Color.unbound.accent)
                    Text(mission.kind.displayName)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(mission.kind.progressText(mission.currentProgress))
                        .font(Font.unbound.monoM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                }
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 12)

                VStack(spacing: 10) {
                    ForEach(contributions.sorted { $0.total > $1.total }, id: \.name) { row in
                        HStack(spacing: 10) {
                            Text(row.name)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .frame(width: 92, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.unbound.surface).frame(height: 6)
                                    Capsule().fill(Color.unbound.accent)
                                        .frame(width: revealed ? geo.size.width * CGFloat(row.total) / CGFloat(maxContribution) : 0, height: 6)
                                }
                            }
                            .frame(height: 6)
                            Text(mission.kind.progressText(row.total))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color.unbound.textTertiary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.horizontal, 28)
                .opacity(revealed ? 1 : 0)

                Spacer()

                Button {
                    onClaim()
                    dismiss()
                } label: {
                    Text("CLAIM \(SquadRewardPolicy.missionArcs) ARCS")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.unbound.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.12)) {
                revealed = true
            }
        }
    }
}
```

- [ ] **Step 2:** Presentation logic in `SquadDetailView`: after mission refresh, if `mission.isCompleted` and `CurrencyWalletStore` ledger does NOT contain `SquadRewardPolicy.missionSourceId(mission.id)` → set `celebratedMission = mission`. Wallet exposes no ledger-query today — add to `CurrencyWalletStore`:

```swift
    func hasGranted(sourceId: String) -> Bool {
        let ledger = Set(defaults.stringArray(forKey: Self.grantLedgerKeyPrefix + userId) ?? [])
        return ledger.contains(sourceId)
    }
```

`onClaim` = `CurrencyWalletStore.shared.bind(userId:)` + `grant(SquadRewardPolicy.missionArcs, sourceId: SquadRewardPolicy.missionSourceId(mission.id))`. Also listen for `.squadMissionCompleted` (already posted by `SquadMissionService.evaluateCompletion`).
- [ ] **Step 3:** Demo-harness hook: add a `--unbound-demo-mission-celebration` launch arg branch (same pattern as the other `-sheets` args in the harness file — find via `grep -rn "unbound-open-squad" UNBOUND/`) that presents the view with seeded data.
- [ ] **Step 4:** `xcodegen generate`, build, screenshot via the new arg, wallet unit test for `hasGranted`, commit.

### Task D4: Season-track tick

**Files:**
- Modify: `UNBOUND/Views/Squads/SquadLeaderboardViews.swift` or wherever `SquadSeasonRewardsBuilder.makeRewards` lives (locate: `grep -rn "SquadSeasonRewardsBuilder" UNBOUND/`)

- [ ] **Step 1:** Read the builder. Add a `missionsCompleted: Int` input and one new progress reward row: "Squad Missions" (e.g. unlocks at 4 completed missions in the season). Source the count via `SquadBackend`: `select count` on `squad_missions` where `squad_id` + `completed_at` within season interval (members can read). Keep the change additive — do not restructure existing reward rows.
- [ ] **Step 2:** Unit test for the builder row; screenshot Season tab; commit.

### Task D5: 1v1 win payout

**Files:**
- Modify: `UNBOUND/Views/Squads/FriendChallengeOutcomeToast.swift`
- Modify: wherever `.friendChallengeExpired` is observed for the toast (the toast file itself — verify with `grep -rn "friendChallengeExpired" UNBOUND/Views/`)

- [ ] **Step 1:** When the settled challenge's `winnerUserId == currentUserId`: `CurrencyWalletStore.shared.grant(SquadRewardPolicy.duelWinArcs, sourceId: SquadRewardPolicy.duelSourceId(challenge.id))` (bind first). The Bool return makes re-settlement re-grants impossible.
- [ ] **Step 2:** Upgrade the toast for the win case: add an Arcs line ("+120 ARCS") under the result text. Keep the toast otherwise as-is.
- [ ] **Step 3:** Unit-test the grant dedup (grant twice with same sourceId → balance +120 once). Commit.

---

# Phase E — 1v1 kinds rework

### Task E1: FriendChallenge.Kind — delete 4 dead, add 3 real

**Files:**
- Modify: `UNBOUND/Models/FriendChallenge.swift`
- Modify: `UNBOUND/Services/Squads/FriendChallengeProgressPolicy.swift`
- Test: existing challenge tests (locate with `grep -rln "FriendChallengeProgressPolicy" UNBOUNDTests/`)

- [ ] **Step 1: Failing tests** — kind set, decode tolerance, policy deltas:

```swift
func testKindMenuIsAllReal() {
    XCTAssertEqual(Set(FriendChallenge.Kind.allCases), [.mostSessions, .earlyRiser, .mostWeight, .mostReps, .mostPRs])
    XCTAssertEqual(Set(FriendChallenge.Kind.creationOptions), Set(FriendChallenge.Kind.allCases))
}
func testLegacyKindRowsDecodeAsNilAndAreDropped() {
    XCTAssertNil(FriendChallenge.Kind(rawValue: "proteinGoal"))   // historical rows drop from lists (never creatable → no real rows exist)
}
```

- [ ] **Step 2: Implement** — new enum:

```swift
    enum Kind: String, Codable, CaseIterable, Sendable {
        case mostSessions
        case earlyRiser
        case mostWeight
        case mostReps
        case mostPRs

        static let creationOptions: [Kind] = Kind.allCases
        var isSupportedForCreation: Bool { true }

        var displayName: String {
            switch self {
            case .mostSessions: return "Most Sessions"
            case .earlyRiser: return "Early Riser (8am)"
            case .mostWeight: return "Most Weight"
            case .mostReps: return "Most Reps"
            case .mostPRs: return "Most PRs"
            }
        }

        var subtitle: String {
            switch self {
            case .mostSessions: return "Most workout sessions this week."
            case .earlyRiser: return "Most workouts before 8 AM."
            case .mostWeight: return "Most combined kg moved this week."
            case .mostReps: return "Most combined reps this week."
            case .mostPRs: return "Most new personal records this week."
            }
        }

        var systemImage: String {
            switch self {
            case .mostSessions: return "calendar.badge.checkmark"
            case .earlyRiser: return "sunrise.fill"
            case .mostWeight: return "scalemass.fill"
            case .mostReps: return "repeat"
            case .mostPRs: return "trophy.fill"
            }
        }

        func progressLabel(for value: Int) -> String {
            switch self {
            case .mostSessions, .earlyRiser:
                return value == 1 ? "1 session" : "\(value.formatted(.number)) sessions"
            case .mostWeight: return "\(value.formatted(.number)) kg"
            case .mostReps: return "\(value.formatted(.number)) reps"
            case .mostPRs: return value == 1 ? "1 PR" : "\(value) PRs"
            }
        }
    }
```

`FriendChallengeProgressPolicy`: delete `unsupportedReason` entirely (and its call site in `FriendChallengeService.recordProgress:253-259`); `progressDelta` returns 1 for ALL kinds when the log qualifies (`earlyRiser` keeps the hour check; the others return 1) — the server computes real deltas (Task E2). Grep repo-wide (incl. UNBOUNDTests) for the deleted case names in BOTH explicit and implicit (`.proteinGoal`) forms before building.
- [ ] **Step 3:** Build + full challenge test suites + commit.

### Task E2: SQL — kind-aware 1v1 deltas

**Files:**
- Append to: `supabase/migrations/20260611120000_squad_mission_kinds_v2.sql` (same migration — single deploy)

- [ ] **Step 1:** Replace `increment_friend_challenge_progress_for_user`'s `v_qualifies` case with delta computation mirroring the mission SQL (same jsonb expressions): `mostSessions` → 1, `earlyRiser` → 1 if `local_start_hour < 8` else 0, `mostWeight` → Σ weight×reps, `mostReps` → Σ reps, `mostPRs` → the pr_hunt EXISTS expression (1/0). Drop the receipts `delta <= 100` check on `friend_challenge_progress_receipts` the same way. Update the trigger function `record_workout_log_social_progress`'s `v_should_increment` case to the new kind names (sessions/earlyRiser pre-filter; weight/reps/PRs always call through — the helper computes 0 deltas as no-ops and `if v_delta <= 0 then return` skips receipt writes).
- [ ] **Step 2:** Extend the rollback test script with a 1v1 mostWeight delta assertion. Commit.

### Task E3: Create-sheet copy check

**Files:**
- Modify (if needed): `UNBOUND/Views/Squads/FriendChallengeCreateSheet.swift`

- [ ] **Step 1:** The sheet builds from `Kind.creationOptions` — verify it renders all 5 with icon/subtitle and no "unsupported" affordances remain (grep the file for `isSupportedForCreation`). Screenshot the sheet; commit if changed.

---

# Phase F — Live-join row

### Task F1: "Training now — jump in" row on Crew tab

**Files:**
- Modify: `UNBOUND/Views/Squads/SquadCrewTab.swift`

- [ ] **Step 1:** At the top of `crewTabContent`, when others are live:

```swift
    @ViewBuilder
    var liveNowRow: some View {
        let others = state.activeRosterPresence.filter { $0.userId != currentUserId }
        if let live = others.first {
            Button {
                NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(displayName(for: live.userId)) is training now")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(others.count > 1 ? "+\(others.count - 1) more live — jump in" : "Jump in and link the session")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
            }
            .buttonStyle(.plain)
        }
    }
```

(Check the presence model's field names against `SquadPresenceService` before using `live.userId`.) Insert `liveNowRow` as the first child of `crewTabContent`.
- [ ] **Step 2:** Build, screenshot with seeded presence (demo harness), commit.

---

# Final gates (after Phase F)

- [ ] Device-arch build: `xcodebuild build -scheme UNBOUND -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED
- [ ] Full suite on sim — compare failure list against origin/main's known reds before attributing
- [ ] deno tests: all function dirs touched
- [ ] 3x launch gauntlet on sim (crash check)
- [ ] Screenshots: Crew/Challenges/Season tabs, mission pick sheet, celebration, outcome toast
- [ ] PR off the worktree branch; jlin deploy steps in PR body: `supabase db push`, `supabase functions deploy evaluate_squad_mission detect_linked_sessions`
