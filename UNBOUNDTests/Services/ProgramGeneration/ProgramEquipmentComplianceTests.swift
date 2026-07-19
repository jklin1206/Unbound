import XCTest
@testable import UNBOUND

/// Audits the real generator across every simulation persona: each prescribed
/// exercise must resolve in the catalog and be program-compatible with that
/// persona's training style and equipment. Set UNBOUND_COMPLIANCE_EXPORT to a
/// directory path to also write a JSON summary for reporting.
final class ProgramEquipmentComplianceTests: XCTestCase {
    private struct PersonaComplianceSummary: Codable {
        let personaId: String
        let displayName: String
        let equipment: [String]
        let trainingDaysAudited: Int
        let prescriptionsAudited: Int
        let distinctMovements: Int
        let violations: [String]
    }

    func testYearSimulationRespectsPersonaEquipment() async throws {
        let simulator = BaselineYearProgramSimulator(simulationDays: 365)
        let report = try await simulator.run()

        var summaries: [PersonaComplianceSummary] = []
        for run in report.personaRuns {
            let persona = try XCTUnwrap(
                BaselineYearProgramSimulator.personas.first { $0.id == run.persona.id }
            )
            var violations: [String] = []
            var prescriptions = 0
            var movements: Set<String> = []

            for day in run.days {
                for exercise in day.exercises {
                    prescriptions += 1
                    movements.insert(MovementCatalog.normalized(exercise.name))
                    // Resolve through the full movement identity, not just
                    // canonical exercises — engaged-skill days legitimately
                    // prescribe skill DRILLS (role .skillDrill).
                    let resolved = MovementCatalog.resolvedTrainingMovement(
                        name: exercise.name,
                        movementId: nil,
                        rankStandardMovementId: nil
                    )
                    guard let definition = resolved?.exact ?? resolved?.standard
                            ?? MovementCatalog.canonicalExercise(named: exercise.name) else {
                        violations.append(
                            "day \(day.absoluteDay): '\(exercise.name)' not in catalog"
                        )
                        continue
                    }
                    if !MovementCatalog.isProgramCompatible(
                        definition,
                        style: persona.trainingStyle,
                        userEquipment: persona.equipment
                    ) {
                        violations.append(
                            "day \(day.absoluteDay): '\(exercise.name)' incompatible with \(persona.equipment.map(\.rawValue))"
                        )
                    }
                }
            }

            summaries.append(PersonaComplianceSummary(
                personaId: persona.id,
                displayName: persona.displayName,
                equipment: persona.equipment.map(\.rawValue),
                trainingDaysAudited: run.days.filter { !$0.isRestDay }.count,
                prescriptionsAudited: prescriptions,
                distinctMovements: movements.count,
                violations: violations
            ))
        }

        exportIfRequested(summaries)

        let allViolations = summaries.flatMap { summary in
            summary.violations.map { "\(summary.personaId): \($0)" }
        }
        XCTAssertTrue(
            allViolations.isEmpty,
            "\(allViolations.count) equipment violations:\n" + allViolations.prefix(40).joined(separator: "\n")
        )
    }

    private func exportIfRequested(_ summaries: [PersonaComplianceSummary]) {
        guard let path = ProcessInfo.processInfo.environment["UNBOUND_COMPLIANCE_EXPORT"],
              !path.isEmpty else {
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(summaries) else { return }
        try? data.write(to: URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("equipment-compliance.json"))
    }
}
