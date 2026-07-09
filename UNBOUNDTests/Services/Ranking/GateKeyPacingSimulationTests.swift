import XCTest
@testable import UNBOUND

// MARK: - GateKeyPacingSimulationTests
//
// Data harness, not a pass/fail feature test: models 24 months of realistic
// training for the 7 baseline year-sim personas and reports WHEN each rank
// gate's readiness requirements (level floor, attribute key, movement key)
// actually turn, plus a grid of candidate movementsAtRank(count, rank) keys
// under the current and widened movement pools — so gate keys can be retuned
// against believable timelines.
//
// Modes:
//   - Default (every suite run): fast smoke — 2 personas, 6 months, no
//     artifact writes, sanity assertions only.
//   - UNBOUND_GATEKEY_PACING=1: full 24-month run over all 7 personas,
//     writes CSVs + markdown to LocalArtifacts/gatekey-pacing-<timestamp>
//     (root override: UNBOUND_GATEKEY_PACING_EXPORT_DIR).
final class GateKeyPacingSimulationTests: XCTestCase {

    private static let smokeMonths = 6
    private static let fullMonths = 24

    private static var fullRunEnabled: Bool {
        ProcessInfo.processInfo.environment["UNBOUND_GATEKEY_PACING"] == "1"
    }

    // MARK: Smoke (always on, must stay fast)

    func testGateKeyPacingSmoke() throws {
        let simulator = GateKeyPacingSimulator(horizonMonths: Self.smokeMonths)
        let specs = [
            try XCTUnwrap(GateKeyPacingPersonas.spec(id: "home-bodyweight-beginner")),
            try XCTUnwrap(GateKeyPacingPersonas.spec(id: "full-gym-intermediate"))
        ]
        // Fail fast on a stale exercise key / node id even in normal suite
        // runs — a bad identifier would silently flatline its curve.
        for spec in specs {
            for movement in spec.movements {
                XCTAssertGreaterThanOrEqual(
                    simulator.milestoneAnchorCount(for: movement, spec: spec), 3,
                    "\(spec.id): movement \(movement.kind) resolves too few milestone anchors"
                )
            }
        }

        let results = specs.map(simulator.run)

        XCTAssertEqual(results.count, 2, "smoke should simulate both personas")
        for result in results {
            XCTAssertEqual(result.months.count, Self.smokeMonths)
            assertCurvesMonotone(result)
            XCTAssertEqual(result.gates.count, OverallRankTrialDefinitions.all.count)
        }

        // Calibration: the level curve's own documented anchor — an average
        // 4x/week fully-adherent trainee at ~416 AP/session reaches L90 in
        // ~18 months (OverallLevelCurve calibration comment). If this
        // drifts, the sim's XP accumulation no longer matches the app.
        let l90Month = simulator.monthWhenLevelReached(90, sessionsPerWeek: 4, adherence: 1.0)
        XCTAssertTrue(
            (17...19).contains(l90Month),
            "Calibration broke: 4x/week full-adherence L90 should land month 17-19, got \(l90Month)"
        )

        // Model sanity after the 2026-07-09 retune: a gym intermediate's
        // experience head start still turns "4 @ Master" (now the Seven Seals
        // movement key) almost immediately — expected and by design, that gate
        // paces via its attribute key + L55 floor. The tightened top-gate key
        // (Threshold, 5 @ Vessel) must bind meaningfully LATER than that.
        let gym = try XCTUnwrap(results.first { $0.spec.id == "full-gym-intermediate" })
        let fourAtMaster = try XCTUnwrap(
            gym.candidates.first { $0.pool == "current" && $0.count == 4 && $0.rank == .master }
        )
        XCTAssertLessThanOrEqual(
            fourAtMaster.month, 3,
            "Model sanity: a gym intermediate should turn '4 @ Master (current pool)' within the first months — if not, the experience head start / lift milestones are miscalibrated"
        )
        let thresholdGate = try XCTUnwrap(gym.gates.first { $0.gateId == "gate-07-the-threshold" })
        let thresholdMovementKey = try XCTUnwrap(
            thresholdGate.keyTurns.first { $0.keyId.hasPrefix("key-movements") }
        )
        // An experience head start can put a gym intermediate at Vessel on
        // their staples from day one (imported strength), so both keys may
        // turn the same month for THIS persona. Never earlier is the contract
        // here; the strictly-later property is asserted on from-scratch
        // personas in the full run.
        XCTAssertGreaterThanOrEqual(
            thresholdMovementKey.month, fourAtMaster.month,
            "Retune sanity: the Threshold's 5 @ Vessel key must never bind earlier than the 4 @ Master key it replaced"
        )
    }

    // MARK: Full run (env-gated, writes artifacts)

