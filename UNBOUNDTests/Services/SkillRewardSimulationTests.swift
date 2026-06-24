import XCTest
@testable import UNBOUND

/// End-to-end simulation of "train these exercises in a program → what ranks up,
/// what reward beats fire, what text shows." Drives the real ProofEngine +
/// RewardPayloadBuilder against the now-generated tier criteria (push/legs/core/
/// handstand/planche), covering every criterion shape the generated ladders use:
/// rep grind, weighted %bw (goblet), hold-seconds, legacy reps-fallback hold,
/// and a floor-gated feat. If any wiring is broken, these fail loudly.
final class SkillRewardSimulationTests: XCTestCase {

    // MARK: - Builders (program-style log)

    private func set(reps: Int = 0, weightKg: Double? = nil, durationSeconds: Int? = nil) -> SetLog {
        SetLog(id: UUID().uuidString, setNumber: 1, weightKg: weightKg, reps: reps,
               rpe: 8, isWarmup: false, durationSeconds: durationSeconds)
    }

    private func entry(_ name: String, node: String, _ sets: [SetLog]) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: "entry-\(node)", exerciseName: name, movementId: nil,
            rankStandardMovementId: node, plannedSets: sets.count, plannedReps: "—",
            sets: sets, skipped: false, notes: nil
        )
    }

    private func log(_ entries: [ExerciseLogEntry]) -> WorkoutLog {
        WorkoutLog(
            id: "sim-\(UUID().uuidString)", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Sim Day", startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1300), exerciseEntries: entries,
            overallNotes: nil, overallRPE: 8, durationMinutes: 30
        )
    }

    private func evaluate(_ entries: [ExerciseLogEntry], bodyweightKg: Double = 70) -> ProofEngineResult {
        ProofEngine.evaluate(log: log(entries), source: .generated, bodyweightKg: bodyweightKg)
    }

    private func clearedTiers(_ r: ProofEngineResult, _ skillId: String) -> [SkillTier] {
        r.standardsCleared.filter { $0.skillId == skillId }.map(\.tier).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - 1. Rep grind (push-up), with name normalization

    func testRepGrindPushupRanksUpAndNormalizesName() {
        // Program logs "Push-Up" (display caps + hyphen) — must resolve to the
        // criterion's "pushup".
        let r = evaluate([entry("Push-Up", node: "cal.pushup", [set(reps: 40)])])
        let cleared = clearedTiers(r, "cal.pushup")

        XCTAssertFalse(cleared.isEmpty, "40 push-ups must clear push-up standards (name normalization)")
        XCTAssertTrue(cleared.contains(.veteran), "40 reps should reach the Veteran rung")
        XCTAssertNotNil(r.multiRankEvent, "clearing several rungs at once fires a rank-advance")
        XCTAssertGreaterThan(r.multiRankEvent?.ranksAdvanced ?? 0, 1)
    }

    // MARK: - 2. Weighted goblet squat (%bw) — the load-based node

    func testWeightedGobletSquatRanksByLoad() {
        // 20 kg held @ 70 kg bw = +28.6% bw → clears the lower %bw rungs.
        let r = evaluate([entry("goblet squat", node: "ld.goblet-20",
                                [set(reps: 12, weightKg: 20)])])
        let cleared = clearedTiers(r, "ld.goblet-20")

        XCTAssertFalse(cleared.isEmpty, "a loaded goblet squat must rank the node by %bw")
        XCTAssertTrue(cleared.contains(.forged), "+28.6% bw should reach the +25% (Forged) rung")
        XCTAssertFalse(cleared.contains(.veteran), "+28.6% bw is below the +30% (Veteran) rung")
    }

    func testBodyweightGobletDoesNotRank() {
        // No weight in hand → no %bw → goblet does not rank (load-based by design).
        let r = evaluate([entry("goblet squat", node: "ld.goblet-20", [set(reps: 20)])])
        XCTAssertTrue(clearedTiers(r, "ld.goblet-20").isEmpty,
                      "an unloaded goblet squat should not clear a load-based ladder")
    }

    // MARK: - 3. Hold-seconds (plank) via the TIME column

    func testHoldSecondsPlankRanksUp() {
        let r = evaluate([entry("plank", node: "cal.plank-30",
                                [set(durationSeconds: 60)])])
        let cleared = clearedTiers(r, "cal.plank-30")
        XCTAssertFalse(cleared.isEmpty, "a 60s plank hold must clear plank standards")
        XCTAssertTrue(cleared.contains(.veteran), "60s should reach the 60s (Veteran) rung")
    }

    // MARK: - 4. Legacy reps-column hold fallback (freestanding handstand)

    func testLegacyRepsFallbackHoldRanksUp() {
        // Older logs encoded hold seconds in `reps` with no durationSeconds.
        let r = evaluate([entry("freestanding handstand", node: "hs.freestanding-hs-30",
                                [set(reps: 30)])])
        XCTAssertFalse(clearedTiers(r, "hs.freestanding-hs-30").isEmpty,
                       "a 30s handstand logged in the reps column must still rank (fallback)")
    }

    // MARK: - 5. Former feats scale on their OWN movement (1 rep = Initiate)

    func testFeatScalesFromInitiateOnItsOwnReps() {
        // cal.handstand-pushup now ranks purely on its own reps: 1 HSPU = Initiate
        // (the entry), more reps climb the same ladder. No first-rep jump to a floor.
        let one = evaluate([entry("handstand pushup", node: "cal.handstand-pushup",
                                  [set(reps: 1)])])
        let clearedOne = clearedTiers(one, "cal.handstand-pushup")
        XCTAssertTrue(clearedOne.contains(.initiate), "the first HSPU earns Initiate")
        XCTAssertFalse(clearedOne.contains(.veteran), "one rep no longer jumps to a floor")

        // A strong set climbs the same scaled ladder well past Veteran.
        let many = evaluate([entry("handstand pushup", node: "cal.handstand-pushup",
                                   [set(reps: 14)])])
        XCTAssertTrue(clearedTiers(many, "cal.handstand-pushup").contains(.veteran),
                      "14 HSPU climbs past Veteran on the scaled ladder")
    }

    // MARK: - 5b. A hold earns a personal best (seconds)

    func testHoldEarnsPersonalBest() {
        let r = evaluate([entry("plank", node: "cal.plank-30", [set(durationSeconds: 75)])])

        let holdBest = r.newBests.first { $0.family == .hold }
        XCTAssertNotNil(holdBest, "a TIME-column hold should produce a personal best")
        XCTAssertEqual(holdBest?.unit, .seconds)
        XCTAssertEqual(holdBest?.value, 75)

        // And it surfaces in the reward beats as a "New best" line when no higher
        // beat (standard/unlock) is present.
        let onlyBest = evaluate([entry("wall handstand", node: "hs.wall-handstand-30",
                                       [set(durationSeconds: 1)])])  // 1s — below every rung, no standard
        let payload = RewardPayloadBuilder.proofPayload(from: onlyBest)
        XCTAssertTrue(payload.beats.contains { $0.kind == .newBest },
                      "a hold with no rank-up still celebrates a new best")
    }

    // MARK: - 6. The reward sequence text the user actually sees

    func testRewardBeatsTextForACombinedProgramWorkout() {
        // A realistic mixed program day: push-ups, a loaded goblet, a plank hold.
        let r = evaluate([
            entry("pushup", node: "cal.pushup", [set(reps: 40)]),
            entry("goblet squat", node: "ld.goblet-20", [set(reps: 12, weightKg: 20)]),
            entry("plank", node: "cal.plank-30", [set(durationSeconds: 60)])
        ])
        let payload = RewardPayloadBuilder.proofPayload(from: r)

        XCTAssertFalse(payload.beats.isEmpty, "a productive program day must produce reward beats")
        // Every standardCleared beat reads "<Tier> cleared" with the skill as subtitle.
        for beat in payload.beats where beat.kind == .standardCleared {
            XCTAssertTrue(beat.title.hasSuffix("cleared"), "beat title: \(beat.title)")
            XCTAssertNotNil(beat.skillId)
            XCTAssertNotNil(beat.tier)
        }
        XCTAssertGreaterThan(payload.tally.standardsCleared, 0)
        XCTAssertTrue(payload.beats.contains { $0.skillId == "cal.pushup" })
        XCTAssertTrue(payload.beats.contains { $0.skillId == "ld.goblet-20" })
        XCTAssertTrue(payload.beats.contains { $0.skillId == "cal.plank-30" })
    }
}
