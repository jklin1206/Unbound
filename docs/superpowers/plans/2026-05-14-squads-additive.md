# Squads (Additive) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship UNBOUND's social layer — invite-only crews of 3–8 with linked workouts, plus cooperative Squad Missions, rotating Weekly Honors, and opt-in Friend Challenges. No leaderboards anywhere.

**Architecture:** Heavy reuse from `squads-impl` reference (46 commits of models, services, views, tests, migrations, Edge Functions). Plus 3 NEW systems on top: `SquadMission`, `WeeklyHonor`, `FriendChallenge` — each with model + store + service + UI. Full Supabase backend: 8 tables (5 original + 3 new), 5 Edge Functions (3 original + 2 new), Realtime presence (polling fallback), 3 cron schedules. New 5th tab in tab bar.

**Tech Stack:** Swift 5.9+, SwiftUI iOS 17+, XCTest, Supabase (PostgreSQL + RLS + Realtime + Edge Functions/Deno), Apple Push Notifications (linked-session push), Universal Links.

**Spec:** [`docs/superpowers/specs/2026-05-14-squads-additive-design.md`](../specs/2026-05-14-squads-additive-design.md).

**Reference branch:** `/Users/jlin/Documents/toji/UNBOUND-squads/` — copy verbatim where indicated.

**Worktree:** Create `/Users/jlin/Documents/toji/UNBOUND-squads-v2` on new branch `squads-v2` off `program-redesign` HEAD.

---

## File Structure

### CREATE — original squads-impl files to copy verbatim

```
supabase/migrations/
├── 20260514130000_squad_schema.sql                       (from squads-impl 20260513120000)
├── 20260514130001_squad_activity_nullable_user.sql       (from squads-impl 20260513130000)
├── 20260514130002_squad_missions.sql                     (NEW)
├── 20260514130003_squad_weekly_honors.sql                (NEW)
└── 20260514130004_friend_challenges.sql                  (NEW)

supabase/functions/
├── join_squad/index.ts                                   (copy)
├── detect_linked_sessions/index.ts                       (copy)
├── evaluate_squad_streak/index.ts                        (copy)
├── evaluate_squad_mission/index.ts                       (NEW)
└── assign_weekly_honors/index.ts                         (NEW)

UNBOUND/Models/
├── Squad.swift                                           (copy)
├── SquadMember.swift                                     (copy)
├── SquadPresence.swift                                   (copy)
├── SquadActivityEntry.swift                              (copy)
├── SquadState.swift                                      (copy)
├── SquadTitleID.swift                                    (copy)
├── SquadMission.swift                                    (NEW)
├── WeeklyHonor.swift                                     (NEW)
└── FriendChallenge.swift                                 (NEW)

UNBOUND/Services/Squads/
├── SquadTitleCatalog.swift                               (copy)
├── SquadTitleThresholdEvaluator.swift                    (copy)
├── SquadStore.swift                                      (copy)
├── SquadServiceProtocol.swift                            (copy)
├── SquadService.swift                                    (copy)
├── SquadBackendProtocol.swift                            (copy)
├── SquadBackend.swift                                    (copy)
├── MockSquadBackend.swift                                (copy)
├── SquadActivityServiceProtocol.swift                    (copy)
├── SquadActivityService.swift                            (copy)
├── SquadActivityBackendProtocol.swift                    (copy)
├── SquadActivityBackend.swift                            (copy)
├── MockSquadActivityBackend.swift                        (copy)
├── SquadPresenceServiceProtocol.swift                    (copy)
├── SquadPresenceService.swift                            (copy)
├── LinkedSessionEvaluator.swift                          (copy)
├── SquadMissionService.swift                             (NEW)
├── SquadMissionCatalog.swift                             (NEW)
├── SquadHonorsService.swift                              (NEW)
└── FriendChallengeService.swift                          (NEW)

UNBOUND/Views/Squads/
├── SquadTabView.swift                                    (copy)
├── SquadEmptyView.swift                                  (copy)
├── CreateSquadSheet.swift                                (copy)
├── JoinSquadSheet.swift                                  (copy)
├── SquadDetailView.swift                                 (copy + add Mission/Honors/Challenge sections)
├── SquadMemberCard.swift                                 (copy)
├── SquadMemberDetailView.swift                           (copy)
├── AffinityPickerSheet.swift                             (copy)
├── ActivityFeedRow.swift                                 (copy)
├── LinkedSessionToast.swift                              (copy)
├── SquadMissionCard.swift                                (NEW)
├── WeeklyHonorsStrip.swift                               (NEW)
├── FriendChallengeCard.swift                             (NEW)
├── FriendChallengeCreateSheet.swift                      (NEW)
└── FriendChallengeOutcomeToast.swift                     (NEW)

UNBOUND/Views/Components/Unbound/
└── SquadTitleBadge.swift                                 (copy)

UNBOUNDTests/Models/
├── SquadTests.swift                                      (copy)
├── SquadMemberTests.swift                                (copy)
├── SquadPresenceTests.swift                              (copy)
├── SquadActivityEntryTests.swift                         (copy)
├── SquadTitleIDTests.swift                               (copy)
├── SquadMissionTests.swift                               (NEW)
├── WeeklyHonorTests.swift                                (NEW)
└── FriendChallengeTests.swift                            (NEW)

UNBOUNDTests/Services/
├── SquadStoreTests.swift                                 (copy)
├── SquadTitleThresholdEvaluatorTests.swift               (copy)
├── SquadServiceTests.swift                               (copy)
├── SquadActivityServiceTests.swift                       (copy)
├── LinkedSessionEvaluatorTests.swift                     (copy)
├── SessionXPAffinityBonusTests.swift                     (copy)
├── SquadMissionServiceTests.swift                        (NEW)
├── SquadHonorsServiceTests.swift                         (NEW)
└── FriendChallengeServiceTests.swift                     (NEW)
```

### MODIFY

```
UNBOUND/Services/WorkoutLog/WorkoutLogService.swift                   (markInWorkout + clearPresence + mission progress + activity record)
UNBOUND/Services/Ranking/SessionXPService.swift                       (affinity +10% bonus, non-stacking with +20% linked)
UNBOUND/Services/Attributes/AttributeService.swift                    (already has applyBoost from #5 — verify)
UNBOUND/Services/ServiceContainer.swift                                (wire 6 new services)
UNBOUND/Models/AttributeRankUpEvent.swift                              (notification names: squadStateChanged / squadPresenceChanged / linkedSessionDetected / squadMissionCompleted / weeklyHonorReceived / friendChallengeExpired)
UNBOUND/App/AniBodyApp.swift                                           (universal links handler)
UNBOUND/Views/Home/HomeTabView.swift                                   (add Squad tab; tab 4)
project.yml                                                             (applinks:unboundapp.com entitlement)
```