    func testGateKeyPacingFullRunExportsArtifacts() throws {
        try XCTSkipUnless(Self.fullRunEnabled, "Set UNBOUND_GATEKEY_PACING=1 to run the full 24-month pacing simulation and export artifacts.")

        let tuning = GateKeyPacingTuning.default
        let simulator = GateKeyPacingSimulator(tuning: tuning, horizonMonths: Self.fullMonths)
        let specs = GateKeyPacingPersonas.all
        XCTAssertEqual(specs.count, BaselineYearProgramSimulator.personas.count)

        // Every chosen movement must anchor to at least 3 real milestones
        // (a bad node choice or renamed table entry would silently flatline).
        for spec in specs {
            for movement in spec.movements {
                let anchors = simulator.milestoneAnchorCount(for: movement, spec: spec)
                XCTAssertGreaterThanOrEqual(
                    anchors, 3,
                    "\(spec.id): movement \(movement.kind) resolves only \(anchors) milestone anchors — check the exercise key / node id against the real standards tables"
                )
            }
        }

        let results = specs.map(simulator.run)
        for result in results {
            XCTAssertEqual(result.months.count, Self.fullMonths)
            assertCurvesMonotone(result)
        }

        // Retune check (2026-07-09): the Threshold movement key is now
        // 5 @ Vessel on the widened pool.
        //
        // Experienced personas IMPORT Vessel-level strength via the head
        // start, so both the old and new key can turn at month 1 for them —
        // by design (their real gates are the level floor + the trial). The
        // contract for them: never earlier than the old key, and still
        // achievable by the L72 floor.
        for personaId in ["full-gym-intermediate", "advanced-strength"] {
            let result = try XCTUnwrap(results.first { $0.spec.id == personaId })
            let threshold = try XCTUnwrap(result.gates.first { $0.gateId == "gate-07-the-threshold" })
            let movementKey = try XCTUnwrap(threshold.keyTurns.first { $0.keyId.hasPrefix("key-movements") })
            let oldKey = try XCTUnwrap(
                result.candidates.first { $0.pool == "current" && $0.count == 4 && $0.rank == .master }
            )
            XCTAssertGreaterThanOrEqual(
                movementKey.month, oldKey.month,
                "\(personaId): the retuned 5 @ Vessel key (month \(movementKey.month)) must never bind earlier than the old 4 @ Master key (month \(oldKey.month))"
            )
            XCTAssertLessThanOrEqual(
                movementKey.month, threshold.levelMonth,
                "\(personaId): the 5 @ Vessel key (month \(movementKey.month)) must stay achievable — at latest by the L72 floor (month \(threshold.levelMonth)) for a gym persona"
            )
        }

        // For FROM-SCRATCH personas the retune's whole point must show up:
        // the new key binds strictly later than the old one, and still turns
        // within the 24-month horizon (it tracks, not blocks, their arc).
        for personaId in ["home-bodyweight-beginner", "home-dumbbell-bench"] {
            let result = try XCTUnwrap(results.first { $0.spec.id == personaId })
            let threshold = try XCTUnwrap(result.gates.first { $0.gateId == "gate-07-the-threshold" })
            let movementKey = try XCTUnwrap(threshold.keyTurns.first { $0.keyId.hasPrefix("key-movements") })
            let oldKey = try XCTUnwrap(
                result.candidates.first { $0.pool == "current" && $0.count == 4 && $0.rank == .master }
            )
            XCTAssertGreaterThan(
                movementKey.month, oldKey.month,
                "\(personaId): the retuned 5 @ Vessel key (month \(movementKey.month)) should bind later than the old 4 @ Master key (month \(oldKey.month)) for a from-scratch persona"
            )
            XCTAssertLessThan(
                movementKey.month, tuning.neverMonth,
                "\(personaId): the 5 @ Vessel key must still turn within the horizon for a from-scratch persona"
            )
        }

        let outputURL = try GateKeyPacingArtifactWriter().write(
            results,
            tuning: tuning,
            horizonMonths: Self.fullMonths
        )
        print("UNBOUND_GATEKEY_PACING_OUTPUT=\(outputURL.path)")
        XCTContext.runActivity(named: "Gate-key pacing artifacts") { activity in
            activity.add(XCTAttachment(string: outputURL.path))
        }
    }

    // MARK: Shared assertions

    /// Every emitted curve must be non-decreasing month over month: level,
    /// attribute >=rank counts, and both pools' movement >=rank counts.
    /// (Performance, XP, and tier stores are all monotone in the app.)
    private func assertCurvesMonotone(_ result: PersonaPacingResult, file: StaticString = #filePath, line: UInt = #line) {
        for index in 1..<result.months.count {
            let prev = result.months[index - 1]
            let curr = result.months[index]
            XCTAssertGreaterThanOrEqual(
                curr.level, prev.level,
                "\(result.spec.id): level regressed at month \(curr.month)", file: file, line: line
            )
            for (rank, count) in curr.attributeCounts {
                XCTAssertGreaterThanOrEqual(
                    count, prev.attributeCounts[rank] ?? 0,
                    "\(result.spec.id): attrs >= \(rank.displayName) regressed at month \(curr.month)", file: file, line: line
                )
            }
            for (rank, count) in curr.currentPoolCounts {
                XCTAssertGreaterThanOrEqual(
                    count, prev.currentPoolCounts[rank] ?? 0,
                    "\(result.spec.id): current pool >= \(rank.displayName) regressed at month \(curr.month)", file: file, line: line
                )
            }
            for (rank, count) in curr.widenedPoolCounts {
                XCTAssertGreaterThanOrEqual(
                    count, prev.widenedPoolCounts[rank] ?? 0,
                    "\(result.spec.id): widened pool >= \(rank.displayName) regressed at month \(curr.month)", file: file, line: line
                )
            }
        }
    }
}
