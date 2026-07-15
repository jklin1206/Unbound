import XCTest
@testable import UNBOUND

final class YearProgramSimulationTests: XCTestCase {
    func testSimulatorSeedsPerMovementAndReportsHoldSeconds() {
        var tracker = SimulationProgressionTracker(
            userId: "sim-profile",
            experience: .current,
            bodyweightKg: 82
        )
        let curl = Exercise(
            id: "curl",
            name: "Cable Curl",
            muscleGroups: [.arms],
            sets: 3,
            reps: "10 reps",
            restSeconds: 60
        )
        let raise = Exercise(
            id: "raise",
            name: "Dumbbell Lateral Raise",
            muscleGroups: [.shoulders],
            sets: 3,
            reps: "10 reps",
            restSeconds: 60
        )
        let hold = Exercise(
            id: "plank",
            name: "Plank",
            muscleGroups: [.core],
            sets: 3,
            reps: "20s hold",
            restSeconds: 60
        )

        let curlOutcome = tracker.log(
            exercise: curl,
            date: Date(),
            shouldGrind: false,
            shouldUnderperform: false,
            cutModeActive: false
        )
        let raiseOutcome = tracker.log(
            exercise: raise,
            date: Date(),
            shouldGrind: false,
            shouldUnderperform: false,
            cutModeActive: false
        )
        let holdOutcome = tracker.log(
            exercise: hold,
            date: Date(),
            shouldGrind: false,
            shouldUnderperform: false,
            cutModeActive: false
        )

        XCTAssertNotEqual(curlOutcome.weightKg, raiseOutcome.weightKg)
        XCTAssertEqual(holdOutcome.reps, 0)
        XCTAssertEqual(holdOutcome.holdSeconds, 20)
    }

    func testBaselineYearSimulationSmokeExportsDebugArtifacts() async throws {
        try await runYearSimulation(
            personas: [try XCTUnwrap(BaselineYearProgramSimulator.personas.first { $0.id == "home-bodyweight-beginner" })],
            label: "smoke-home-bodyweight-56-days",
            expectedPersonaCount: 1,
            simulationDays: BaselineYearProgramSimulator.smokeSimulationDays
        )
    }

    func testBaselineYearSimulationExportsAllPersonaArtifacts() async throws {
        try XCTSkipUnless(Self.fullYearTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_FULL_YEAR=1 to export the full 365-day all-persona artifact bundle.")
        try await runYearSimulation(
            personas: BaselineYearProgramSimulator.personas,
            label: "all-personas",
            expectedPersonaCount: BaselineYearProgramSimulator.personas.count,
            simulationDays: BaselineYearProgramSimulator.fullYearSimulationDays
        )
    }

    func testBaselineYearSimulationExportsHomeBodyweightBeginnerArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "home-bodyweight-beginner")
    }

    func testBaselineYearSimulationExportsHomeDumbbellBenchArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "home-dumbbell-bench")
    }

    func testBaselineYearSimulationExportsFullGymIntermediateArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "full-gym-intermediate")
    }

    func testBaselineYearSimulationExportsAdvancedStrengthArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "advanced-strength")
    }

    func testBaselineYearSimulationExportsAdvancedCalisthenicsArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "advanced-calisthenics")
    }

    func testBaselineYearSimulationExportsTravelInconsistentArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "travel-inconsistent")
    }

    func testBaselineYearSimulationExportsCutModeHybridArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "cut-mode-hybrid")
    }

    private static var fullYearTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_ENABLE_FULL_YEAR"] == "1"
    }

    private static var shardTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_ENABLE_SHARDS"] == "1"
    }

    private func runYearSimulation(
        personaId: String,
        sourceFile: StaticString = #filePath,
        sourceLine: UInt = #line
    ) async throws {
        executionTimeAllowance = 120

        let persona = try XCTUnwrap(
            BaselineYearProgramSimulator.personas.first { $0.id == personaId },
            file: sourceFile,
            line: sourceLine
        )
        try await runYearSimulation(
            personas: [persona],
            label: personaId,
            expectedPersonaCount: 1,
            sourceFile: sourceFile,
            sourceLine: sourceLine
        )
    }

    private func runYearSimulation(
        personas: [YearSimulationPersona],
        label: String,
        expectedPersonaCount: Int,
        simulationDays: Int = BaselineYearProgramSimulator.fullYearSimulationDays,
        sourceFile: StaticString = #filePath,
        sourceLine: UInt = #line
    ) async throws {
        executionTimeAllowance = expectedPersonaCount > 1 ? 300 : 120

        let report = try await Task.detached(priority: .userInitiated) {
            let simulator = BaselineYearProgramSimulator(personas: personas, simulationDays: simulationDays)
            return try await simulator.run()
        }.value
        let outputURL = try BaselineYearSimulationArtifactWriter().write(report)
        print("UNBOUND_YEAR_SIM_OUTPUT=\(outputURL.path)")

        XCTAssertEqual(report.personaRuns.count, expectedPersonaCount)
        XCTAssertTrue(report.personaRuns.allSatisfy { $0.days.count == simulationDays })
        XCTAssertTrue(report.personaRuns.allSatisfy { !$0.programs.isEmpty })
        if simulationDays >= BaselineYearProgramSimulator.fullYearSimulationDays {
            let criticals = report.personaRuns.flatMap { run in
                run.violations.filter { $0.severity == .critical }
            }
            XCTAssertTrue(
                criticals.isEmpty,
                criticals.map { "\($0.code): \($0.detail)" }.joined(separator: "\n"),
                file: sourceFile,
                line: sourceLine
            )
        }

        await XCTContext.runActivity(named: "UNBOUND year simulation artifacts: \(label)") { activity in
            activity.add(XCTAttachment(string: outputURL.path))
        }
    }
}