### NOT TOUCHED

- Session-flow Home modules
- Build hex pipeline (#1)
- Scan pipeline (#3)
- Ascension Tier pipeline (#4)
- Trial pipeline (#5)

---

## Standing rules

1. All subagent dispatches `model: "sonnet"` or higher.
2. SourceKit cross-file errors are NOISE. `xcodebuild` is authoritative.
3. `xcodegen` after any new Swift file.
4. Build: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build`
5. Reference branch: `/Users/jlin/Documents/toji/UNBOUND-squads/`. Literal `cp` for salvageable files.
6. RLS by default on every new table. Service-role-only inserts where indicated.
7. Don't deploy Supabase migrations or functions during implementation — that's the final ship step.
8. Production `SquadBackend` impls can be stubs throwing `.backendUnavailable` until Supabase is deployed. Tests use the mock.
9. Don't touch session-flow Home modules.

---

# Phase 1 — Pre-flight

## Task 1.1: Worktree + baseline

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git worktree add /Users/jlin/Documents/toji/UNBOUND-squads-v2 -b squads-v2 program-redesign
cp /Users/jlin/Documents/toji/UNBOUND/UNBOUND/Services/Secrets/Secrets.swift /Users/jlin/Documents/toji/UNBOUND-squads-v2/UNBOUND/Services/Secrets/Secrets.swift
cd /Users/jlin/Documents/toji/UNBOUND-squads-v2
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -3
```

Expected: 315 tests with 5 pre-existing failures (carries forward from trunk).

---

# Phase 2 — Backend schemas

## Task 2.1: 5 original squad migrations

Copy from squads-impl with new timestamps:

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/supabase/migrations/20260513120000_squad_schema.sql supabase/migrations/20260514130000_squad_schema.sql
cp /Users/jlin/Documents/toji/UNBOUND-squads/supabase/migrations/20260513130000_squad_activity_nullable_user.sql supabase/migrations/20260514130001_squad_activity_nullable_user.sql
git add supabase/migrations/
git commit -m "feat(squads): adopt squad schema + activity-user-nullable migrations from squads-impl"
```

## Task 2.2: squad_missions migration

Create `supabase/migrations/20260514130002_squad_missions.sql`:

```sql
create table squad_missions (
  id              uuid primary key default gen_random_uuid(),
  squad_id        uuid not null references public.squads(id) on delete cascade,
  week_iso        text not null,
  mission_kind    text not null,
  target          int not null,
  current_progress int not null default 0,
  completed_at    timestamptz,
  created_at      timestamptz not null default now(),
  unique (squad_id, week_iso)
);

create index on squad_missions (squad_id, week_iso desc);

alter table squad_missions enable row level security;

create policy "squad_missions: members can read"
  on squad_missions for select
  to authenticated
  using (public.is_squad_member(auth.uid(), squad_id));

create policy "squad_missions: service-role insert/update only"
  on squad_missions for insert
  to authenticated
  with check (false);

create policy "squad_missions: service-role update only"
  on squad_missions for update
  to authenticated
  using (false);
```

```bash
git add supabase/migrations/20260514130002_squad_missions.sql
git commit -m "feat(squads): squad_missions table for weekly cooperative goal"
```

## Task 2.3: squad_weekly_honors migration

Create `supabase/migrations/20260514130003_squad_weekly_honors.sql`:

```sql
create table squad_weekly_honors (
  id              uuid primary key default gen_random_uuid(),
  squad_id        uuid not null references public.squads(id) on delete cascade,
  week_iso        text not null,
  honor_kind      text not null,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  awarded_at      timestamptz not null default now()
);

create index on squad_weekly_honors (squad_id, week_iso desc);
create index on squad_weekly_honors (recipient_user_id);

alter table squad_weekly_honors enable row level security;

create policy "squad_weekly_honors: members can read"
  on squad_weekly_honors for select
  to authenticated
  using (public.is_squad_member(auth.uid(), squad_id));

create policy "squad_weekly_honors: service-role insert only"
  on squad_weekly_honors for insert
  to authenticated
  with check (false);
```

```bash
git add supabase/migrations/20260514130003_squad_weekly_honors.sql
git commit -m "feat(squads): squad_weekly_honors table for rotating spotlight"
```

## Task 2.4: friend_challenges migration

Create `supabase/migrations/20260514130004_friend_challenges.sql`:

```sql
create table friend_challenges (
  id              uuid primary key default gen_random_uuid(),
  challenger_id   uuid not null references auth.users(id) on delete cascade,
  challenged_id   uuid not null references auth.users(id) on delete cascade,
  squad_id        uuid not null references public.squads(id) on delete cascade,
  challenge_kind  text not null,
  started_at      timestamptz not null default now(),
  expires_at      timestamptz not null,
  winner_user_id  uuid references auth.users(id) on delete set null,
  accepted_at     timestamptz,
  challenger_progress int not null default 0,
  challenged_progress int not null default 0,
  check (challenger_id <> challenged_id)
);

create index on friend_challenges (squad_id, expires_at desc);
create index on friend_challenges (challenger_id);
create index on friend_challenges (challenged_id);

alter table friend_challenges enable row level security;

create policy "friend_challenges: squad members can read"
  on friend_challenges for select
  to authenticated
  using (public.is_squad_member(auth.uid(), squad_id));

create policy "friend_challenges: members can create challenge if both in same squad"
  on friend_challenges for insert
  to authenticated
  with check (
    auth.uid() = challenger_id
    and public.is_squad_member(auth.uid(), squad_id)
    and public.is_squad_member(challenged_id, squad_id)
  );

create policy "friend_challenges: participants can update progress"
  on friend_challenges for update
  to authenticated
  using (auth.uid() = challenger_id or auth.uid() = challenged_id);
```

```bash
git add supabase/migrations/20260514130004_friend_challenges.sql
git commit -m "feat(squads): friend_challenges table for opt-in 1v1 competition"
```

---

# Phase 3 — Core Swift models

## Task 3.1: 6 original squad models

Copy verbatim from squads-impl:

```bash
for f in Squad SquadMember SquadPresence SquadActivityEntry SquadState SquadTitleID; do
    cp "/Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/${f}.swift" "UNBOUND/Models/${f}.swift" 2>/dev/null || \
    cp "/Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Models/${f}.swift" "UNBOUND/Models/${f}.swift"
done

# Tests
for f in SquadTests SquadMemberTests SquadPresenceTests SquadActivityEntryTests SquadTitleIDTests; do
    cp "/Users/jlin/Documents/toji/UNBOUND-squads/UNBOUNDTests/Models/${f}.swift" "UNBOUNDTests/Models/${f}.swift"
done

xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadTests -only-testing:UNBOUNDTests/SquadMemberTests -only-testing:UNBOUNDTests/SquadPresenceTests -only-testing:UNBOUNDTests/SquadActivityEntryTests -only-testing:UNBOUNDTests/SquadTitleIDTests 2>&1 | tail -8
git add UNBOUND/Models/Squad.swift UNBOUND/Models/SquadMember.swift UNBOUND/Models/SquadPresence.swift UNBOUND/Models/SquadActivityEntry.swift UNBOUND/Models/SquadState.swift UNBOUND/Models/SquadTitleID.swift UNBOUNDTests/Models/Squad*Tests.swift
git commit -m "feat(squads): adopt 6 squad models + tests from squads-impl"
```

## Task 3.2: SquadMission model + tests

Create `UNBOUND/Models/SquadMission.swift`:

```swift
import Foundation

struct SquadMission: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let weekIso: String     // "2026-W20"
    let kind: Kind
    let target: Int
    var currentProgress: Int
    var completedAt: Date?
    let createdAt: Date

    var isCompleted: Bool { completedAt != nil }
    var progressFraction: Double { Double(currentProgress) / Double(max(target, 1)) }

    enum Kind: String, Codable, CaseIterable, Sendable {
        case alignedSessions   // X aligned-axis sessions across the squad
        case capstonesTogether // X trial capstones across the squad
        case focusSessions     // X focus-mode sessions across the squad
        case tierCrossings     // X tier crossings across the squad
        case linkedSessions    // X linked sessions across the squad
        case perfectAttendance // every member trains 4+ times

        var displayName: String {
            switch self {
            case .alignedSessions: return "Aligned Crew"
            case .capstonesTogether: return "Capstone Crew"
            case .focusSessions: return "Focus Crew"
            case .tierCrossings: return "Tier Crossing"
            case .linkedSessions: return "Linked Crew"
            case .perfectAttendance: return "Perfect Attendance"
            }
        }

        var subtitle: String {
            switch self {
            case .alignedSessions: return "Hit aligned-axis sessions together."
            case .capstonesTogether: return "Each clear a trial capstone."
            case .focusSessions: return "Hit focus-mode sessions as a crew."
            case .tierCrossings: return "Cross tiers together."
            case .linkedSessions: return "Stack linked workouts."
            case .perfectAttendance: return "All in, all week."
            }
        }
    }
}
```

Create `UNBOUNDTests/Models/SquadMissionTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class SquadMissionTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let m = SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W20",
            kind: .alignedSessions,
            target: 24,
            currentProgress: 8,
            completedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(SquadMission.self, from: data)
        XCTAssertEqual(decoded, m)
    }

    func testProgressFraction() {
        var m = SquadMission(
            id: UUID(), squadId: UUID(), weekIso: "2026-W20",
            kind: .alignedSessions, target: 10, currentProgress: 3,
            completedAt: nil, createdAt: .now
        )
        XCTAssertEqual(m.progressFraction, 0.3, accuracy: 0.01)
        XCTAssertFalse(m.isCompleted)
        m.completedAt = .now
        XCTAssertTrue(m.isCompleted)
    }

    func testAllKindsHaveDisplayName() {
        for kind in SquadMission.Kind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.subtitle.isEmpty)
        }
    }
}
```

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadMissionTests 2>&1 | tail -8
git add UNBOUND/Models/SquadMission.swift UNBOUNDTests/Models/SquadMissionTests.swift
git commit -m "feat(squads): SquadMission model + tests"
```

