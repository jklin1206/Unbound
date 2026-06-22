import XCTest
@testable import UNBOUND

/// Guard for the cross-surface rank unification: logging a skill's own movement
/// by its LIBRARY name (not the skill node id) must advance that skill's rank.
/// Stage 1 made advancement live; for most skills the library name already
/// matches the node's criteria, so they advance for free. The few whose library
/// name differs from the criterion name (e.g. "Hollow Hold" vs the criterion
/// "hollow body hold") need an `exerciseSkillTwins` entry. This test sweeps a
/// representative movement per family so a regression — or a new differently
/// named twin — is caught.
@MainActor
final class CrossSurfaceRankAdvanceTests: XCTestCase {

    private let bodyweightKg = 70.0

    private func set(reps: Int = 0, seconds: Int? = nil) -> SetLog {
        SetLog(id: UUID().uuidString, setNumber: 1, weightKg: nil, reps: reps,
               rpe: 8, isWarmup: false, durationSeconds: seconds)
    }

    private func log(name: String, movementId: String?, reps: Int = 0, seconds: Int? = nil) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: "log-\(name)", exerciseName: name, movementId: movementId,
            rankStandardMovementId: movementId ?? name, plannedSets: 1, plannedReps: "—",
            sets: [set(reps: reps, seconds: seconds)], skipped: false, notes: nil
        )
    }

    /// (library display name, skill node id, a strong rep count, a strong hold).
    /// Logged by the LIBRARY name to prove cross-surface advancement — the user
    /// logging the everyday exercise must move the skill rank.
    private let cases: [(name: String, node: String, reps: Int, seconds: Int)] = [
        ("Pull-Up", "pp.pullup", 25, 0),
        ("Chin-Up", "pp.chin-up", 25, 0),
        ("Push-Up", "cal.pushup", 60, 0),
        ("Dip", "cal.5-dips", 30, 0),
        ("Pistol Squat", "ld.pistol-squat", 20, 0),
        ("Bulgarian Split Squat", "ld.bulgarian-split-squat", 25, 0),
        ("Nordic Curl", "ld.nordic-curl", 12, 0),
        ("L-Sit", "cal.l-sit-10", 0, 60),
        ("Plank", "cal.plank-30", 0, 120),
        ("Dead Hang", "pp.dead-hang", 0, 90),
        ("Hollow Hold", "cl.hollow-body-30", 0, 60),
        // Advanced families — logged by their library/drill name.
        ("Tuck Front Lever", "cl.tuck-front-lever", 0, 30),
        ("Tuck Back Lever", "cl.tuck-back-lever", 0, 30),
        ("Tuck Planche", "pl.tuck-planche", 0, 30),
        ("Wall Handstand", "hs.wall-handstand-30", 0, 60),
        ("Dragon Flag", "cl.dragon-flag", 15, 0),
        ("Muscle-Up", "pp.muscle-up", 8, 0)
    ]

    func testLoggingLibraryNameAdvancesEachSkill() throws {
        var failures: [String] = []
        for c in cases {
            guard SkillGraph.shared.node(id: c.node) != nil else {
                failures.append("\(c.node) missing from graph")
                continue
            }
            let entry = log(name: c.name, movementId: nil, reps: c.reps, seconds: c.seconds == 0 ? nil : c.seconds)
            let (advances, state) = RankService.shared.tierAdvances(
                fullHistory: [entry], bodyweightKg: bodyweightKg, priorState: .empty
            )
            let advanced = advances.contains { $0.skillId == c.node }
                && state.tier(for: c.node).rawValue > SkillTier.initiate.rawValue
            if !advanced {
                failures.append("Logging '\(c.name)' did NOT advance \(c.node) (tier \(state.tier(for: c.node)))")
            }
        }
        XCTAssertTrue(
            failures.isEmpty,
            "Cross-surface advancement gaps (each needs an exerciseSkillTwins entry or a name fix):\n"
                + failures.joined(separator: "\n")
        )
    }
}
