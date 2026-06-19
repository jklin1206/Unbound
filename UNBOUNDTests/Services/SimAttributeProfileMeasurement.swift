import XCTest
@testable import UNBOUND

/// Measurement harness (not a pass/fail test): replays the year-sim's logged
/// sessions through the REAL `AttributeCatalog` (so skill weights + the resolver
/// count, unlike a name-only Python pass) and prints the per-persona attribute
/// profile. Run with the sim export:
///   TEST_RUNNER_UNBOUND_SIM_EXPORT_JSON=<path>.json xcodebuild test \
///     -only-testing:UNBOUNDTests/SimAttributeProfileMeasurement/testPrintAttributeProfiles
/// Caveat: the export carries only strength `mainExercises`, so cardio/carry
/// (vitality's main feed) isn't here — vitality reads low for the same reason.
final class SimAttributeProfileMeasurement: XCTestCase {
    func testProbeSkillResolution() {
        let names = ["tuck planche", "advanced tuck planche", "full planche", "front lever",
                     "tuck front lever", "advanced tuck back lever", "muscle-up", "pistol squat",
                     "german hang", "handstand pushup", "explosive pull-up", "pull-up"]
        for n in names {
            let def = MovementCatalog.resolvedTrainingMovement(name: n)?.exact
            let c = AttributeCatalog.shared.contribution(
                forMovementId: def?.id, rankStandardMovementId: def?.rankStandardMovementId, fallbackExerciseName: n)
            let w = c.weights.map { "\($0.key.rawValue):\(String(format: "%.2f", $0.value))" }.sorted().joined(separator: " ")
            print("PROBE '\(n)' -> id=\(def?.id ?? "NIL") skill=\(def?.skillId ?? "-") weights=[\(w)]")
        }
    }

    func testPrintAttributeProfiles() throws {
        let path = ProcessInfo.processInfo.environment["UNBOUND_SIM_EXPORT_JSON"]
        try XCTSkipUnless(path != nil, "set UNBOUND_SIM_EXPORT_JSON to the year-sim export json")
        let json = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: path!))) as! [String: Any]

        for run in (json["personaRuns"] as? [[String: Any]] ?? []) {
            let pid = ((run["persona"] as? [String: Any])?["id"] as? String) ?? "?"
            var attr: [AttributeKey: Double] = [:]
            var totalAP = 0.0
            for day in (run["days"] as? [[String: Any]] ?? []) {
                if (day["isRestDay"] as? Bool ?? false) || !(day["completed"] as? Bool ?? false) { continue }
                for e in (day["exercises"] as? [[String: Any]] ?? []) {
                    let name = e["name"] as? String ?? ""
                    let sets = e["completedSets"] as? Int ?? 0
                    let reps = e["reps"] as? Int ?? 8
                    guard sets > 0 else { continue }
                    let def = MovementCatalog.resolvedTrainingMovement(name: name)?.exact
                    let value: Double = {
                        if let id = def?.id, id.hasPrefix("cardio.") || id.hasPrefix("carry.") { return 12 }
                        if def?.skillId != nil { return 18 }
                        switch ExerciseClassification.classify(
                            exerciseKey: MovementCatalog.normalized(def?.canonicalExerciseName ?? name)) {
                        case .upperCompound, .lowerCompound, .bodyweightSkill: return 14
                        case .accessory: return 10
                        }
                    }()
                    let ap = Double(sets) * value * log(1 + Double(max(reps, 0)))
                    totalAP += ap
                    let c = AttributeCatalog.shared.contribution(
                        forMovementId: def?.id,
                        rankStandardMovementId: def?.rankStandardMovementId,
                        fallbackExerciseName: name)
                    for (axis, w) in c.weights { attr[axis, default: 0] += ap * w }
                }
            }
            print("SIM_ATTR \(pid)  overallLVL=\(OverallLevelCurve.level(forXP: totalAP))")
            for axis in AttributeKey.allCases {
                let L = AttributeLevelCurve.level(forXP: attr[axis] ?? 0)
                print("SIM_ATTR    \(axis.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0)) L\(L)  \(AttributeLevelCurve.rankTitle(forLevel: L).displayName)")
            }
        }
    }
}