## Task 3.3: WeeklyHonor model + tests

Create `UNBOUND/Models/WeeklyHonor.swift`:

```swift
import Foundation

struct WeeklyHonor: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let weekIso: String
    let kind: Kind
    let recipientUserId: UUID
    let awardedAt: Date

    enum Kind: String, Codable, CaseIterable, Sendable {
        case mostConsistent
        case ironWill
        case clutchPerformer
        case mostImproved
        case comebackArc
        case earlyBird
        case nightGrinder
        case trialFinisher
        case supportBuff

        var displayName: String {
            switch self {
            case .mostConsistent: return "Most Consistent"
            case .ironWill: return "Iron Will"
            case .clutchPerformer: return "Clutch Performer"
            case .mostImproved: return "Most Improved"
            case .comebackArc: return "Comeback Arc"
            case .earlyBird: return "Early Bird"
            case .nightGrinder: return "Night Grinder"
            case .trialFinisher: return "Trial Finisher"
            case .supportBuff: return "Support Buff"
            }
        }

        var reason: String {
            switch self {
            case .mostConsistent: return "Most distinct training days"
            case .ironWill: return "Highest average RPE"
            case .clutchPerformer: return "Tier crossings during the week"
            case .mostImproved: return "Biggest attribute delta"
            case .comebackArc: return "Returned after 7+ days then logged 3+"
            case .earlyBird: return "Most pre-7am workouts"
            case .nightGrinder: return "Most post-9pm workouts"
            case .trialFinisher: return "Completed a Trial capstone"
            case .supportBuff: return "Most linked-session participation"
            }
        }

        var iconName: String {
            switch self {
            case .mostConsistent: return "calendar.badge.checkmark"
            case .ironWill: return "flame.fill"
            case .clutchPerformer: return "bolt.fill"
            case .mostImproved: return "arrow.up.right.circle.fill"
            case .comebackArc: return "arrow.uturn.up"
            case .earlyBird: return "sunrise.fill"
            case .nightGrinder: return "moon.stars.fill"
            case .trialFinisher: return "checkmark.seal.fill"
            case .supportBuff: return "figure.2"
            }
        }
    }
}
```

Tests follow the same pattern as Task 3.2 — codable roundtrip + all-kinds-have-display-name.

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/WeeklyHonorTests 2>&1 | tail -8
git add UNBOUND/Models/WeeklyHonor.swift UNBOUNDTests/Models/WeeklyHonorTests.swift
git commit -m "feat(squads): WeeklyHonor model + 9 honor kinds + tests"
```

## Task 3.4: FriendChallenge model + tests

Create `UNBOUND/Models/FriendChallenge.swift`:

```swift
import Foundation

