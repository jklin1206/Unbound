# Rank Gates Engine Foundations — Implementation Plan (Plan 1 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the 8 overall-rank trial definitions as the new destination-world gates (First Light → The Last Gate) with the new station machinery (per-option floors, heavy strikes, weakest-attribute resolution) and Gate Keys eligibility — engine only, no UI.

**Architecture:** Rewrite `OverallRankTrialDefinitions` + `TrialStandards` in place; extend the existing station/evaluation machinery minimally (3 additions); keep ids stable via `legacyIds`; everything testable headlessly. UI plans (2–4) build on these definitions.

**Tech Stack:** Swift, XCTest, xcodegen project. Run tests via the standard suite; `TrialStandardsSnapshotTests` is re-baselined **deliberately** in this plan.

**Spec:** `docs/superpowers/specs/2026-06-12-rank-gates-redesign-design.md` (the spec's §5 gate tables are the source of truth for every floor below).

**Roadmap context:** Plan 1 = engine (this doc) · Plan 2 = experience spine UI · Plan 3 = Crossing + asset manager + art lane · Plan 4 = per-gate visualizers + legacy deletion. Plans 2–4 authored at phase start.

**Lanes:** Tasks tagged `[CLAUDE]` (judgment/engine) or `[CODEX-OK]` (mechanical, parallel-safe after the exemplar lands). Codex lanes use isolated worktrees per CLAUDE.md's lane table; explicit-path staging only; every Codex result re-verified (build + tests) before merge.

---

## Task 0: Balance checkpoint with jlin `[CLAUDE]` — BLOCKING

**Files:** none (conversation gate)

- [ ] **Step 1:** Present spec §14's seven proposed defaults to jlin as a confirm/adjust list. Do not start Task 7+ until each is confirmed. Record outcomes by editing the values in this plan's tables inline (they are written with the §14 defaults).

---

## Task 1: `RankTrialFormat` — new cases, tolerant decode `[CLAUDE]`

**Files:**
- Modify: `UNBOUND/Services/Ranking/OverallRankTrialService.swift:17-39`
- Test: `UNBOUNDTests/Services/OverallRankTrialFormatTests.swift` (create)

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class OverallRankTrialFormatTests: XCTestCase {
    func testLegacyRawValuesDecodeToNewFormats() throws {
        let legacyToNew: [String: RankTrialFormat] = [
            "daily100": .firstLight,
            "operatorScreen": .theCount,
            "finisher": .theForging,
            "fixedDeck": .deckOfProof,
            "tower": .theAscent,
            "bossRush": .sevenSeals,
            "raid": .theThreshold,
            "finalExam": .theLastGate
        ]
        for (legacy, expected) in legacyToNew {
            let data = Data("\"\(legacy)\"".utf8)
            let decoded = try JSONDecoder().decode(RankTrialFormat.self, from: data)
            XCTAssertEqual(decoded, expected, "legacy raw \(legacy)")
        }
    }

    func testDisplayNamesAreGateNames() {
        XCTAssertEqual(RankTrialFormat.firstLight.displayName, "First Light")
        XCTAssertEqual(RankTrialFormat.theCount.displayName, "The Count")
        XCTAssertEqual(RankTrialFormat.theForging.displayName, "The Forging")
        XCTAssertEqual(RankTrialFormat.deckOfProof.displayName, "Deck of Proof")
        XCTAssertEqual(RankTrialFormat.theAscent.displayName, "The Ascent")
        XCTAssertEqual(RankTrialFormat.sevenSeals.displayName, "The Seven Seals")
        XCTAssertEqual(RankTrialFormat.theThreshold.displayName, "The Threshold")
        XCTAssertEqual(RankTrialFormat.theLastGate.displayName, "The Last Gate")
    }
}
```

- [ ] **Step 2: Run to verify failure** — `xcodegen generate` first if the test file is new. Expected: compile failure (`firstLight` not defined).

- [ ] **Step 3: Implement** — replace the enum body (keep the type name):

```swift
enum RankTrialFormat: String, Codable, CaseIterable, Equatable, Sendable {
    case firstLight
    case theCount
    case theForging
    case deckOfProof
    case theAscent
    case sevenSeals
    case theThreshold
    case theLastGate

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "daily100": self = .firstLight
        case "operatorScreen": self = .theCount
        case "finisher": self = .theForging
        case "fixedDeck": self = .deckOfProof
        case "tower": self = .theAscent
        case "bossRush": self = .sevenSeals
        case "raid": self = .theThreshold
        case "finalExam": self = .theLastGate
        default:
            guard let format = RankTrialFormat(rawValue: raw) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown RankTrialFormat raw value: \(raw)"
                ))
            }
            self = format
        }
    }

    var displayName: String {
        switch self {
        case .firstLight: return "First Light"
        case .theCount: return "The Count"
        case .theForging: return "The Forging"
        case .deckOfProof: return "Deck of Proof"
        case .theAscent: return "The Ascent"
        case .sevenSeals: return "The Seven Seals"
        case .theThreshold: return "The Threshold"
        case .theLastGate: return "The Last Gate"
        }
    }
}
```

- [ ] **Step 4:** Repo-wide grep for old case usage: `grep -rn "\.daily100\|\.operatorScreen\|\.finisher\b\|\.fixedDeck\|\.tower\b\|\.bossRush\|\.raid\b\|\.finalExam" UNBOUND UNBOUNDTests` — update every site to the new case (the readiness card, `WorkoutReadyView+Blocks` dispatch, mode views, demo recorder, tests). Per the namespace-migration rule, grep the *implicit* `.case` form repo-wide including tests, not just `RankTrialFormat.case`.
- [ ] **Step 5:** Run the format tests + full build. Expected: PASS, build green.
- [ ] **Step 6: Commit** — `git add <explicit paths touched>` · `git commit -m "feat(gates): RankTrialFormat gate-name cases with tolerant legacy decode"`

---

## Task 2: `TrialStandards` rewrite `[CLAUDE]`

**Files:**
- Modify: `UNBOUND/Models/Standards/Gates/TrialStandards.swift` (full rewrite)
- Modify: `UNBOUNDTests/.../TrialStandardsSnapshotTests.swift` (re-baseline — locate via `grep -rl TrialStandardsSnapshot UNBOUNDTests`)

- [ ] **Step 1:** Rewrite `TrialStandards` with gate-named enums. Values carried from current standards unless marked NEW:

```swift
enum TrialStandards {
    /// Gate I — First Light (Initiate → Novice, .firstLight)
    enum FirstLight {
        static let lowerReps = 20
        static let pushReps = 15
        static let pullReps = 20
        static let stepReps = 20
        static let stepWindowSeconds = 120        // NEW: timed Steps window (jlin-approved)
        static let trunkHoldSeconds = 25
        static let stationCapSeconds = 14 * 60
    }

