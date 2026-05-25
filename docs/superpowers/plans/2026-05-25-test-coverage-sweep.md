# Test Coverage Sweep — Squads / Coach / Ranking / Trials

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** Backfill unit-test coverage on the 4 service trees that currently have zero tests. Target: **10-15 high-leverage tests per tree** — not exhaustive coverage, but enough that the most-changed services have a safety net. Lets us refactor without fear when Squads v1 / program redesign lands.

**Architecture:** No production code changes. Pure test additions. For each tree: (1) identify the top 3-5 services by importance, (2) write tests for happy path + 2-3 edge cases per service, (3) ensure each service has at least a smoke test, (4) commit per service so failures don't cascade.

**Tech stack:** XCTest, existing mock service patterns.

---

## Scope

In:
- `UNBOUND/UNBOUNDTests/Services/Squads/` — 10-15 tests
- `UNBOUND/UNBOUNDTests/Services/Coach/` — 10-15 tests
- `UNBOUND/UNBOUNDTests/Services/Ranking/` — 10-15 tests
- `UNBOUND/UNBOUNDTests/Services/Trials/` — 10-15 tests
- For each tree: at least one smoke test per service file

Out:
- Refactors to make services more testable (defer; flag in plan notes)
- Integration tests / UI tests
- 100% coverage — aim for the high-value paths
- Performance tests

---

## Approach per tree

For each service file in scope:

1. **Read the file**, identify the public API (every `func` not `private`).
2. **Write a smoke test** — initialize the service with mocks, call its main entry point, assert it doesn't crash.
3. **Pick the 1-3 most-important behaviors** — usually the ones that have if/else branches or state mutations.
4. **Write happy-path tests** for those.
5. **Write 1 edge-case test** per behavior (boundary, error path, empty input).

If a service can't be tested without major refactoring (e.g. uses singletons, hard-coded dependencies), **flag it in the test file's header comment with `// TODO(testability):`** and write whatever you can. Don't refactor the service in this sweep.

---

## File-Touch Matrix

### Squads (already partly covered post-Phase 1)

| File to test | Test file | Tests target |
|---|---|---|
| `SquadService.swift` | `SquadServiceTests.swift` | create, join (cap enforced), leave, fetch state |
| `SquadMessageStore.swift` (after P1 lands) | `SquadMessageStoreTests.swift` | load, subscribe idempotency, send + optimistic append, dedupe by id |
| `SquadReactionStore.swift` (after P2 lands) | already in P2 plan | — |
| `SquadPresenceService.swift` | `SquadPresenceServiceTests.swift` | start session, expiry, multi-member presence |
| `OpenChallengeService.swift` (after P3) | already in P3 plan | — |
| `CoopPairChallengeService.swift` (after P3) | already in P3 plan | — |

### Coach

| File to test | Test file | Tests target |
|---|---|---|
| `CoachActionExecutor.swift` | `CoachActionExecutorTests.swift` | execute swap, execute deload, execute repRange, undo, redo, history cap |
| `PTContextBuilder.swift` | `PTContextBuilderTests.swift` | build context from empty state, from full state, includes recent workouts |
| `PlateauFixService.swift` | `PlateauFixServiceTests.swift` | detect plateau on stagnant weights, suggest deload, ignore early data |
| `TravelPlanService.swift` | `TravelPlanServiceTests.swift` | adjust program for no-equipment, restore on travel end |

### Ranking

| File to test | Test file | Tests target |
|---|---|---|
| `RankingService.swift` (or main file — locate via grep) | `RankingServiceTests.swift` | compute rank from attribute profile, threshold transitions |
| `TitleEvaluator.swift` (if exists) | `TitleEvaluatorTests.swift` | unlock at threshold, no unlock below, equipped state |
| `AttributeProfile*.swift` | `AttributeProfileTests.swift` | aggregate from logs, axis defaults, decay |
| `SkillUnlockStandards.swift` | `SkillUnlockStandardsTests.swift` | passing standard unlocks tier, failing leaves user at prior tier |
| `PrereqClearer.swift` (already covered in program redesign Phase C) | — | skip |

### Trials

| File to test | Test file | Tests target |
|---|---|---|
| `TrialsService.swift` | `TrialsServiceTests.swift` | start, complete, fail, retry-cooldown enforced |
| `TrialsCatalog.swift` | `TrialsCatalogTests.swift` | catalog non-empty, every trial has required fields, theme distribution sensible |
| `TrialsNotificationScheduler.swift` | `TrialsNotificationSchedulerTests.swift` | schedule on start, cancel on complete, no duplicate notifications |
| `TrialsRewardService.swift` (if exists) | `TrialsRewardServiceTests.swift` | reward calculated correctly per theme |

---

## Tasks

### Task 1 — Squad service test sweep

For each Squad service file in scope above, add the listed tests using existing `MockSquadBackend` and similar.

Commit per file: `test(squads): SquadServiceTests` etc.

**Acceptance:** All Squad tests green; `xcodebuild test -only-testing:UNBOUNDTests/Services/Squads` finishes cleanly.

### Task 2 — Coach service test sweep

For each Coach service file, add the listed tests.

If `PlateauFixService` or `TravelPlanService` have no public test seams (e.g. they internally pull from singletons), inject a protocol-based dependency just-enough to test, OR flag with `TODO(testability)` and skip.

**Acceptance:** Coach tests green.

### Task 3 — Ranking service test sweep

For each Ranking service file. Many of these consume `AttributeProfile` — use a helper `makeAttributeProfile(power: 60, agility: 40, …)` to construct test fixtures.

**Acceptance:** Ranking tests green.

### Task 4 — Trials service test sweep

For each Trials service file. The catalog test should fail loudly if a trial is missing required fields — that's its purpose.

**Acceptance:** Trials tests green.

### Task 5 — CI threshold + reporting

**File:** Modify `.github/workflows/*.yml` (or whichever CI is in use; if none, skip).

Add a job that runs:
```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES
```

Print coverage % per tree as part of the CI summary. Don't fail CI on coverage drops yet — establish baseline first.

**Acceptance:** CI run shows coverage % per tree.

**Commit:** `ci: add coverage reporting`

---

## Notes for the implementer

- Don't refactor production code. The goal is "tests around what exists", not "make this testable in the ideal way."
- Reuse existing mock backends and ServiceContainer.mock wherever possible.
- If a service is genuinely impossible to test (e.g. tightly coupled singletons everywhere), write a one-line test that constructs it and asserts it didn't crash — that's still better than zero.
- Don't aim for 100%. Aim for "the next refactor I want to do isn't terrifying."

---

## Verification

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/Squads \
  -only-testing:UNBOUNDTests/Services/Coach \
  -only-testing:UNBOUNDTests/Services/Ranking \
  -only-testing:UNBOUNDTests/Services/Trials
```

All green = sweep done. Manually inspect the coverage report — flag any service still showing 0% in a follow-up.