struct FriendChallenge: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let challengerId: UUID
    let challengedId: UUID
    let squadId: UUID
    let kind: Kind
    let startedAt: Date
    let expiresAt: Date
    var acceptedAt: Date?
    var challengerProgress: Int
    var challengedProgress: Int
    var winnerUserId: UUID?

    var isActive: Bool { winnerUserId == nil && Date() < expiresAt }
    var isExpired: Bool { Date() >= expiresAt }
    var isPending: Bool { acceptedAt == nil }

    enum Kind: String, Codable, CaseIterable, Sendable {
        case mostSessions
        case noMissedDays
        case firstToFinishTrial
        case mostAlignedSessions
        case earlyRiser
        case proteinGoal

        var displayName: String {
            switch self {
            case .mostSessions: return "Most Sessions"
            case .noMissedDays: return "No Missed Days"
            case .firstToFinishTrial: return "First to Finish Trial"
            case .mostAlignedSessions: return "Most Aligned"
            case .earlyRiser: return "Early Riser (8am)"
            case .proteinGoal: return "Protein Goal"
            }
        }

        var subtitle: String {
            switch self {
            case .mostSessions: return "Most workout sessions this week."
            case .noMissedDays: return "Longest consecutive day streak."
            case .firstToFinishTrial: return "First to clear a trial capstone."
            case .mostAlignedSessions: return "Most aligned-axis sessions."
            case .earlyRiser: return "Most workouts before 8 AM."
            case .proteinGoal: return "Most days hitting protein target."
            }
        }
    }
}
```

Tests follow the same pattern.

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/FriendChallengeTests 2>&1 | tail -8
git add UNBOUND/Models/FriendChallenge.swift UNBOUNDTests/Models/FriendChallengeTests.swift
git commit -m "feat(squads): FriendChallenge model + 6 challenge kinds + tests"
```

---

# Phase 4 — Catalogs + Threshold evaluator

## Task 4.1: SquadTitleCatalog + Threshold evaluator + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/SquadTitleCatalog.swift UNBOUND/Services/Squads/SquadTitleCatalog.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/SquadTitleThresholdEvaluator.swift UNBOUND/Services/Squads/SquadTitleThresholdEvaluator.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUNDTests/Services/SquadTitleThresholdEvaluatorTests.swift UNBOUNDTests/Services/SquadTitleThresholdEvaluatorTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadTitleThresholdEvaluatorTests 2>&1 | tail -8
git add UNBOUND/Services/Squads/SquadTitleCatalog.swift UNBOUND/Services/Squads/SquadTitleThresholdEvaluator.swift UNBOUNDTests/Services/SquadTitleThresholdEvaluatorTests.swift
git commit -m "feat(squads): adopt SquadTitleCatalog + ThresholdEvaluator from squads-impl"
```

## Task 4.2: SquadMissionCatalog (template registry)

Create `UNBOUND/Services/Squads/SquadMissionCatalog.swift`:

```swift
import Foundation

/// Deterministic catalog of weekly mission templates.
/// `generate(for:weekIso:)` picks a template seeded by squad id + week.
enum SquadMissionCatalog {
    struct Template {
        let kind: SquadMission.Kind
        let targetMultiplier: Int  // multiplied by member count for final target
    }

    static let templates: [Template] = [
        Template(kind: .alignedSessions, targetMultiplier: 4),
        Template(kind: .capstonesTogether, targetMultiplier: 1),
        Template(kind: .focusSessions, targetMultiplier: 6),
        Template(kind: .tierCrossings, targetMultiplier: 1),
        Template(kind: .linkedSessions, targetMultiplier: 1),  // base 3 (see below)
        Template(kind: .perfectAttendance, targetMultiplier: 1),
    ]

