import XCTest
@testable import UNBOUND

/// Golden floor snapshot over every Overall-Rank-Trial definition.
///
/// Serializes every tunable floor (per-definition: estimatedMinutes,
/// minOverallLevel; per-station: metric, minimumValue, qualifying/planned sets,
/// rest, cap, load%bw) into one deterministic string. This locks the trial
/// floors so the `TrialStandards` extraction can be proven byte-for-byte
/// behavior-neutral: the snapshot must not change.
final class TrialStandardsSnapshotTests: XCTestCase {

    private func snapshot() -> String {
        var lines: [String] = []
        for def in OverallRankTrialDefinitions.all {
            lines.append("DEF \(def.id) rank=\(String(describing: def.targetRank)) "
                + "fmt=\(String(describing: def.format)) min=\(def.estimatedMinutes) "
                + "lvl=\(def.minOverallLevel)")
            for variant in def.loadoutVariants {
                lines.append("  VAR \(String(describing: variant.loadout))")
                for s in variant.stations {
                    let load = s.loadPercentOfBodyweight.map { String(format: "%.3f", $0) } ?? "-"
                    lines.append(
                        "    ST \(s.id) cat=\(String(describing: s.category)) "
                        + "mov=\(s.standard.movementId) metric=\(String(describing: s.standard.metric)) "
                        + "min=\(s.standard.minimumValue) qual=\(s.standard.minimumQualifyingSets) "
                        + "planned=\(s.standard.plannedSets) rest=\(s.standard.restSeconds) "
                        + "cap=\(s.capSeconds.map(String.init) ?? "-") load=\(load)"
                    )
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    func testTrialFloorsMatchGoldenSnapshot() {
        let actual = snapshot()
        // Rebaselined 2026-06-12 for gate-named TrialStandards.
        XCTAssertEqual(actual, Self.golden, "Trial floors changed — update the golden snapshot only for intentional trial changes.")
    }

    private static let golden = """
    DEF gate-01-first-light rank=novice fmt=firstLight min=15 lvl=1
      VAR noGymField
        ST firstlight-path cat=lower mov=exercise.bodyweight-squat metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-posts cat=push mov=exercise.incline-pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-banner cat=pull mov=exercise.inverted-row metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-steps cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=120 load=-
        ST firstlight-door cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=840 load=-
      VAR homeKit
        ST firstlight-path cat=lower mov=exercise.goblet-squat metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-posts cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-banner cat=pull mov=exercise.dumbbell-row metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-steps cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=120 load=-
        ST firstlight-door cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=840 load=-
      VAR gymHybrid
        ST firstlight-path cat=lower mov=exercise.leg-press metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-posts cat=push mov=exercise.machine-chest-press metric=reps min=15 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-banner cat=pull mov=exercise.cable-row-seated metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST firstlight-steps cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=120 load=-
        ST firstlight-door cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=840 load=-
    DEF gate-02-the-count rank=apprentice fmt=theCount min=20 lvl=8
      VAR noGymField
        ST count-long-bell cat=engine mov=cardio.run metric=distanceMeters min=700 qual=1 planned=1 rest=45 cap=360 load=-
        ST count-second cat=lower mov=exercise.step-up metric=reps min=30 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-third cat=push mov=exercise.pushup metric=reps min=18 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-fourth cat=pull mov=exercise.inverted-row metric=reps min=24 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-water-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=80 qual=1 planned=1 rest=75 cap=180 load=0.200
        ST count-stillness cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=120 load=-
      VAR homeKit
        ST count-long-bell cat=engine mov=cardio.run metric=distanceMeters min=700 qual=1 planned=1 rest=45 cap=360 load=-
        ST count-second cat=lower mov=exercise.goblet-squat metric=reps min=30 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-third cat=push mov=exercise.pushup metric=reps min=18 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-fourth cat=pull mov=exercise.dumbbell-row metric=reps min=24 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-water-carry cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=80 qual=1 planned=1 rest=75 cap=180 load=0.200
        ST count-stillness cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=120 load=-
      VAR gymHybrid
        ST count-long-bell cat=engine mov=cardio.row metric=distanceMeters min=804 qual=1 planned=1 rest=45 cap=360 load=-
        ST count-second cat=lower mov=exercise.leg-press metric=reps min=30 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-third cat=push mov=exercise.machine-chest-press metric=reps min=18 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-fourth cat=pull mov=exercise.cable-row-seated metric=reps min=24 qual=1 planned=1 rest=75 cap=120 load=-
        ST count-water-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=80 qual=1 planned=1 rest=75 cap=180 load=0.200
        ST count-stillness cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=120 load=-
    DEF gate-03-the-forging rank=forged fmt=theForging min=30 lvl=15
      VAR noGymField
        ST forging-stoke cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST forging-strike-hinge cat=hingePower mov=exercise.single-leg-rdl metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=0.250
        ST forging-strike-push cat=push mov=exercise.pushup metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-strike-pull cat=pull mov=exercise.inverted-row metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-quench cat=carryCore mov=carry.loaded-march metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=0.250
      VAR homeKit
        ST forging-stoke cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST forging-strike-hinge cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-strike-push cat=push mov=exercise.dumbbell-bench-press metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-strike-pull cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-quench cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=0.300
      VAR gymHybrid
        ST forging-stoke cat=engine mov=cardio.row metric=distanceMeters min=345 qual=1 planned=1 rest=45 cap=- load=-
        ST forging-strike-hinge cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-strike-push cat=push mov=exercise.machine-chest-press metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-strike-pull cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST forging-quench cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=0.300
    DEF gate-04-deck-of-proof rank=veteran fmt=deckOfProof min=42 lvl=22
      VAR noGymField
        ST deck-card-01 cat=push mov=exercise.pushup metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-02 cat=push mov=exercise.pushup metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-03 cat=push mov=exercise.pushup metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-04 cat=push mov=exercise.pushup metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-05 cat=push mov=exercise.pushup metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-06 cat=push mov=exercise.pushup metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-07 cat=push mov=exercise.pushup metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-08 cat=push mov=exercise.pushup metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-09 cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-10 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-11 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-12 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-14 cat=lower mov=exercise.bodyweight-squat metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-15 cat=lower mov=exercise.bodyweight-squat metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-16 cat=lower mov=exercise.bodyweight-squat metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-17 cat=lower mov=exercise.bodyweight-squat metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-18 cat=lower mov=exercise.bodyweight-squat metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-19 cat=lower mov=exercise.bodyweight-squat metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-20 cat=lower mov=exercise.bodyweight-squat metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-21 cat=lower mov=exercise.bodyweight-squat metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-22 cat=lower mov=exercise.bodyweight-squat metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-23 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-24 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-25 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-26 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-27 cat=pull mov=exercise.pullup metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-28 cat=pull mov=exercise.pullup metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-29 cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-30 cat=pull mov=exercise.pullup metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-31 cat=pull mov=exercise.pullup metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-32 cat=pull mov=exercise.pullup metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-33 cat=pull mov=exercise.pullup metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-34 cat=pull mov=exercise.pullup metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-35 cat=pull mov=exercise.pullup metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-36 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-37 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-38 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-39 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-40 cat=carryCore mov=exercise.decline-situp metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-41 cat=carryCore mov=exercise.decline-situp metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-42 cat=carryCore mov=exercise.decline-situp metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-43 cat=carryCore mov=exercise.decline-situp metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-44 cat=carryCore mov=exercise.decline-situp metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-45 cat=carryCore mov=exercise.decline-situp metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-46 cat=carryCore mov=exercise.decline-situp metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-47 cat=carryCore mov=exercise.decline-situp metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-48 cat=carryCore mov=exercise.decline-situp metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-49 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-50 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-51 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-52 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
      VAR homeKit
        ST deck-card-01 cat=push mov=exercise.pushup metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-02 cat=push mov=exercise.pushup metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-03 cat=push mov=exercise.pushup metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-04 cat=push mov=exercise.pushup metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-05 cat=push mov=exercise.pushup metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-06 cat=push mov=exercise.pushup metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-07 cat=push mov=exercise.pushup metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-08 cat=push mov=exercise.pushup metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-09 cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-10 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-11 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-12 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-14 cat=lower mov=exercise.bodyweight-squat metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-15 cat=lower mov=exercise.bodyweight-squat metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-16 cat=lower mov=exercise.bodyweight-squat metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-17 cat=lower mov=exercise.bodyweight-squat metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-18 cat=lower mov=exercise.bodyweight-squat metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-19 cat=lower mov=exercise.bodyweight-squat metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-20 cat=lower mov=exercise.bodyweight-squat metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-21 cat=lower mov=exercise.bodyweight-squat metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-22 cat=lower mov=exercise.bodyweight-squat metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-23 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-24 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-25 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-26 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-27 cat=pull mov=exercise.pullup metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-28 cat=pull mov=exercise.pullup metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-29 cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-30 cat=pull mov=exercise.pullup metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-31 cat=pull mov=exercise.pullup metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-32 cat=pull mov=exercise.pullup metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-33 cat=pull mov=exercise.pullup metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-34 cat=pull mov=exercise.pullup metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-35 cat=pull mov=exercise.pullup metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-36 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-37 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-38 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-39 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-40 cat=carryCore mov=exercise.decline-situp metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-41 cat=carryCore mov=exercise.decline-situp metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-42 cat=carryCore mov=exercise.decline-situp metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-43 cat=carryCore mov=exercise.decline-situp metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-44 cat=carryCore mov=exercise.decline-situp metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-45 cat=carryCore mov=exercise.decline-situp metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-46 cat=carryCore mov=exercise.decline-situp metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-47 cat=carryCore mov=exercise.decline-situp metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-48 cat=carryCore mov=exercise.decline-situp metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-49 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-50 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-51 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-52 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
      VAR gymHybrid
        ST deck-card-01 cat=push mov=exercise.pushup metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-02 cat=push mov=exercise.pushup metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-03 cat=push mov=exercise.pushup metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-04 cat=push mov=exercise.pushup metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-05 cat=push mov=exercise.pushup metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-06 cat=push mov=exercise.pushup metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-07 cat=push mov=exercise.pushup metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-08 cat=push mov=exercise.pushup metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-09 cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-10 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-11 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-12 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-14 cat=lower mov=exercise.bodyweight-squat metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-15 cat=lower mov=exercise.bodyweight-squat metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-16 cat=lower mov=exercise.bodyweight-squat metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-17 cat=lower mov=exercise.bodyweight-squat metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-18 cat=lower mov=exercise.bodyweight-squat metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-19 cat=lower mov=exercise.bodyweight-squat metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-20 cat=lower mov=exercise.bodyweight-squat metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-21 cat=lower mov=exercise.bodyweight-squat metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-22 cat=lower mov=exercise.bodyweight-squat metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-23 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-24 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-25 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-26 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-27 cat=pull mov=exercise.pullup metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-28 cat=pull mov=exercise.pullup metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-29 cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-30 cat=pull mov=exercise.pullup metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-31 cat=pull mov=exercise.pullup metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-32 cat=pull mov=exercise.pullup metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-33 cat=pull mov=exercise.pullup metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-34 cat=pull mov=exercise.pullup metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-35 cat=pull mov=exercise.pullup metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-36 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-37 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-38 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-39 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-40 cat=carryCore mov=exercise.decline-situp metric=reps min=11 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-41 cat=carryCore mov=exercise.decline-situp metric=reps min=2 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-42 cat=carryCore mov=exercise.decline-situp metric=reps min=3 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-43 cat=carryCore mov=exercise.decline-situp metric=reps min=4 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-44 cat=carryCore mov=exercise.decline-situp metric=reps min=5 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-45 cat=carryCore mov=exercise.decline-situp metric=reps min=6 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-46 cat=carryCore mov=exercise.decline-situp metric=reps min=7 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-47 cat=carryCore mov=exercise.decline-situp metric=reps min=8 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-48 cat=carryCore mov=exercise.decline-situp metric=reps min=9 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-49 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-50 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-51 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
        ST deck-card-52 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=- load=-
    DEF gate-05-the-ascent rank=master fmt=theAscent min=50 lvl=40
      VAR noGymField
        ST ascent-floor-01 cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST ascent-floor-02 cat=lower mov=exercise.step-up metric=reps min=24 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-03 cat=push mov=exercise.pushup metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-04 cat=pull mov=exercise.pullup metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-05 cat=hingePower mov=exercise.glute-bridge metric=reps min=30 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-06 cat=carryCore mov=carry.loaded-march metric=distanceMeters min=100 qual=1 planned=1 rest=75 cap=- load=0.100
        ST ascent-floor-07 cat=engine mov=cardio.run metric=distanceMeters min=500 qual=1 planned=1 rest=45 cap=- load=-
        ST ascent-floor-08 cat=explosive mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-09-push cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-09-pull cat=pull mov=exercise.pullup metric=reps min=8 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-10 cat=carryCore mov=exercise.plank metric=holdSeconds min=90 qual=1 planned=1 rest=90 cap=300 load=-
      VAR homeKit
        ST ascent-floor-01 cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST ascent-floor-02 cat=lower mov=exercise.dumbbell-step-up metric=reps min=24 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-03 cat=push mov=exercise.dumbbell-bench-press metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-04 cat=pull mov=exercise.pullup metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-05 cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=30 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-06 cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=100 qual=1 planned=1 rest=75 cap=- load=0.250
        ST ascent-floor-07 cat=engine mov=cardio.run metric=distanceMeters min=500 qual=1 planned=1 rest=45 cap=- load=-
        ST ascent-floor-08 cat=explosive mov=exercise.kettlebell-swing metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-09-push cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-09-pull cat=pull mov=exercise.pullup metric=reps min=8 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-10 cat=carryCore mov=exercise.plank metric=holdSeconds min=90 qual=1 planned=1 rest=90 cap=300 load=-
      VAR gymHybrid
        ST ascent-floor-01 cat=engine mov=cardio.row metric=distanceMeters min=345 qual=1 planned=1 rest=45 cap=- load=-
        ST ascent-floor-02 cat=lower mov=exercise.leg-press metric=reps min=24 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-03 cat=push mov=exercise.machine-chest-press metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-04 cat=pull mov=exercise.pullup metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-05 cat=hingePower mov=exercise.cable-pull-through metric=reps min=30 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-06 cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=100 qual=1 planned=1 rest=75 cap=- load=0.250
        ST ascent-floor-07 cat=engine mov=cardio.row metric=distanceMeters min=575 qual=1 planned=1 rest=45 cap=- load=-
        ST ascent-floor-08 cat=explosive mov=exercise.kettlebell-swing metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-09-push cat=push mov=exercise.machine-chest-press metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-09-pull cat=pull mov=exercise.pullup metric=reps min=8 qual=1 planned=1 rest=75 cap=- load=-
        ST ascent-floor-10 cat=carryCore mov=exercise.plank metric=holdSeconds min=90 qual=1 planned=1 rest=90 cap=300 load=-
    DEF gate-06-seven-seals rank=vessel fmt=sevenSeals min=58 lvl=55
      VAR noGymField
        ST seals-endurance cat=engine mov=cardio.run metric=distanceMeters min=800 qual=1 planned=1 rest=45 cap=360 load=-
        ST seals-vitality cat=lower mov=exercise.step-up metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST seals-explosiveness cat=explosive mov=exercise.glute-bridge metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST seals-power cat=hingePower mov=exercise.single-leg-rdl metric=reps min=3 qual=1 planned=3 rest=75 cap=360 load=0.250
        ST seals-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST seals-mobility cat=mobilityControl mov=mobility.deep-squat-hold metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=360 load=-
        ST seals-spirit cat=carryCore mov=carry.loaded-march metric=distanceMeters min=200 qual=1 planned=1 rest=75 cap=360 load=0.150
      VAR homeKit
        ST seals-endurance cat=engine mov=cardio.run metric=distanceMeters min=800 qual=1 planned=1 rest=45 cap=360 load=-
        ST seals-vitality cat=lower mov=exercise.dumbbell-step-up metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST seals-explosiveness cat=explosive mov=exercise.kettlebell-swing metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST seals-power cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=360 load=-
        ST seals-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST seals-mobility cat=mobilityControl mov=mobility.deep-squat-hold metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=360 load=-
        ST seals-spirit cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=200 qual=1 planned=1 rest=75 cap=360 load=0.300
      VAR gymHybrid
        ST seals-endurance cat=engine mov=cardio.row metric=distanceMeters min=919 qual=1 planned=1 rest=45 cap=360 load=-
        ST seals-vitality cat=lower mov=exercise.leg-press metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST seals-explosiveness cat=explosive mov=exercise.cable-pull-through metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST seals-power cat=hingePower mov=exercise.romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=360 load=-
        ST seals-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST seals-mobility cat=mobilityControl mov=mobility.deep-squat-hold metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=360 load=-
        ST seals-spirit cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=200 qual=1 planned=1 rest=75 cap=360 load=0.300
    DEF gate-07-the-threshold rank=ascendant fmt=theThreshold min=65 lvl=72
      VAR noGymField
        ST threshold-approach cat=engine mov=cardio.run metric=distanceMeters min=400 qual=3 planned=3 rest=45 cap=1080 load=-
        ST threshold-breach-hinge cat=hingePower mov=exercise.glute-bridge metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST threshold-breach-upper cat=pull mov=exercise.pullup metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST threshold-breach-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=60 qual=4 planned=4 rest=75 cap=1920 load=0.150
        ST threshold-hold-the-light cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=900 load=-
      VAR homeKit
        ST threshold-approach cat=engine mov=cardio.run metric=distanceMeters min=400 qual=3 planned=3 rest=45 cap=1080 load=-
        ST threshold-breach-hinge cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST threshold-breach-upper cat=pull mov=exercise.pullup metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST threshold-breach-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=60 qual=4 planned=4 rest=75 cap=1920 load=0.300
        ST threshold-hold-the-light cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=900 load=-
      VAR gymHybrid
        ST threshold-approach cat=engine mov=cardio.row metric=distanceMeters min=459 qual=3 planned=3 rest=45 cap=1080 load=-
        ST threshold-breach-hinge cat=hingePower mov=exercise.cable-pull-through metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST threshold-breach-upper cat=pull mov=exercise.pullup metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST threshold-breach-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=60 qual=4 planned=4 rest=75 cap=1920 load=0.300
        ST threshold-hold-the-light cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=900 load=-
    DEF gate-08-the-last-gate rank=unbound fmt=theLastGate min=75 lvl=90
      VAR noGymField
        ST lastgate-landing-1-path cat=lower mov=exercise.bodyweight-squat metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-posts cat=push mov=exercise.incline-pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-banner cat=pull mov=exercise.inverted-row metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-steps cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-door cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=480 load=-
        ST lastgate-landing-2-count cat=engine mov=cardio.run metric=distanceMeters min=400 qual=1 planned=1 rest=45 cap=150 load=-
        ST lastgate-landing-3-strike cat=hingePower mov=exercise.single-leg-rdl metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=0.300
        ST lastgate-landing-4-card-01 cat=push mov=exercise.pushup metric=reps min=11 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-02 cat=lower mov=exercise.bodyweight-squat metric=reps min=2 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-03 cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-04 cat=carryCore mov=exercise.decline-situp metric=reps min=4 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-05 cat=push mov=exercise.pushup metric=reps min=5 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-06 cat=lower mov=exercise.bodyweight-squat metric=reps min=6 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-07 cat=pull mov=exercise.pullup metric=reps min=7 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-08 cat=carryCore mov=exercise.decline-situp metric=reps min=8 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-09 cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-10 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-11 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-12 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-5-engine cat=engine mov=cardio.run metric=distanceMeters min=500 qual=1 planned=1 rest=45 cap=- load=-
        ST lastgate-landing-5-hold cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=- load=-
        ST lastgate-landing-6-power cat=hingePower mov=exercise.single-leg-rdl metric=reps min=3 qual=1 planned=3 rest=75 cap=360 load=0.250
        ST lastgate-landing-6-vitality cat=lower mov=exercise.step-up metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST lastgate-landing-6-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST lastgate-landing-6-endurance cat=engine mov=cardio.run metric=distanceMeters min=800 qual=1 planned=1 rest=45 cap=360 load=-
        ST lastgate-landing-6-mobility cat=mobilityControl mov=mobility.deep-squat-hold metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=360 load=-
        ST lastgate-landing-6-explosiveness cat=explosive mov=exercise.glute-bridge metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST lastgate-landing-7-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=240 qual=1 planned=1 rest=75 cap=- load=0.200
        ST lastgate-summit cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=600 load=-
      VAR homeKit
        ST lastgate-landing-1-path cat=lower mov=exercise.goblet-squat metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-posts cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-banner cat=pull mov=exercise.dumbbell-row metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-steps cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-door cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=480 load=-
        ST lastgate-landing-2-count cat=engine mov=cardio.run metric=distanceMeters min=400 qual=1 planned=1 rest=45 cap=150 load=-
        ST lastgate-landing-3-strike cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST lastgate-landing-4-card-01 cat=push mov=exercise.pushup metric=reps min=11 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-02 cat=lower mov=exercise.bodyweight-squat metric=reps min=2 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-03 cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-04 cat=carryCore mov=exercise.decline-situp metric=reps min=4 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-05 cat=push mov=exercise.pushup metric=reps min=5 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-06 cat=lower mov=exercise.bodyweight-squat metric=reps min=6 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-07 cat=pull mov=exercise.pullup metric=reps min=7 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-08 cat=carryCore mov=exercise.decline-situp metric=reps min=8 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-09 cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-10 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-11 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-12 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-5-engine cat=engine mov=cardio.run metric=distanceMeters min=500 qual=1 planned=1 rest=45 cap=- load=-
        ST lastgate-landing-5-hold cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=- load=-
        ST lastgate-landing-6-power cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=360 load=-
        ST lastgate-landing-6-vitality cat=lower mov=exercise.dumbbell-step-up metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST lastgate-landing-6-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST lastgate-landing-6-endurance cat=engine mov=cardio.run metric=distanceMeters min=800 qual=1 planned=1 rest=45 cap=360 load=-
        ST lastgate-landing-6-mobility cat=mobilityControl mov=mobility.deep-squat-hold metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=360 load=-
        ST lastgate-landing-6-explosiveness cat=explosive mov=exercise.kettlebell-swing metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST lastgate-landing-7-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=240 qual=1 planned=1 rest=75 cap=- load=0.350
        ST lastgate-summit cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=600 load=-
      VAR gymHybrid
        ST lastgate-landing-1-path cat=lower mov=exercise.leg-press metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-posts cat=push mov=exercise.machine-chest-press metric=reps min=15 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-banner cat=pull mov=exercise.cable-row-seated metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-steps cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=480 load=-
        ST lastgate-landing-1-door cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=480 load=-
        ST lastgate-landing-2-count cat=engine mov=cardio.row metric=distanceMeters min=459 qual=1 planned=1 rest=45 cap=150 load=-
        ST lastgate-landing-3-strike cat=hingePower mov=exercise.romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=- load=-
        ST lastgate-landing-4-card-01 cat=push mov=exercise.pushup metric=reps min=11 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-02 cat=lower mov=exercise.bodyweight-squat metric=reps min=2 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-03 cat=pull mov=exercise.pullup metric=reps min=3 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-04 cat=carryCore mov=exercise.decline-situp metric=reps min=4 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-05 cat=push mov=exercise.pushup metric=reps min=5 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-06 cat=lower mov=exercise.bodyweight-squat metric=reps min=6 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-07 cat=pull mov=exercise.pullup metric=reps min=7 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-08 cat=carryCore mov=exercise.decline-situp metric=reps min=8 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-09 cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-10 cat=lower mov=exercise.bodyweight-squat metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-11 cat=pull mov=exercise.pullup metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-12 cat=carryCore mov=exercise.decline-situp metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-4-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=30 cap=720 load=-
        ST lastgate-landing-5-engine cat=engine mov=cardio.row metric=distanceMeters min=575 qual=1 planned=1 rest=45 cap=- load=-
        ST lastgate-landing-5-hold cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=- load=-
        ST lastgate-landing-6-power cat=hingePower mov=exercise.romanian-deadlift metric=reps min=3 qual=1 planned=3 rest=75 cap=360 load=-
        ST lastgate-landing-6-vitality cat=lower mov=exercise.leg-press metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST lastgate-landing-6-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST lastgate-landing-6-endurance cat=engine mov=cardio.row metric=distanceMeters min=919 qual=1 planned=1 rest=45 cap=360 load=-
        ST lastgate-landing-6-mobility cat=mobilityControl mov=mobility.deep-squat-hold metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=360 load=-
        ST lastgate-landing-6-explosiveness cat=explosive mov=exercise.cable-pull-through metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST lastgate-landing-7-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=240 qual=1 planned=1 rest=75 cap=- load=0.350
        ST lastgate-summit cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=600 load=-
    """
}