    /// Gate II — The Count (Novice → Apprentice, .theCount)
    enum TheCount {
        static let engineMeters = 700
        static let engineCapSeconds = 6 * 60
        static let cadenceSecondsPerRep = 4       // NEW: bell cycle; windows derive from it
        static let lowerReps = 30                 // window = 30×4s = 120s
        static let pushReps = 18                  // window = 18×4s ≈ 80s → keep 120s floor window
        static let pullReps = 24                  // window = 24×4s ≈ 100s → 120s
        static let stationCapSeconds = 2 * 60     // unchanged: cadence windows land on 2:00
        static let carryMeters = 80
        static let carryCapSeconds = 3 * 60
        static let carryLoadPercent = 0.20
        static let stillnessHoldSeconds = 60      // now universal across loadouts (jlin-approved)
    }

    /// Gate III — The Forging (Apprentice → Forged, .theForging)
    enum TheForging {
        static let stokeEngineMeters = 300        // unscored opener
        static let strikeReps = [8, 5, 3]         // NEW: scored bar lives on the 3s only
        static let scoredStrikeReps = 3
        static let noGymHingeLoadPercent = 0.25   // NEW: backpack single-leg RDL scored load
        static let scoredPullReps = 3             // strict pull-ups (bar loadouts)
        static let quenchCarryMeters = 40
        // Strike load floors are NOT duplicated here: resolved at draft time from
        // StrengthStandards Forged-tier ratios (single source). See Task 4.
    }

    /// Gate IV — Deck of Proof (Forged → Veteran, .deckOfProof) — mechanics locked
    enum DeckOfProof {
        static let aceReps = 11
        static let faceCardReps = 10
        static let restSeconds = 30
        static let rowConversionMultiplier = 1.5  // NEW: row cards count ×1.5 vs pull-ups
    }

    /// Gate V — The Ascent (Veteran → Master, .theAscent)
    enum TheAscent {
        static let floor1Meters = 300
        static let lowerReps = 24
        static let pushReps = 20
        static let pullUpReps = 12                // NEW: strict pull-up floor (was 20 rows) — checkpoint #1
        static let rowFallbackReps = 18           // NEW: 12 × 1.5
        static let hingeReps = 30
        static let carryMeters = 100
        static let carryLoadPercentNoGym = 0.10
        static let carryLoadPercentLoaded = 0.25
        static let longEngineMeters = 500
        static let explosiveReps = 20
        static let blendPushReps = 15
        static let blendPullUpReps = 8            // NEW (was 15 rows) — checkpoint #1
        static let blendRowFallbackReps = 12
        static let bossHoldSeconds = 90
        static let bossHoldCapSeconds = 5 * 60
    }

    /// Gate VI — The Seven Seals (Master → Vessel, .sevenSeals)
    enum SevenSeals {
        static let sealCapSeconds = 6 * 60
        static let enduranceEngineMeters = 800
        static let vitalityLowerReps = 48
        static let explosivenessReps = 40
        static let powerStrikeReps = 3            // NEW seal — Vessel-tier ratios via Task 4 — checkpoint #2
        static let controlHoldSeconds = 60
        static let controlSets = 2
        static let mobilityDeepSquatHoldSeconds = 60   // NEW seal — checkpoint #3
        static let mobilityCossackRepsPerSide = 10     // NEW seal — checkpoint #3
        static let spiritCarryMeters = 200
        static let spiritCarryLoadPercentNoGym = 0.15
        static let spiritCarryLoadPercentLoaded = 0.30
    }