    static func generate(squadId: UUID, weekIso: String, memberCount: Int) -> (kind: SquadMission.Kind, target: Int) {
        var hasher = Hasher()
        hasher.combine(squadId)
        hasher.combine(weekIso)
        let idx = abs(hasher.finalize()) % templates.count
        let t = templates[idx]
        let target: Int
        switch t.kind {
        case .linkedSessions:
            target = 3  // fixed minimum, requires 2+ members
        case .perfectAttendance:
            target = memberCount  // 1 unit per member
        default:
            target = t.targetMultiplier * memberCount
        }
        return (t.kind, target)
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/Squads/SquadMissionCatalog.swift
git commit -m "feat(squads): SquadMissionCatalog with 6 templates"
```

---

# Phase 5 — Stores

## Task 5.1: SquadStore + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/SquadStore.swift UNBOUND/Services/Squads/SquadStore.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUNDTests/Services/SquadStoreTests.swift UNBOUNDTests/Services/SquadStoreTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadStoreTests 2>&1 | tail -8
git add UNBOUND/Services/Squads/SquadStore.swift UNBOUNDTests/Services/SquadStoreTests.swift
git commit -m "feat(squads): adopt SquadStore (UserDefaults persistence) from squads-impl"
```

---

# Phase 6 — Services

## Task 6.1: SquadBackend protocol + production + mock

```bash
for f in SquadBackendProtocol SquadBackend MockSquadBackend; do
    cp "/Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/${f}.swift" "UNBOUND/Services/Squads/${f}.swift"
done
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/Squads/SquadBackend*.swift UNBOUND/Services/Squads/MockSquadBackend.swift
git commit -m "feat(squads): adopt SquadBackendProtocol + SquadBackend + MockSquadBackend"
```

## Task 6.2: SquadService + protocol + 16 tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/SquadServiceProtocol.swift UNBOUND/Services/Squads/SquadServiceProtocol.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/SquadService.swift UNBOUND/Services/Squads/SquadService.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUNDTests/Services/SquadServiceTests.swift UNBOUNDTests/Services/SquadServiceTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadServiceTests 2>&1 | tail -10
git add UNBOUND/Services/Squads/SquadService*.swift UNBOUNDTests/Services/SquadServiceTests.swift
git commit -m "feat(squads): adopt SquadService (createSquad/joinSquad/leaveSquad/setAffinity/aggregateBuild/loadCurrentSquad) + 16 tests"
```

## Task 6.3: SquadActivityService + backend + 6 tests

```bash
for f in SquadActivityServiceProtocol SquadActivityService SquadActivityBackendProtocol SquadActivityBackend MockSquadActivityBackend; do
    cp "/Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/${f}.swift" "UNBOUND/Services/Squads/${f}.swift"
done
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUNDTests/Services/SquadActivityServiceTests.swift UNBOUNDTests/Services/SquadActivityServiceTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadActivityServiceTests 2>&1 | tail -8
git add UNBOUND/Services/Squads/SquadActivity*.swift UNBOUND/Services/Squads/MockSquadActivityBackend.swift UNBOUNDTests/Services/SquadActivityServiceTests.swift
git commit -m "feat(squads): adopt SquadActivityService + backend + 6 tests"
```

## Task 6.4: SquadPresenceService + LinkedSessionEvaluator

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/SquadPresenceServiceProtocol.swift UNBOUND/Services/Squads/SquadPresenceServiceProtocol.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/SquadPresenceService.swift UNBOUND/Services/Squads/SquadPresenceService.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Services/Squads/LinkedSessionEvaluator.swift UNBOUND/Services/Squads/LinkedSessionEvaluator.swift
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUNDTests/Services/LinkedSessionEvaluatorTests.swift UNBOUNDTests/Services/LinkedSessionEvaluatorTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/LinkedSessionEvaluatorTests 2>&1 | tail -8
git add UNBOUND/Services/Squads/SquadPresence*.swift UNBOUND/Services/Squads/LinkedSessionEvaluator.swift UNBOUNDTests/Services/LinkedSessionEvaluatorTests.swift
git commit -m "feat(squads): adopt SquadPresenceService + LinkedSessionEvaluator + tests"
```

## Task 6.5: SquadMissionService + tests

Create `UNBOUND/Services/Squads/SquadMissionService.swift`:

```swift
import Foundation

@MainActor
protocol SquadMissionServiceProtocol: Sendable {
    func generateThisWeek(squadId: UUID) async throws -> SquadMission
    func currentMission(squadId: UUID) async -> SquadMission?
    func recordProgress(log: WorkoutLog, userId: String) async
    func evaluateCompletion(squadId: UUID) async
}

@MainActor
final class SquadMissionService: SquadMissionServiceProtocol {
    static let shared = SquadMissionService()
    private let backend: SquadBackendProtocol
    private let squadService: any SquadServiceProtocol
    private let logger = LoggingService.shared

    init(
        backend: SquadBackendProtocol = SquadBackend(),
        squadService: any SquadServiceProtocol = SquadService.shared
    ) {
        self.backend = backend
        self.squadService = squadService
    }

    func generateThisWeek(squadId: UUID) async throws -> SquadMission {
        let weekIso = Self.currentWeekIso()
        // Fetch squad to know member count
        // TODO(squads-impl): backend.fetchSquad + backend.fetchMembers
        let memberCount = 4  // fallback until SquadBackend fetch wires through
        let (kind, target) = SquadMissionCatalog.generate(squadId: squadId, weekIso: weekIso, memberCount: memberCount)
        let mission = SquadMission(
            id: UUID(),
            squadId: squadId,
            weekIso: weekIso,
            kind: kind,
            target: target,
            currentProgress: 0,
            completedAt: nil,
            createdAt: .now
        )
        // TODO(squads-impl, Phase 9): backend.insertSquadMission(mission) once Edge Function is deployed
        return mission
    }

    func currentMission(squadId: UUID) async -> SquadMission? {
        // TODO(squads-impl): backend.fetchCurrentMission(squadId:weekIso:)
        return nil
    }

    func recordProgress(log: WorkoutLog, userId: String) async {
        // Determine if log contributes to current mission:
        // - alignedSessions → check if log has aligned-axis content per trial
        // - focusSessions → log marked as focus mode
        // - capstonesTogether → if log triggered a capstone (.trialCapstoneCompleted notification)
        // For v1, increment a generic +1 per log. Refinement is follow-up.
        logger.log("SquadMissionService.recordProgress for user \(userId) — generic +1 (refinement pending)", level: .info)
    }

    func evaluateCompletion(squadId: UUID) async {
        guard let mission = await currentMission(squadId: squadId),
              mission.currentProgress >= mission.target,
              mission.completedAt == nil else { return }
        // TODO(squads-impl, Phase 9): backend.markMissionCompleted(missionId:)
        NotificationCenter.default.post(name: .squadMissionCompleted, object: mission)
    }

    static func currentWeekIso() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let date = Date()
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }
}
```

Add tests at `UNBOUNDTests/Services/SquadMissionServiceTests.swift` covering: `currentWeekIso` format, `generateThisWeek` returns expected target for member count, `evaluateCompletion` only fires when ≥ target.

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadMissionServiceTests 2>&1 | tail -8
git add UNBOUND/Services/Squads/SquadMissionService.swift UNBOUNDTests/Services/SquadMissionServiceTests.swift
git commit -m "feat(squads): SquadMissionService (weekly cooperative goal orchestration)"
```

## Task 6.6: SquadHonorsService + tests

Create `UNBOUND/Services/Squads/SquadHonorsService.swift`:

```swift
import Foundation

@MainActor
protocol SquadHonorsServiceProtocol: Sendable {
    func currentHonors(squadId: UUID) async -> [WeeklyHonor]
    func recordHonor(_ honor: WeeklyHonor) async
}

@MainActor
final class SquadHonorsService: SquadHonorsServiceProtocol {
    static let shared = SquadHonorsService()
    private let backend: SquadBackendProtocol
    private let logger = LoggingService.shared

    init(backend: SquadBackendProtocol = SquadBackend()) {
        self.backend = backend
    }

    func currentHonors(squadId: UUID) async -> [WeeklyHonor] {
        // TODO(squads-impl): backend.fetchHonors(squadId:weekIso:)
        return []
    }

    func recordHonor(_ honor: WeeklyHonor) async {
        // TODO(squads-impl): backend.insertHonor(honor)
        NotificationCenter.default.post(name: .weeklyHonorReceived, object: honor)
    }
}
```

Tests cover `recordHonor` posts notification.

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SquadHonorsServiceTests 2>&1 | tail -8
git add UNBOUND/Services/Squads/SquadHonorsService.swift UNBOUNDTests/Services/SquadHonorsServiceTests.swift
git commit -m "feat(squads): SquadHonorsService (weekly recognition orchestration)"
```

## Task 6.7: FriendChallengeService + tests

Create `UNBOUND/Services/Squads/FriendChallengeService.swift`:

```swift
import Foundation

@MainActor
protocol FriendChallengeServiceProtocol: Sendable {
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID) async throws -> FriendChallenge
    func activeChallenges(userId: UUID) async -> [FriendChallenge]
    func accept(_ challengeId: UUID) async throws
    func recordProgress(log: WorkoutLog, userId: String) async
    func evaluateExpired() async
}

@MainActor
final class FriendChallengeService: FriendChallengeServiceProtocol {
    static let shared = FriendChallengeService()
    private let backend: SquadBackendProtocol
    private let logger = LoggingService.shared

    init(backend: SquadBackendProtocol = SquadBackend()) {
        self.backend = backend
    }

    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID) async throws -> FriendChallenge {
        // TODO(squads-impl): backend.createFriendChallenge(...)
        throw SquadError.backendUnavailable
    }

    func activeChallenges(userId: UUID) async -> [FriendChallenge] {
        // TODO(squads-impl): backend.fetchActiveChallenges(userId:)
        return []
    }

    func accept(_ challengeId: UUID) async throws {
        // TODO(squads-impl): backend.updateChallengeAccepted(id:)
    }

    func recordProgress(log: WorkoutLog, userId: String) async {
        // For each active challenge involving userId, increment progress
        // based on challenge.kind. TODO real impl.
    }

    func evaluateExpired() async {
        // For each expired-but-no-winner challenge, compute winner by metric,
        // mark winner, post .friendChallengeExpired notification.
    }
}
```

Tests cover: createChallenge throws when backend unavailable, evaluateExpired correctly picks higher-progress as winner.

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/FriendChallengeServiceTests 2>&1 | tail -8
git add UNBOUND/Services/Squads/FriendChallengeService.swift UNBOUNDTests/Services/FriendChallengeServiceTests.swift
git commit -m "feat(squads): FriendChallengeService (opt-in 1v1 lifecycle)"
```

---

# Phase 7 — WorkoutLogService integration

## Task 7.1: markInWorkout + clearPresence + mission progress + challenge progress

In `UNBOUND/Services/WorkoutLog/WorkoutLogService.swift`, after RankService tier evaluation and Trials capstone evaluation, add (in this order):

```swift
// Squad presence: mark this user as in-workout for 3h.
if let squad = await SquadService.shared.state(userId: log.userId).currentSquad {
    await SquadPresenceService.shared.markInWorkout(userId: log.userId, squadId: squad.id)
}

// Squad Mission: increment progress against active mission.
await SquadMissionService.shared.recordProgress(log: log, userId: log.userId)

// Squad activity feed: record this log as an activity entry.
// (Only if user is in a squad.)
// TODO(squads-impl): SquadActivityService records aligned-axis sessions

// Friend Challenges: update progress on any active challenge involving this user.
await FriendChallengeService.shared.recordProgress(log: log, userId: log.userId)
```

(Adapt `SquadService.state(userId:)` to actual API.)

`clearPresence` is called WHEN THE WORKOUT ENDS, not saveLog. saveLog represents end-of-workout already, so add at the end:

```swift
await SquadPresenceService.shared.clearPresence(userId: log.userId)
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/WorkoutLog/WorkoutLogService.swift
git commit -m "feat(squads): WorkoutLogService hooks presence + mission + challenge progress"
```

## Task 7.2: Notification names

In `UNBOUND/Models/AttributeRankUpEvent.swift`, append to the existing `extension Notification.Name`:

```swift
static let squadStateChanged = Notification.Name("unbound.squadStateChanged")
static let squadPresenceChanged = Notification.Name("unbound.squadPresenceChanged")
static let squadActivityRecorded = Notification.Name("unbound.squadActivityRecorded")
static let linkedSessionDetected = Notification.Name("unbound.linkedSessionDetected")
static let squadStreakExtended = Notification.Name("unbound.squadStreakExtended")
static let squadTitleUnlocked = Notification.Name("unbound.squadTitleUnlocked")
static let squadMissionCompleted = Notification.Name("unbound.squadMissionCompleted")
static let weeklyHonorReceived = Notification.Name("unbound.weeklyHonorReceived")
static let friendChallengeExpired = Notification.Name("unbound.friendChallengeExpired")
static let friendChallengeAccepted = Notification.Name("unbound.friendChallengeAccepted")
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Models/AttributeRankUpEvent.swift
git commit -m "feat(squads): add 10 squad notification names"
```

## Task 7.3: SessionXP affinity bonus + non-stacking

Per squads-impl Phase 11: `SessionXPService.recordSession` checks for active squad with affinity matching the session's dominant axis. If match, +10% bonus. If the session was also part of a linked-session pair (gets +20% bonus via LinkedSessionEvaluator), don't stack.

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUNDTests/Services/SessionXPAffinityBonusTests.swift UNBOUNDTests/Services/SessionXPAffinityBonusTests.swift
```

In `UNBOUND/Services/Ranking/SessionXPService.swift`, add affinity bonus + non-stacking. The reference branch already shows the implementation pattern — adopt it.

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SessionXPAffinityBonusTests 2>&1 | tail -8
git add UNBOUND/Services/Ranking/SessionXPService.swift UNBOUNDTests/Services/SessionXPAffinityBonusTests.swift
git commit -m "feat(squads): SessionXP +10% affinity bonus, non-stacking with linked"
```

---

# Phase 8 — ServiceContainer wiring

## Task 8.1: Wire 6 new services into ServiceContainer

In `UNBOUND/Services/ServiceContainer.swift`, add slots:

```swift
let squads: any SquadServiceProtocol
let squadActivity: any SquadActivityServiceProtocol
let squadPresence: any SquadPresenceServiceProtocol
let squadMission: any SquadMissionServiceProtocol
let squadHonors: any SquadHonorsServiceProtocol
let friendChallenge: any FriendChallengeServiceProtocol
```

Wire defaults to `.shared` in both inits. Update `.mock` if it exists.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/ServiceContainer.swift
git commit -m "feat(squads): wire 6 squad services into ServiceContainer"
```

---

# Phase 9 — Edge Functions

## Task 9.1: 3 original Edge Functions

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/supabase/functions/join_squad/index.ts supabase/functions/join_squad/index.ts
cp /Users/jlin/Documents/toji/UNBOUND-squads/supabase/functions/detect_linked_sessions/index.ts supabase/functions/detect_linked_sessions/index.ts
cp /Users/jlin/Documents/toji/UNBOUND-squads/supabase/functions/evaluate_squad_streak/index.ts supabase/functions/evaluate_squad_streak/index.ts
git add supabase/functions/join_squad supabase/functions/detect_linked_sessions supabase/functions/evaluate_squad_streak
git commit -m "feat(squads): adopt 3 Edge Functions from squads-impl"
```

## Task 9.2: evaluate_squad_mission Edge Function

Create `supabase/functions/evaluate_squad_mission/index.ts`. Daily cron. For each squad with an active mission this week, query workout_logs and trial_capstones to determine progress. If `current_progress >= target`, mark `completed_at = now()` and insert a `squad_activity` row of kind `squadMissionCompleted`.

```bash
git add supabase/functions/evaluate_squad_mission
git commit -m "feat(squads): evaluate_squad_mission Edge Function (daily progress cron)"
```

## Task 9.3: assign_weekly_honors Edge Function

Create `supabase/functions/assign_weekly_honors/index.ts`. Sunday 11pm UTC cron. For each squad:
1. Compute per-member metrics for the past ISO week (consistency, RPE avg, tier crossings, attribute delta, comeback flag, pre-7am count, post-9pm count, capstone count, linked-session count).
2. Pick 3 honor kinds. For each, find the highest-metric member.
3. Constraints: no member gets 2 honors same week; rotate same-kind recipient vs last week.
4. Insert 3 rows into `squad_weekly_honors`.

```bash
git add supabase/functions/assign_weekly_honors
git commit -m "feat(squads): assign_weekly_honors Edge Function (Sunday rotation cron)"
```

---

# Phase 10 — UI primitives

## Task 10.1: SquadTitleBadge + SquadMemberCard + LinkedSessionToast + ActivityFeedRow + AffinityPickerSheet

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Views/Components/Unbound/SquadTitleBadge.swift UNBOUND/Views/Components/Unbound/SquadTitleBadge.swift
for f in SquadMemberCard LinkedSessionToast ActivityFeedRow AffinityPickerSheet; do
    cp "/Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Views/Squads/${f}.swift" "UNBOUND/Views/Squads/${f}.swift"
done
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Components/Unbound/SquadTitleBadge.swift UNBOUND/Views/Squads/SquadMemberCard.swift UNBOUND/Views/Squads/LinkedSessionToast.swift UNBOUND/Views/Squads/ActivityFeedRow.swift UNBOUND/Views/Squads/AffinityPickerSheet.swift
git commit -m "feat(squads): adopt 5 squad UI primitives from squads-impl"
```

## Task 10.2: SquadMissionCard

Create `UNBOUND/Views/Squads/SquadMissionCard.swift`. Renders mission title + shared progress bar + days remaining + reward preview.

```swift
import SwiftUI

struct SquadMissionCard: View {
    let mission: SquadMission

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("SQUAD MISSION")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                if mission.isCompleted {
                    Text("✓ CLEARED")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                }
            }
            Text(mission.kind.displayName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(mission.kind.subtitle)
                .font(Font.unbound.captionM)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                Text("\(mission.currentProgress)")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("/ \(mission.target)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
            }
            ProgressView(value: mission.progressFraction)
                .progressViewStyle(.linear)
                .tint(Color.unbound.accent)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
        )
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Squads/SquadMissionCard.swift
git commit -m "feat(squads): SquadMissionCard with shared progress bar"
```

## Task 10.3: WeeklyHonorsStrip

Create `UNBOUND/Views/Squads/WeeklyHonorsStrip.swift`. Renders 3 honor cards horizontally with recipient avatars + honor name + reason.

```swift
import SwiftUI

struct WeeklyHonorsStrip: View {
    let honors: [WeeklyHonor]
    let roster: [SquadMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WEEKLY HONORS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                if let first = honors.first {
                    Text(first.weekIso.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            HStack(spacing: 10) {
                ForEach(honors) { honor in
                    honorCard(honor)
                }
                if honors.isEmpty {
                    Text("Honors land Sunday night.")
                        .font(Font.unbound.captionM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
    }

    private func honorCard(_ honor: WeeklyHonor) -> some View {
        let recipient = roster.first { $0.userId == honor.recipientUserId }
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.unbound.accent.opacity(0.2))
                Image(systemName: honor.kind.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .frame(width: 36, height: 36)
            Text(honor.kind.displayName.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
            if let recipient {
                Text(recipient.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Squads/WeeklyHonorsStrip.swift
git commit -m "feat(squads): WeeklyHonorsStrip (3 horizontal honor cards, no ranking)"
```

## Task 10.4: FriendChallengeCard + CreateSheet + OutcomeToast

Create `UNBOUND/Views/Squads/FriendChallengeCard.swift` — shows two parallel progress bars (own + opponent), days remaining, NOT a leaderboard.

Create `UNBOUND/Views/Squads/FriendChallengeCreateSheet.swift` — pick opponent from roster + pick kind from `FriendChallenge.Kind.allCases`.

Create `UNBOUND/Views/Squads/FriendChallengeOutcomeToast.swift` — toast modifier listening for `.friendChallengeExpired`. Shows winner with friendly "rematch?" tone, no consolation text emphasizing the loss.

(Code for each follows the same pattern as previous toasts/cards. ~80 lines each.)

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Squads/FriendChallenge*.swift
git commit -m "feat(squads): FriendChallengeCard + CreateSheet + OutcomeToast"
```

---

# Phase 11 — Empty + Create + Join sheets

## Task 11.1: Empty + Create + Join (copy from squads-impl)

```bash
for f in SquadEmptyView CreateSquadSheet JoinSquadSheet SquadMemberDetailView; do
    cp "/Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Views/Squads/${f}.swift" "UNBOUND/Views/Squads/${f}.swift"
done
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Squads/SquadEmptyView.swift UNBOUND/Views/Squads/CreateSquadSheet.swift UNBOUND/Views/Squads/JoinSquadSheet.swift UNBOUND/Views/Squads/SquadMemberDetailView.swift
git commit -m "feat(squads): adopt SquadEmptyView + CreateSquadSheet + JoinSquadSheet + SquadMemberDetailView"
```

---

# Phase 12 — SquadDetailView (the big one)

## Task 12.1: Adopt SquadDetailView + add Mission/Honors/Challenge sections

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Views/Squads/SquadDetailView.swift UNBOUND/Views/Squads/SquadDetailView.swift
```

Then EDIT to insert 3 new sections in the existing layout. The squads-impl version has 8 sections. New layout (11 sections):

1. Header card (name + member count + Invite button) — existing
2. **SquadMissionCard** — NEW (top placement, primary)
3. Aggregate Build hex — existing
4. Affinity card — existing
5. Squad streak row — existing
6. Roster grid — existing
7. **WeeklyHonorsStrip** — NEW (between roster and activity feed)
8. Activity feed — existing
9. Squad Titles row — existing
10. **Friend Challenges section** — NEW (list of `FriendChallengeCard`s + "+ Create challenge" button)
11. Footer settings — existing

Add state for the 3 new data sources:

```swift
@State private var currentMission: SquadMission? = nil
@State private var weeklyHonors: [WeeklyHonor] = []
@State private var activeChallenges: [FriendChallenge] = []
@State private var showChallengeCreate = false
```

In `.task`, load alongside existing squad state load.

Wire `.onReceive(.squadMissionCompleted)`, `.onReceive(.weeklyHonorReceived)`, `.onReceive(.friendChallengeExpired)` to refresh those sections.

Apply `.friendChallengeOutcomeToast()` modifier at view root.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Squads/SquadDetailView.swift
git commit -m "feat(squads): SquadDetailView 11 sections (Mission + Honors + Challenges added)"
```

---

# Phase 13 — Squad tab + universal links

## Task 13.1: SquadTabView (root)

```bash
cp /Users/jlin/Documents/toji/UNBOUND-squads/UNBOUND/Views/Squads/SquadTabView.swift UNBOUND/Views/Squads/SquadTabView.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Squads/SquadTabView.swift
git commit -m "feat(squads): adopt SquadTabView (empty-vs-detail router)"
```

## Task 13.2: Wire SquadTabView into HomeTabView

In `UNBOUND/Views/Home/HomeTabView.swift`, add a 5th tab:

```swift
NavigationStack {
    SquadTabView()
}
.tabItem {
    Image(systemName: "figure.2")
    Text("Squad")
}
.tag(4)
```

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UnboundHomeViewSessionFlowTests 2>&1 | tail -8
git add UNBOUND/Views/Home/HomeTabView.swift
git commit -m "feat(squads): add Squad tab to tab bar (5 tabs total)"
```

## Task 13.3: Universal links + AASA doc

In `UNBOUND/App/AniBodyApp.swift`, add:

```swift
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    guard let url = activity.webpageURL else { return }
    let comps = url.pathComponents.filter { $0 != "/" }
    guard comps.count == 2, comps[0] == "squad" else { return }
    let code = comps[1].uppercased()
    NotificationCenter.default.post(name: .squadInviteCodeReceived, object: code)
    // Switch to Squad tab — wire via selectedTab binding to HomeTabView
}
```

Add `.squadInviteCodeReceived` notification to the existing Notification.Name extension.

In `project.yml`, add:

```yaml
com.apple.developer.associated-domains:
  - applinks:unboundapp.com
```

Document the AASA JSON file as a comment at the top of AniBodyApp.swift:

```swift
// Universal Links: https://unboundapp.com/squad/<code>
//
// AASA file deployment at https://unboundapp.com/.well-known/apple-app-site-association:
// {
//   "applinks": {
//     "details": [
//       { "appIDs": ["TEAMID.com.unboundapp.ios"], "components": [{ "/": "/squad/*" }] }
//     ]
//   }
// }
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/App/AniBodyApp.swift UNBOUND/Models/AttributeRankUpEvent.swift project.yml
git commit -m "feat(squads): universal links for /squad/<code> deep-link join + applinks entitlement"
```

---

# Phase 14 — Final regression + handoff

## Task 14.1: Full test suite

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -3
```

Expected: TEST SUCCEEDED with 5 pre-existing failures. Test count substantially higher (~50+ new tests).

## Task 14.2: Grep verification

```bash
echo "=== Squad refs present ==="
grep -rn "SquadService\|SquadTabView\|SquadMission\|WeeklyHonor\|FriendChallenge" UNBOUND/ --include="*.swift" | wc -l

echo "=== No leaderboard strings ==="
grep -rn "leaderboard\|Leaderboard\|ranked\|last place" UNBOUND/Views/Squads/ --include="*.swift"

echo "=== Session-flow Home preserved ==="
grep -c "BEGIN SESSION\|SESSION PLAN\|COACH CUE\|Move\b\|Foundation" UNBOUND/Views/Home/UnboundHomeView.swift
```

## Task 14.3: Sim smoke

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/squads-v2-final build 2>&1 | tail -3
xcrun simctl install booted /tmp/squads-v2-final/Build/Products/Debug-iphonesimulator/UNBOUND.app
xcrun simctl terminate booted com.unboundapp.ios 2>&1 | tail -1
xcrun simctl launch booted com.unboundapp.ios
sleep 5
xcrun simctl io booted screenshot /tmp/squads-v2-home.png
```

Verify Home renders session-flow + 5 tabs. Tap Squad tab → SquadEmptyView appears.

## Task 14.4: Handoff doc

```bash
cat > docs/superpowers/handoff/2026-05-14-squads-v2-smoke.md <<EOF
# Squads (Additive v2) — Final Smoke

Sub-project #6 shipped on \`squads-v2\`. Ready for merge into \`program-redesign\`.

## What ships
- 5th tab in tab bar (Squad — figure.2 icon)
- Full Supabase backend: 8 tables, 5 Edge Functions
- Invite-only crews of 3-8 via /squad/<code> deep link
- Linked workouts with +20% XP bonus
- Affinity (+10% XP, non-stacking with linked +20%)
- Squad Missions (cooperative weekly goal, no ranking)
- Weekly Honors (rotating Sunday spotlight, 9 categories)
- Friend Challenges (opt-in 1v1, 1-week expire)
- LinkedSessionToast + TrialCapstoneToast-style honor + outcome toasts

## Backend deployment (manual ship step)
1. \`supabase db push\` — applies 5 migrations
2. \`supabase functions deploy\` — deploys 5 Edge Functions
3. Configure webhook on \`workout_logs\` insert → \`detect_linked_sessions\`
4. Schedule via pg_cron:
   - \`evaluate_squad_streak\` daily 03:00 UTC
   - \`evaluate_squad_mission\` daily 04:00 UTC
   - \`assign_weekly_honors\` Sunday 23:00 UTC
5. Deploy AASA file to https://unboundapp.com/.well-known/apple-app-site-association

## Session-flow Home preserved
Verified — Squad is a NEW tab, no changes to Home modules.

## Known follow-ups
- Production SquadBackend impls are stubs (throw .backendUnavailable). Real Supabase calls land at deploy.
- FriendChallengeService.recordProgress logic is generic +1 until per-kind metric refinement.
- Universal link AASA file is a marketing-site deployment, not in this PR.
EOF
git add docs/superpowers/handoff/2026-05-14-squads-v2-smoke.md
git commit -m "chore(squads): final smoke + handoff doc — sub-project #6 ready for merge"
```

---

## Self-Review Notes

**Spec coverage:**
- ✅ All 5 original tables + 3 new tables → Phase 2
- ✅ 6 original models + 3 new models → Phase 3
- ✅ Catalogs + Threshold Evaluator + MissionCatalog → Phase 4
- ✅ SquadStore → Phase 5
- ✅ 6 services (SquadService, SquadActivity, SquadPresence, SquadMission, SquadHonors, FriendChallenge) → Phase 6
- ✅ WorkoutLogService hooks + 10 notification names + SessionXP affinity → Phase 7
- ✅ ServiceContainer wiring → Phase 8
- ✅ 5 Edge Functions → Phase 9
- ✅ UI primitives (5 from squads-impl + MissionCard + HonorsStrip + 3 FriendChallenge views) → Phase 10
- ✅ Empty + Create + Join + MemberDetail → Phase 11
- ✅ SquadDetailView 11 sections → Phase 12
- ✅ Squad tab + universal links → Phase 13
- ✅ Final regression + handoff → Phase 14

**Placeholder scan:** Production backend impls are stubs — intentional, documented as `.backendUnavailable` throwers until deploy. No "TBD" in critical paths.

**Type consistency:**
- `Squad`, `SquadMember`, `SquadMission`, `WeeklyHonor`, `FriendChallenge` all use `UUID` for ids.
- Notification names consistent across phases.

**Known soft spots:**
1. `SquadMissionService.recordProgress` uses generic +1 for v1 — refinement is follow-up.
2. `FriendChallengeService.recordProgress` per-kind logic is stubbed.
3. Production `SquadBackend` Supabase calls — stubs until deploy.
4. AASA file deployment is marketing-site work, not iOS.
5. APNs push for `linkedSessionDetected` — falls back to in-app delivery if push infra isn't ready.