    /// Gate VII — The Threshold (Vessel → Ascendant, .theThreshold)
    enum TheThreshold {
        static let approachEngineMeters = 400
        static let approachSets = 3
        static let approachCapSeconds = 18 * 60
        static let breachReps = 10
        static let breachSets = 4
        static let breachCapSeconds = 32 * 60
        static let breachCarryMeters = 60
        static let carryLoadPercentNoGym = 0.15
        static let carryLoadPercentLoaded = 0.30
        static let holdTheLightSeconds = 120
        static let holdSets = 1
        static let holdCapSeconds = 15 * 60
    }

    /// Gate VIII — The Last Gate (Ascendant → Unbound, .theLastGate) — checkpoint #4
    enum TheLastGate {
        // Landing 1 — First Light memory (one set each)
        static let landing1LowerReps = 20
        static let landing1PushReps = 15
        static let landing1PullReps = 20
        static let landing1StepReps = 20
        static let landing1HoldSeconds = 25
        static let landing1CapSeconds = 8 * 60
        // Landing 2 — The Count memory
        static let landing2EngineMeters = 400
        static let landing2WindowSeconds = 150
        // Landing 3 — The Forging memory (Unbound-tier ratios via Task 4)
        static let landing3StrikeReps = 3
        // Landing 4 — The Last Hand: 13 cards across all four suits, standard values
        static let landing4CardCount = 13
        static let landing4CapSeconds = 12 * 60
        // Landing 5 — The Ascent memory
        static let landing5EngineMeters = 500
        static let landing5HoldSeconds = 60
        // Landing 6 — The Seals memory: weakest attribute, floors from SevenSeals
        // Landing 7 — The Threshold memory
        static let landing7CarryMeters = 240
        static let landing7CarryLoadPercentNoGym = 0.20
        static let landing7CarryLoadPercentLoaded = 0.35
        // The Summit
        static let summitHoldSeconds = 120
        static let summitCapSeconds = 10 * 60
    }
}
```

- [ ] **Step 2:** Build. Every compile error is a consumer of an old enum name (`Daily100`, `OperatorScreen`, `Finisher`, `Tower`, `BossRush`, `Raid`, `FinalExam`) — those consumers are rewritten in Tasks 7–14; for THIS commit, fix only `TrialStandardsSnapshotTests` (delete old assertions, snapshot the new values verbatim) and leave definition builders on a temporary `typealias` shim ONLY if needed to stay green; prefer landing Task 2 together with Task 7's first commit if the shim is awkward.
- [ ] **Step 3:** Run snapshot tests → PASS. Commit: `feat(gates): TrialStandards rebaselined to gate-named enums`.

---

## Task 3: Per-option floors (`TrialMovementOption.floorOverride`) `[CLAUDE]`

The pull ladder needs different floors per option at the same station (12 pull-ups vs 18 rows).

**Files:**
- Modify: `UNBOUND/Services/Ranking/OverallRankTrialService.swift:139-154` (`TrialMovementOption`)
- Modify: the `option(...)` builder in `OverallRankTrialDefinitions.swift:455-479` and the resolver/evaluator sites that read station `minimumValue` (locate: `grep -n "minimumValue" UNBOUND/Services/Ranking/*.swift`)
- Test: `UNBOUNDTests/Services/OverallRankTrialServiceTests+Evaluation.swift` (extend)

- [ ] **Step 1: Failing test**

```swift
func testPerOptionFloorOverridesStationMinimum() {
    // Station floor 12 (pull-ups); the inverted-row option overrides to 18.
    let station = OverallRankTrialDefinitions.testStation(
        id: "t-pull", category: .pull, movementId: "exercise.pullup",
        metric: .reps, minimumValue: 12,
        movementOptions: [
            .test(id: "exercise.pullup"),
            .test(id: "exercise.inverted-row", floorOverride: 18)
        ]
    )
    XCTAssertEqual(station.resolvedMinimum(forMovementId: "exercise.pullup"), 12)
    XCTAssertEqual(station.resolvedMinimum(forMovementId: "exercise.inverted-row"), 18)
    XCTAssertEqual(station.resolvedMinimum(forMovementId: "exercise.unknown"), 12)
}
```

(Add small `testStation`/`TrialMovementOption.test` factories in the test target if not present.)

- [ ] **Step 2:** Run → FAIL (`floorOverride` undefined).
- [ ] **Step 3: Implement** — add `let floorOverride: Int?` (default `nil`, Codable-tolerant: `try container.decodeIfPresent`) to `TrialMovementOption`; add to the `option(...)` builder signature as `floorOverride: Int? = nil`; add on `TrialStation`:

```swift
func resolvedMinimum(forMovementId movementId: String) -> Int {
    movementOptions.first(where: { $0.movementId == movementId })?.floorOverride ?? standard.minimumValue
}
```

Wire the evaluator: where station results compare logged work against `minimumValue`, compare against `resolvedMinimum(forMovementId: <the movement actually performed>)`. The performed movement id is already on the station result path (the evaluator matches logged sets to stations by movement) — find the comparison site via `grep -n "minimumValue" OverallRankTrialService.swift` and thread the performed id through.

- [ ] **Step 4:** Tests PASS, full trial-suite green (`-only-testing` the OverallRankTrial suites; verify the suites actually ran).
- [ ] **Step 5: Commit** — `feat(gates): per-option floor overrides for movement substitutions`.

---

## Task 4: Strength-ratio strike floors `[CLAUDE]`

Heavy strikes (Gates III, VI, VIII) need load floors = tier ratio × bodyweight, resolved from `StrengthStandards` (single source — ratios are NOT copied into TrialStandards).

**Files:**
- Modify: `UNBOUND/Services/Ranking/OverallRankTrialService.swift` (`OverallRankTrialPerformanceStandard`, lines 88–137 region)
- Modify: draft/resolution path (`RankTrialLoadoutResolver.swift` / `OverallRankTrialRunner.swift` — wherever stations become workout prescriptions; locate `loadPercentOfBodyweight` consumers as the template: `grep -rn "loadPercentOfBodyweight" UNBOUND/Services`)
- Test: `UNBOUNDTests/Services/OverallRankTrialServiceTests+Evaluation.swift`

- [ ] **Step 1: Failing test**

```swift
func testStrikeStationResolvesLoadFloorFromStrengthStandards() {
    // Forged-tier hinge ratio comes from StrengthStandards — anchor to the engine,
    // never hardcode the ratio in the test (tests-anchor-to-curve-functions rule).
    let expectedRatio = StrengthStandards.ratio(for: .hinge, tier: .forged)
    let station = OverallRankTrialDefinitions.testStrikeStation(
        id: "t-strike", category: .hingePower, movementId: "exercise.barbell-romanian-deadlift",
        reps: 3, strengthTier: .forged
    )
    let resolved = station.resolvedStrikeLoadKg(bodyweightKg: 80)
    XCTAssertEqual(resolved, expectedRatio * 80, accuracy: 0.5)
}

func testStrikeStationFailsWhenTopSetBelowLoadFloor() {
    // Build a performance log whose 3-rep top set is 5kg under the floor → station fails;
    // at/above the floor → passes. Use the existing evaluation-log fixtures in this file.
}
```

(Adapt the `StrengthStandards.ratio(for:tier:)` call to the actual API — read `UNBOUND/Models/Standards/Movements/*.swift` first; if the lookup is per-movement rather than per-category, key it by the station's `movementId`.)

- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3: Implement** — add `let strengthTier: RankTier?` (default nil) to the station/standard model alongside `loadPercentOfBodyweight`. At draft-resolution time (same place carry loads multiply `bodyweight × percent`), when `strengthTier != nil`, resolve the load floor from `StrengthStandards` for the chosen movement option + bodyweight, and stamp the prescription's target load. In evaluation, a strike station passes when ≥1 qualifying set hits `minimumValue` reps at ≥ the resolved load (mirror how carry-load checking works).
- [ ] **Step 4:** Tests PASS. **Step 5: Commit** — `feat(gates): strength-tier strike floors resolved from StrengthStandards`.

---

## Task 5: Weakest-attribute resolution `[CLAUDE]`

**Files:**
- Modify: `UNBOUND/Services/Ranking/OverallRankTrialRunner.swift` (draft creation — `makeDraft`/`makeStructuredDraft` call path)
- Test: `UNBOUNDTests/Services/OverallRankTrialRunnerTests.swift` (create or extend; locate existing runner tests first)

- [ ] **Step 1: Failing test**

```swift
func testLastGateLanding6ResolvesToWeakestAttributeStation() {
    var scores = AttributeScores.test(all: 70)
    scores.set(.mobility, 32)   // weakest
    let draft = OverallRankTrialRunner.resolveDynamicStations(
        for: OverallRankTrialDefinitions.theLastGate,
        loadout: .homeKit,
        attributeScores: scores
    )
    XCTAssertTrue(draft.contains { $0.id == "lastgate-landing-6-mobility" })
    XCTAssertFalse(draft.contains { $0.id.hasPrefix("lastgate-landing-6-") && !$0.id.hasSuffix("mobility") })
}
```

(Adapt `AttributeScores` construction to the real attribute-score type — find it via `grep -rn "AttributeKey" UNBOUND/Services/Attributes | head`.)

- [ ] **Step 2:** FAIL. **Step 3: Implement** — Gate VIII's definition carries all six landing-6 variants (one per `AttributeKey`, ids `lastgate-landing-6-<attribute>`); a new `resolveDynamicStations(for:loadout:attributeScores:)` hook in the runner filters to the lowest-scoring attribute at draft time (ties: pick the earlier `AttributeKey.allCases` order). Stations for the other five attributes never enter the draft.
- [ ] **Step 4:** PASS. **Step 5: Commit** — `feat(gates): Last Gate landing 6 resolves to weakest attribute`.

---

## Tasks 6–13: The eight gate definitions

Shared mechanics for all eight: in `OverallRankTrialDefinitions.swift`, replace each old builder + definition with the new gate. **Keep the old definition's `id` AND existing `legacyIds` in the new definition's `legacyIds` array** (read them from the current file before deleting), set a new `id` per the table, and re-point `nextTrial(after:)` (line 732) plus the `definition(byId:)` lookups. After each gate: build, run that gate's tests, run `TrialStandardsSnapshotTests`, commit (`feat(gates): Gate N — <name>`). Each gate task includes a test asserting: station count, station ids in order, floors (anchored to `TrialStandards`/engine lookups, never literals), and loadout-variant integrity (every station has ≥1 option per loadout).

**Gate task exemplar — Task 6: Gate I — First Light `[CLAUDE]` (this full pattern is what Codex lanes replicate):**

**Files:** Modify `OverallRankTrialDefinitions.swift` (replace `daily100Stations` + `foundationProof`); Test `UNBOUNDTests/Services/GateDefinitionTests.swift` (create).

- [ ] **Step 1: Failing test**

```swift
final class GateDefinitionTests: XCTestCase {
    func testGate1FirstLightStations() {
        let gate = OverallRankTrialDefinitions.firstLight
        XCTAssertEqual(gate.id, "gate-01-first-light")
        XCTAssertEqual(gate.format, .firstLight)
        XCTAssertEqual(gate.displayName, "First Light")
        XCTAssertEqual(gate.targetRank, .novice)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-novice-awakening"))
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-novice-foundation-proof"))
        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home.map(\.id), [
            "firstlight-path", "firstlight-posts", "firstlight-banner",
            "firstlight-steps", "firstlight-door"
        ])
        XCTAssertEqual(home[3].standard.capSeconds, TrialStandards.FirstLight.stepWindowSeconds)
        XCTAssertEqual(home[4].standard.minimumValue, TrialStandards.FirstLight.trunkHoldSeconds)
    }
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement:**

```swift
private static func firstLightStations(loadout: TrialLoadout) -> [TrialStation] {
    [
        station("firstlight-path", title: "The Path Lantern", category: .lower,
            movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.bodyweight-squat",
            metric: .reps, minimumValue: TrialStandards.FirstLight.lowerReps,
            capSeconds: TrialStandards.FirstLight.stationCapSeconds,
            movementOptions: movementSet(loadout: loadout,
                noGym: option("exercise.bodyweight-squat"),
                home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.bodyweight-squat")],
                gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])])),
        station("firstlight-posts", title: "The Post Lantern", category: .push,
            movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.pushup" : "exercise.incline-pushup",
            metric: .reps, minimumValue: TrialStandards.FirstLight.pushReps,
            capSeconds: TrialStandards.FirstLight.stationCapSeconds,
            movementOptions: movementSet(loadout: loadout,
                noGym: option("exercise.incline-pushup"),
                home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")])),
        station("firstlight-banner", title: "The Banner Lantern", category: .pull,
            movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
            metric: .reps, minimumValue: TrialStandards.FirstLight.pullReps,
            capSeconds: TrialStandards.FirstLight.stationCapSeconds,
            movementOptions: movementSet(loadout: loadout,
                noGym: option("exercise.inverted-row"),
                home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band]), option("exercise.inverted-row")],
                gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
        station("firstlight-steps", title: "The Steps Lantern", category: .engine,
            movementId: "exercise.step-up", metric: .reps,
            minimumValue: TrialStandards.FirstLight.stepReps,
            capSeconds: TrialStandards.FirstLight.stepWindowSeconds,
            movementOptions: [option("exercise.step-up")]),
        station("firstlight-door", title: "The Door Light", category: .carryCore,
            movementId: "exercise.plank", metric: .holdSeconds,
            minimumValue: TrialStandards.FirstLight.trunkHoldSeconds,
            capSeconds: TrialStandards.FirstLight.stationCapSeconds,
            movementOptions: [option("exercise.plank")])
    ]
}

static let firstLight = OverallRankTrialDefinition(
    id: "gate-01-first-light",
    targetRank: .novice,
    displayName: "First Light",
    subtitle: "Rank Gate I — light the courtyard",
    estimatedMinutes: 15,
    format: .firstLight,
    minOverallLevel: 1,
    requiredEquipment: [.bodyweight],
    performanceStandards: firstLightStations(loadout: .homeKit).map(\.standard),
    loadoutVariants: loadoutVariants(
        noGym: firstLightStations(loadout: .noGymField),
        home: firstLightStations(loadout: .homeKit),
        gym: firstLightStations(loadout: .gymHybrid)
    ),
    legacyIds: ["overall-rank-trial-novice-awakening", "overall-rank-trial-novice-foundation-proof"]
)
```

(If `OverallRankTrialDefinition` has no `stations(for:)` accessor, it exists via `loadoutVariants` — check `TrialLoadoutVariant` at `OverallRankTrialService.swift:176-183` and use the real accessor in tests.)

- [ ] **Step 4:** PASS. **Step 5:** Commit.

**Tasks 7–13 — remaining gates `[CODEX-OK after Task 6 merges]`.** Each follows the exemplar exactly: same builder API, same test shape (id/format/name/legacy/station-ids/spot-floor asserts), data from these tables. Movement-option sets per category reuse the current per-loadout sets shown in the existing file (lower/push/pull/hinge/carry/engine/control sets at lines 232–585) unless a row says otherwise.

**Task 7 · Gate II — The Count** (`gate-02-the-count`, format `.theCount`, target `.apprentice`, 20 min, replaces `calibration`/operator builders):
| id | title | category | metric | floor | cap |
|---|---|---|---|---|---|
| count-long-bell | The Long Bell | engine (use `engineStation`) | meters | `TheCount.engineMeters` | `engineCapSeconds` |
| count-second | The Second Count | lower | reps | `lowerReps` | `stationCapSeconds` |
| count-third | The Third Count | push | reps | `pushReps` | `stationCapSeconds` |
| count-fourth | The Fourth Count | pull | reps | `pullReps` | `stationCapSeconds` |
| count-water-carry | The Water Carry | carryCore | meters, `loadPercentOfBodyweight: carryLoadPercent` | `carryMeters` | `carryCapSeconds` |
| count-stillness | Stillness | mobilityControl | holdSeconds | `stillnessHoldSeconds` | `stationCapSeconds` | — in ALL three loadouts (movement `exercise.plank`).

**Task 8 · Gate III — The Forging** (`gate-03-the-forging`, `.theForging`, target `.forged`, 30 min, replaces `forge`/finisher):
| id | title | category | structure |
|---|---|---|---|
| forging-stoke | Stoke the Fire | engine | `engineStation`, `stokeEngineMeters`, unscored (mark `minimumQualifyingSets: 0` if supported; else floor = meters with generous cap — check evaluator semantics first) |
| forging-strike-hinge | The Strikes — Hinge | hingePower | reps-with-load: `plannedSets: 3`, `minimumQualifyingSets: 1`, `minimumValue: scoredStrikeReps`, `strengthTier: .forged` (Task 4); no-gym: `loadPercentOfBodyweight: noGymHingeLoadPercent`, movement `exercise.single-leg-rdl` w/ backpack option |
| forging-strike-push | The Strikes — Push | push | same shape, `strengthTier: .forged`; no-gym scored option `exercise.deficit-pushup` `floorOverride: 3` (tempo/pause coached in copy, not enforced) |
| forging-strike-pull | The Strikes — Pull | pull | `minimumValue: scoredPullReps`, movement `exercise.pullup`; row fallback `floorOverride: 5` (×1.5 of 3, rounded up); no-bar loadout: elevated-row track |
| forging-quench | The Quench | carryCore | meters `quenchCarryMeters`, loaded `loadPercentOfBodyweight` 0.25 noGym / 0.30 loaded |
Verify movement ids exist in the catalog before use: `grep -rn "single-leg-rdl\|deficit-pushup" UNBOUND/Models/MovementCatalog* UNBOUND/Resources` — substitute the catalog's actual ids (e.g. `exercise.dumbbell-romanian-deadlift` single-leg variant) if absent; never invent ids (skill-tiercriteria name-resolution rule).

**Task 9 · Gate IV — Deck of Proof** (`gate-04-deck-of-proof`, `.deckOfProof`, target `.veteran`, 42 min, replaces `reckoning`): keep `deckStations`/`deckRanks`/`deckSuitSpecs` mechanics verbatim; rename ids `deck-card-NN` unchanged; pull suit: pull-up cards at face value + add `floorOverride` = ceil(value × `rowConversionMultiplier`) on the row options (use the Task 3 machinery; write one targeted test: a 10-card pull station resolves row floor 15).

**Task 10 · Gate V — The Ascent** (`gate-05-the-ascent`, `.theAscent`, target `.master`, 50 min, replaces `gauntlet`/tower): stations as current `towerStations` with ids `ascent-floor-01…10`, titles "Floor N — <The Path/The Work Floors/The Cloudline/Thin Air/The Summit Gate>"; floor 4 pull: movement `exercise.pullup` `minimumValue: pullUpReps`, row options `floorOverride: rowFallbackReps`; floor 9 pull blend: `blendPullUpReps`/`blendRowFallbackReps`; floor 10 = Summit Gate boss hold (unchanged floors).

**Task 11 · Gate VI — The Seven Seals** (`gate-06-seven-seals`, `.sevenSeals`, target `.vessel`, 58 min, replaces `crucible`/bossRush): seven stations in this order, each `capSeconds: sealCapSeconds`:
`seals-endurance` (engineStation, `enduranceEngineMeters`) · `seals-vitality` (lower, `vitalityLowerReps`) · `seals-explosiveness` (explosive, `explosivenessReps`, current boss-power movement sets) · `seals-power` (hingePower, `powerStrikeReps` w/ `strengthTier: .vessel`) · `seals-control` (mobilityControl, `controlHoldSeconds` × `controlSets`) · `seals-mobility` (mobilityControl, holdSeconds `mobilityDeepSquatHoldSeconds`, movement `exercise.deep-squat-hold` — verify catalog id; cossack reps live in copy/Plan 2, hold is the scored element) · `seals-spirit` (carryCore, `spiritCarryMeters`, loaded percents).

**Task 12 · Gate VII — The Threshold** (`gate-07-the-threshold`, `.theThreshold`, target `.ascendant`, 65 min, replaces `threshold`/raid): current `raidStations` shapes with ids `threshold-approach`, `threshold-breach-hinge`, `threshold-breach-upper`, `threshold-breach-carry`, `threshold-hold-the-light`; breach-upper pull movement `exercise.pullup` `minimumValue: breachReps` w/ row `floorOverride: 15` (10 × 1.5).

**Task 13 · Gate VIII — The Last Gate** (`gate-08-the-last-gate`, `.theLastGate`, target `.unbound`, 75 min, replaces `ascension`/finalExam): stations `lastgate-landing-1-{path,posts,banner,steps,door}` (FirstLight memory floors, shared `landing1CapSeconds`), `lastgate-landing-2-count` (engineStation 400m, cap `landing2WindowSeconds`), `lastgate-landing-3-strike` (hingePower, `landing3StrikeReps`, `strengthTier: .unbound`), `lastgate-landing-4-hand` (13 cards: reuse deck builder with `deckRanks.prefix` slice dealt across all 4 suits — one card per suit cycling A,2,3…; cap `landing4CapSeconds`), `lastgate-landing-5-{engine,hold}` (500m + 60s), `lastgate-landing-6-<attribute>` ×6 (each attribute's station at SevenSeals floors; runner filters to weakest — Task 5), `lastgate-landing-7-carry` (240m @ percents), `lastgate-summit` (120s hold, cap `summitCapSeconds`).

---

## Task 14: Gate Keys `[CLAUDE]`

**Files:**
- Modify: `OverallRankTrialService.swift:11-15` (`OverallRankTrialRequirementKind` + `.gateKey`)
- Create: `UNBOUND/Services/Ranking/GateKeys.swift`
- Modify: `UNBOUND/Services/Ranking/TrialReadinessService.swift:129-179` (append key lines)
- Test: `UNBOUNDTests/Services/GateKeysTests.swift` (create)

- [ ] **Step 1: Failing tests**

```swift
final class GateKeysTests: XCTestCase {
    func testForgeKeysClearFromHistory() {
        let keys = GateKeys.keys(for: .theForging)
        XCTAssertEqual(keys.map(\.id), ["key-forge-pullups", "key-forge-hinge"])
        // History with a 3-rep strict pull-up set and a 5-rep hinge set at 1.25×bw clears both.
        let history = TrialHistoryFixture.sets([
            .reps("exercise.pullup", reps: 3),
            .loaded("exercise.barbell-romanian-deadlift", reps: 5, loadKg: 100)
        ])
        let cleared = GateKeys.clearedKeys(for: .theForging, history: history, bodyweightKg: 80)
        XCTAssertEqual(cleared, Set(keys.map(\.id)))
    }

    func testKeyLinesAppearInRequirements() {
        // TrialReadinessService.requirementLines includes one .gateKey line per key,
        // isMet mirroring clearedKeys. Use the service's existing test harness/input fixture.
    }
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement** `GateKeys.swift`:

```swift
import Foundation

struct GateKeyDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let label: String          // world language: "3 strict pull-ups, one set"
    let movementIds: [String]  // any match counts
    let metric: GateKeyMetric
}

enum GateKeyMetric: Equatable, Sendable {
    case repsInOneSet(Int)
    case loadedRepsInOneSet(reps: Int, ratioOfBodyweight: Double)
    case holdSeconds(Int)
    case attributeFloor(RankTier)   // every attribute ≥ tier
}

enum GateKeys {
    static func keys(for format: RankTrialFormat) -> [GateKeyDefinition] {
        switch format {
        case .firstLight, .theCount, .deckOfProof: return []   // early gates: LVL+accumulation suffice; deck: capacity is the trial
        case .theForging: return [
            GateKeyDefinition(id: "key-forge-pullups", label: "3 strict pull-ups, one set",
                movementIds: ["exercise.pullup"], metric: .repsInOneSet(3)),
            GateKeyDefinition(id: "key-forge-hinge", label: "Hinge 1.25× bodyweight for 5",
                movementIds: ["exercise.barbell-romanian-deadlift", "exercise.deadlift", "exercise.dumbbell-romanian-deadlift"],
                metric: .loadedRepsInOneSet(reps: 5, ratioOfBodyweight: 1.25))
        ]
        case .theAscent: return [
            GateKeyDefinition(id: "key-ascent-pullups", label: "10 pull-ups, one set",
                movementIds: ["exercise.pullup"], metric: .repsInOneSet(10)),
            GateKeyDefinition(id: "key-ascent-hold", label: "60s unbroken hold",
                movementIds: ["exercise.plank"], metric: .holdSeconds(60))
        ]
        case .sevenSeals: return [
            GateKeyDefinition(id: "key-seals-hexagon", label: "Every attribute at Master floor",
                movementIds: [], metric: .attributeFloor(.master))
        ]
        case .theThreshold: return [
            GateKeyDefinition(id: "key-threshold-carry", label: "Carry 30% bodyweight for 100m",
                movementIds: ["carry.farmer-carry", "carry.loaded-march", "carry.suitcase-carry"],
                metric: .loadedRepsInOneSet(reps: 100, ratioOfBodyweight: 0.30)),   // reps == meters for carries
            GateKeyDefinition(id: "key-threshold-hold", label: "120s unbroken hold",
                movementIds: ["exercise.plank"], metric: .holdSeconds(120))
        ]
        case .theLastGate: return [
            GateKeyDefinition(id: "key-lastgate-stamps", label: "Seven gates answered",
                movementIds: [], metric: .attributeFloor(.ascendant))   // placeholder metric: see step note
        ]
        }
    }

    static func clearedKeys(for format: RankTrialFormat, history: GateKeyHistory, bodyweightKg: Double) -> Set<String> {
        // Walk keys; match by movementIds + metric against history's best single-set records.
        // attributeFloor reads the attribute snapshot on `history`.
        // (Implementation reads the same per-set history store PrereqClearer uses —
        //  mirror its data access; do NOT add a new logging path.)
        Set(keys(for: format).filter { history.satisfies($0, bodyweightKg: bodyweightKg) }.map(\.id))
    }
}
```

Step-note: `key-lastgate-stamps` is "passed gates I–VII" — implement as a check against `OverallRankTrialProgress` passed-attempt records, not `attributeFloor` (replace the metric with a dedicated `case gatesAnswered(Int)` while implementing; the enum above ships with that case instead if cleaner — keep the test updated). Define `GateKeyHistory` as a thin protocol over the existing history/attribute stores (same read path as `PrereqClearer` proofs + attribute scores; locate via `PrereqClearer.swift:41-98`).

Then in `TrialReadinessService.requirementLines`, append after the equipment line:

```swift
for key in GateKeys.keys(for: definition.format) {
    let isMet = input.clearedGateKeys.contains(key.id)
    lines.append(OverallRankTrialRequirementLine(
        id: key.id, kind: .gateKey, label: key.label,
        current: isMet ? "Proven" : "Unproven",
        required: key.label, isMet: isMet
    ))
}
```

(`input.clearedGateKeys: Set<String>` joins `OverallRankTrialReadinessInput`; the call site that builds the input computes it via `GateKeys.clearedKeys` — find the builder via `grep -rn "OverallRankTrialReadinessInput(" UNBOUND`.)

- [ ] **Step 4:** PASS, suites green. **Step 5: Commit** — `feat(gates): Gate Keys — named eligibility proofs auto-cleared from history`.

---

## Task 15: Integration sweep + full gauntlet `[CLAUDE]`

- [ ] **Step 1:** Repo-wide stale-reference sweep (namespace-migration rule): `grep -rn "Daily 100\|Operator Screen\|The Finisher\|Boss Rush\|Threshold Raid\|Final Exam\|foundationProof\|calibration\b\|reckoning\|gauntlet\b\|crucible\|ascension" UNBOUND UNBOUNDTests --include="*.swift"` — update display copy, static property names (`nextTrial(after:)` map), readiness-card strings, demo recorder. New L10n keys get real `Localizable.xcstrings` entries (edit catalog as TEXT).
- [ ] **Step 2:** Full test suite — expect green except intentionally re-baselined snapshots (already updated). Verify each `-only-testing` suite actually ran.
- [ ] **Step 3:** `set -o pipefail; xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO … | grep "BUILD SUCCEEDED"` (device-arch gate; never concurrent xcodebuilds).
- [ ] **Step 4:** Persisted-progress smoke: unit test decoding a legacy attempt blob (old definition id + old format raw) → resolves to the new definition via `legacyIds` + tolerant format decode.
- [ ] **Step 5:** Commit + push checkpoint to jlin with the standard Agent Handoff format.

## Self-review (done at authoring)

- **Spec coverage:** §5 gates → Tasks 6–13; §7 keys → Task 14; movement ladder → Tasks 3, 8, 10, 12; weakest-attribute → Task 5; strikes → Task 4; tolerant migration → Tasks 1, 15; §12 verification → per-task gates + Task 15. UI/§6/§8/§9 deliberately out (Plans 2–4).
- **Checkpoint dependency:** Task 0 blocks Tasks 7–14 only; Tasks 1–6 are checkpoint-independent.
- **Known judgment calls left to implementer:** exact catalog ids for new movements (verify, never invent); evaluator wiring points located by grep (file is 2,400 lines — line numbers drift); `GateKeyMetric.gatesAnswered` shape per step-note.
