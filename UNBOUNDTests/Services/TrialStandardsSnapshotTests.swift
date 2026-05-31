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
        // Captured 2026-05-31, pre-TrialStandards extraction. Must not change.
        XCTAssertEqual(actual, Self.golden, "Trial floors changed — the TrialStandards extraction is not behavior-neutral.")
    }

    private static let golden = """
    DEF overall-rank-trial-novice-awakening rank=novice fmt=daily100 min=14 lvl=1
      VAR noGymField
        ST daily-lower cat=lower mov=exercise.bodyweight-squat metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-push cat=push mov=exercise.incline-pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-pull cat=pull mov=exercise.inverted-row metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-engine cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-trunk cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=840 load=-
      VAR homeKit
        ST daily-lower cat=lower mov=exercise.goblet-squat metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-push cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-pull cat=pull mov=exercise.dumbbell-row metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-engine cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-trunk cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=840 load=-
      VAR gymHybrid
        ST daily-lower cat=lower mov=exercise.leg-press metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-push cat=push mov=exercise.machine-chest-press metric=reps min=15 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-pull cat=pull mov=exercise.cable-row-seated metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-engine cat=engine mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=840 load=-
        ST daily-trunk cat=carryCore mov=exercise.plank metric=holdSeconds min=25 qual=1 planned=1 rest=90 cap=840 load=-
    DEF overall-rank-trial-apprentice-calibration rank=apprentice fmt=operatorScreen min=20 lvl=8
      VAR noGymField
        ST operator-engine cat=engine mov=cardio.run metric=distanceMeters min=700 qual=1 planned=1 rest=45 cap=360 load=-
        ST operator-lower cat=lower mov=exercise.step-up metric=reps min=30 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-push cat=push mov=exercise.pushup metric=reps min=18 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-pull cat=pull mov=exercise.inverted-row metric=reps min=24 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-carry-core cat=carryCore mov=exercise.plank metric=holdSeconds min=60 qual=1 planned=1 rest=90 cap=180 load=-
      VAR homeKit
        ST operator-engine cat=engine mov=cardio.run metric=distanceMeters min=700 qual=1 planned=1 rest=45 cap=360 load=-
        ST operator-lower cat=lower mov=exercise.goblet-squat metric=reps min=30 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-push cat=push mov=exercise.pushup metric=reps min=18 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-pull cat=pull mov=exercise.dumbbell-row metric=reps min=24 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-carry-core cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=80 qual=1 planned=1 rest=75 cap=180 load=0.200
      VAR gymHybrid
        ST operator-engine cat=engine mov=cardio.row metric=distanceMeters min=804 qual=1 planned=1 rest=45 cap=360 load=-
        ST operator-lower cat=lower mov=exercise.leg-press metric=reps min=30 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-push cat=push mov=exercise.machine-chest-press metric=reps min=18 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-pull cat=pull mov=exercise.cable-row-seated metric=reps min=24 qual=1 planned=1 rest=75 cap=120 load=-
        ST operator-carry-core cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=80 qual=1 planned=1 rest=75 cap=180 load=0.200
    DEF overall-rank-trial-forged-forge rank=forged fmt=finisher min=30 lvl=15
      VAR noGymField
        ST finisher-r1-engine cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r1-hinge cat=hingePower mov=exercise.glute-bridge metric=reps min=21 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-push cat=push mov=exercise.pushup metric=reps min=21 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-pull cat=pull mov=exercise.inverted-row metric=reps min=7 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-engine cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r2-hinge cat=hingePower mov=exercise.glute-bridge metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-push cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-pull cat=pull mov=exercise.inverted-row metric=reps min=5 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-engine cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r3-hinge cat=hingePower mov=exercise.glute-bridge metric=reps min=9 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-push cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-pull cat=pull mov=exercise.inverted-row metric=reps min=3 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
      VAR homeKit
        ST finisher-r1-engine cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r1-hinge cat=hingePower mov=exercise.kettlebell-swing metric=reps min=21 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-push cat=push mov=exercise.pushup metric=reps min=21 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-pull cat=pull mov=exercise.dumbbell-row metric=reps min=7 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-carry cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-engine cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r2-hinge cat=hingePower mov=exercise.kettlebell-swing metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-push cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-pull cat=pull mov=exercise.dumbbell-row metric=reps min=5 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-carry cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-engine cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r3-hinge cat=hingePower mov=exercise.kettlebell-swing metric=reps min=9 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-push cat=push mov=exercise.pushup metric=reps min=9 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-pull cat=pull mov=exercise.dumbbell-row metric=reps min=3 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-carry cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
      VAR gymHybrid
        ST finisher-r1-engine cat=engine mov=cardio.row metric=distanceMeters min=345 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r1-hinge cat=hingePower mov=exercise.cable-pull-through metric=reps min=21 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-push cat=push mov=exercise.machine-chest-press metric=reps min=21 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-pull cat=pull mov=exercise.cable-row-seated metric=reps min=7 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r1-carry cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-engine cat=engine mov=cardio.row metric=distanceMeters min=345 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r2-hinge cat=hingePower mov=exercise.cable-pull-through metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-push cat=push mov=exercise.machine-chest-press metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-pull cat=pull mov=exercise.cable-row-seated metric=reps min=5 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r2-carry cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-engine cat=engine mov=cardio.row metric=distanceMeters min=345 qual=1 planned=1 rest=45 cap=- load=-
        ST finisher-r3-hinge cat=hingePower mov=exercise.cable-pull-through metric=reps min=9 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-push cat=push mov=exercise.machine-chest-press metric=reps min=9 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-pull cat=pull mov=exercise.cable-row-seated metric=reps min=3 qual=1 planned=1 rest=75 cap=- load=-
        ST finisher-r3-carry cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=40 qual=1 planned=1 rest=75 cap=- load=-
    DEF overall-rank-trial-veteran-reckoning rank=veteran fmt=fixedDeck min=42 lvl=22
      VAR noGymField
        ST deck-card-01 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-02 cat=lower mov=exercise.step-up metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-03 cat=pull mov=exercise.inverted-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-04 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-05 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-06 cat=lower mov=exercise.step-up metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-07 cat=pull mov=exercise.inverted-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-08 cat=carryCore mov=exercise.plank metric=holdSeconds min=30 qual=1 planned=1 rest=90 cap=- load=-
        ST deck-card-09 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-10 cat=lower mov=exercise.step-up metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-11 cat=pull mov=exercise.inverted-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-12 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-14 cat=lower mov=exercise.step-up metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-15 cat=pull mov=exercise.inverted-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-16 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-17 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-18 cat=lower mov=exercise.step-up metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-19 cat=pull mov=exercise.inverted-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-20 cat=carryCore mov=exercise.plank metric=holdSeconds min=30 qual=1 planned=1 rest=90 cap=- load=-
        ST deck-card-21 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-22 cat=lower mov=exercise.step-up metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-23 cat=pull mov=exercise.inverted-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-24 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
      VAR homeKit
        ST deck-card-01 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-02 cat=lower mov=exercise.goblet-squat metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-03 cat=pull mov=exercise.dumbbell-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-04 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-05 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-06 cat=lower mov=exercise.goblet-squat metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-07 cat=pull mov=exercise.dumbbell-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-08 cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=60 qual=1 planned=1 rest=75 cap=- load=0.200
        ST deck-card-09 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-10 cat=lower mov=exercise.goblet-squat metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-11 cat=pull mov=exercise.dumbbell-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-12 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-13 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-14 cat=lower mov=exercise.goblet-squat metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-15 cat=pull mov=exercise.dumbbell-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-16 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-17 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-18 cat=lower mov=exercise.goblet-squat metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-19 cat=pull mov=exercise.dumbbell-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-20 cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=60 qual=1 planned=1 rest=75 cap=- load=0.200
        ST deck-card-21 cat=push mov=exercise.pushup metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-22 cat=lower mov=exercise.goblet-squat metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-23 cat=pull mov=exercise.dumbbell-row metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-24 cat=engine mov=cardio.run metric=distanceMeters min=200 qual=1 planned=1 rest=45 cap=- load=-
      VAR gymHybrid
        ST deck-card-01 cat=push mov=exercise.machine-chest-press metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-02 cat=lower mov=exercise.leg-press metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-03 cat=pull mov=exercise.cable-row-seated metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-04 cat=engine mov=cardio.row metric=distanceMeters min=229 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-05 cat=push mov=exercise.machine-chest-press metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-06 cat=lower mov=exercise.leg-press metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-07 cat=pull mov=exercise.cable-row-seated metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-08 cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=60 qual=1 planned=1 rest=75 cap=- load=0.200
        ST deck-card-09 cat=push mov=exercise.machine-chest-press metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-10 cat=lower mov=exercise.leg-press metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-11 cat=pull mov=exercise.cable-row-seated metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-12 cat=engine mov=cardio.row metric=distanceMeters min=229 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-13 cat=push mov=exercise.machine-chest-press metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-14 cat=lower mov=exercise.leg-press metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-15 cat=pull mov=exercise.cable-row-seated metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-16 cat=engine mov=cardio.row metric=distanceMeters min=229 qual=1 planned=1 rest=45 cap=- load=-
        ST deck-card-17 cat=push mov=exercise.machine-chest-press metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-18 cat=lower mov=exercise.leg-press metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-19 cat=pull mov=exercise.cable-row-seated metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-20 cat=carryCore mov=carry.suitcase-carry metric=distanceMeters min=60 qual=1 planned=1 rest=75 cap=- load=0.200
        ST deck-card-21 cat=push mov=exercise.machine-chest-press metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-22 cat=lower mov=exercise.leg-press metric=reps min=12 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-23 cat=pull mov=exercise.cable-row-seated metric=reps min=10 qual=1 planned=1 rest=75 cap=- load=-
        ST deck-card-24 cat=engine mov=cardio.row metric=distanceMeters min=229 qual=1 planned=1 rest=45 cap=- load=-
    DEF overall-rank-trial-master-gauntlet rank=master fmt=tower min=50 lvl=40
      VAR noGymField
        ST tower-floor-01 cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST tower-floor-02 cat=lower mov=exercise.step-up metric=reps min=24 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-03 cat=push mov=exercise.pushup metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-04 cat=pull mov=exercise.inverted-row metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-05 cat=hingePower mov=exercise.glute-bridge metric=reps min=30 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-06 cat=carryCore mov=carry.loaded-march metric=distanceMeters min=100 qual=1 planned=1 rest=75 cap=- load=0.100
        ST tower-floor-07 cat=engine mov=cardio.run metric=distanceMeters min=500 qual=1 planned=1 rest=45 cap=- load=-
        ST tower-floor-08 cat=explosive mov=exercise.step-up metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-09-push cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-09-pull cat=pull mov=exercise.inverted-row metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-10 cat=carryCore mov=exercise.plank metric=holdSeconds min=90 qual=1 planned=1 rest=90 cap=300 load=-
      VAR homeKit
        ST tower-floor-01 cat=engine mov=cardio.run metric=distanceMeters min=300 qual=1 planned=1 rest=45 cap=- load=-
        ST tower-floor-02 cat=lower mov=exercise.dumbbell-step-up metric=reps min=24 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-03 cat=push mov=exercise.dumbbell-bench-press metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-04 cat=pull mov=exercise.dumbbell-row metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-05 cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=30 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-06 cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=100 qual=1 planned=1 rest=75 cap=- load=0.250
        ST tower-floor-07 cat=engine mov=cardio.run metric=distanceMeters min=500 qual=1 planned=1 rest=45 cap=- load=-
        ST tower-floor-08 cat=explosive mov=exercise.kettlebell-swing metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-09-push cat=push mov=exercise.pushup metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-09-pull cat=pull mov=exercise.dumbbell-row metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-10 cat=carryCore mov=exercise.plank metric=holdSeconds min=90 qual=1 planned=1 rest=90 cap=300 load=-
      VAR gymHybrid
        ST tower-floor-01 cat=engine mov=cardio.row metric=distanceMeters min=345 qual=1 planned=1 rest=45 cap=- load=-
        ST tower-floor-02 cat=lower mov=exercise.leg-press metric=reps min=24 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-03 cat=push mov=exercise.machine-chest-press metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-04 cat=pull mov=exercise.cable-row-seated metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-05 cat=hingePower mov=exercise.cable-pull-through metric=reps min=30 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-06 cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=100 qual=1 planned=1 rest=75 cap=- load=0.250
        ST tower-floor-07 cat=engine mov=cardio.row metric=distanceMeters min=575 qual=1 planned=1 rest=45 cap=- load=-
        ST tower-floor-08 cat=explosive mov=exercise.kettlebell-swing metric=reps min=20 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-09-push cat=push mov=exercise.machine-chest-press metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-09-pull cat=pull mov=exercise.cable-row-seated metric=reps min=15 qual=1 planned=1 rest=75 cap=- load=-
        ST tower-floor-10 cat=carryCore mov=exercise.plank metric=holdSeconds min=90 qual=1 planned=1 rest=90 cap=300 load=-
    DEF overall-rank-trial-vessel-ten-hundred rank=vessel fmt=bossRush min=58 lvl=55
      VAR noGymField
        ST boss-engine cat=engine mov=cardio.run metric=distanceMeters min=800 qual=1 planned=1 rest=45 cap=360 load=-
        ST boss-lower cat=lower mov=exercise.step-up metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-power cat=hingePower mov=exercise.glute-bridge metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-upper-push cat=push mov=exercise.pushup metric=reps min=16 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-upper-pull cat=pull mov=exercise.inverted-row metric=reps min=16 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST boss-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=200 qual=1 planned=1 rest=75 cap=360 load=0.150
      VAR homeKit
        ST boss-engine cat=engine mov=cardio.run metric=distanceMeters min=800 qual=1 planned=1 rest=45 cap=360 load=-
        ST boss-lower cat=lower mov=exercise.dumbbell-step-up metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-power cat=hingePower mov=exercise.kettlebell-swing metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-upper-push cat=push mov=exercise.pushup metric=reps min=16 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-upper-pull cat=pull mov=exercise.dumbbell-row metric=reps min=16 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST boss-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=200 qual=1 planned=1 rest=75 cap=360 load=0.300
      VAR gymHybrid
        ST boss-engine cat=engine mov=cardio.row metric=distanceMeters min=919 qual=1 planned=1 rest=45 cap=360 load=-
        ST boss-lower cat=lower mov=exercise.leg-press metric=reps min=48 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-power cat=hingePower mov=exercise.cable-pull-through metric=reps min=40 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-upper-push cat=push mov=exercise.machine-chest-press metric=reps min=16 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-upper-pull cat=pull mov=exercise.cable-row-seated metric=reps min=16 qual=1 planned=1 rest=75 cap=360 load=-
        ST boss-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=60 qual=2 planned=2 rest=90 cap=360 load=-
        ST boss-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=200 qual=1 planned=1 rest=75 cap=360 load=0.300
    DEF overall-rank-trial-unbound-threshold rank=unbound fmt=raid min=65 lvl=72
      VAR noGymField
        ST raid-stage-1 cat=engine mov=cardio.run metric=distanceMeters min=400 qual=3 planned=3 rest=45 cap=1080 load=-
        ST raid-stage-2-hinge cat=hingePower mov=exercise.glute-bridge metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST raid-stage-2-upper cat=pull mov=exercise.inverted-row metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST raid-stage-2-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=60 qual=4 planned=4 rest=75 cap=1920 load=0.150
        ST raid-stage-3-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=900 load=-
      VAR homeKit
        ST raid-stage-1 cat=engine mov=cardio.run metric=distanceMeters min=400 qual=3 planned=3 rest=45 cap=1080 load=-
        ST raid-stage-2-hinge cat=hingePower mov=exercise.dumbbell-romanian-deadlift metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST raid-stage-2-upper cat=pull mov=exercise.dumbbell-row metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST raid-stage-2-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=60 qual=4 planned=4 rest=75 cap=1920 load=0.300
        ST raid-stage-3-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=900 load=-
      VAR gymHybrid
        ST raid-stage-1 cat=engine mov=cardio.row metric=distanceMeters min=459 qual=3 planned=3 rest=45 cap=1080 load=-
        ST raid-stage-2-hinge cat=hingePower mov=exercise.cable-pull-through metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST raid-stage-2-upper cat=pull mov=exercise.cable-row-seated metric=reps min=10 qual=4 planned=4 rest=75 cap=1920 load=-
        ST raid-stage-2-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=60 qual=4 planned=4 rest=75 cap=1920 load=0.300
        ST raid-stage-3-control cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=900 load=-
    DEF overall-rank-trial-ascendant-ascension rank=ascendant fmt=finalExam min=75 lvl=90
      VAR noGymField
        ST exam-part-a-explosive cat=explosive mov=exercise.step-up metric=reps min=30 qual=1 planned=1 rest=75 cap=480 load=-
        ST exam-part-b-engine cat=engine mov=cardio.run metric=distanceMeters min=1200 qual=1 planned=1 rest=45 cap=720 load=-
        ST exam-part-c-pull cat=pull mov=exercise.inverted-row metric=reps min=60 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-push cat=push mov=exercise.pushup metric=reps min=60 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-lower cat=lower mov=exercise.step-up metric=reps min=80 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-carry cat=carryCore mov=carry.loaded-march metric=distanceMeters min=240 qual=1 planned=1 rest=75 cap=1800 load=0.200
        ST exam-part-c-trunk cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=1800 load=-
      VAR homeKit
        ST exam-part-a-explosive cat=explosive mov=exercise.kettlebell-swing metric=reps min=30 qual=1 planned=1 rest=75 cap=480 load=-
        ST exam-part-b-engine cat=engine mov=cardio.run metric=distanceMeters min=1200 qual=1 planned=1 rest=45 cap=720 load=-
        ST exam-part-c-pull cat=pull mov=exercise.dumbbell-row metric=reps min=60 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-push cat=push mov=exercise.pushup metric=reps min=60 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-lower cat=lower mov=exercise.goblet-squat metric=reps min=80 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=240 qual=1 planned=1 rest=75 cap=1800 load=0.350
        ST exam-part-c-trunk cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=1800 load=-
      VAR gymHybrid
        ST exam-part-a-explosive cat=explosive mov=exercise.kettlebell-swing metric=reps min=30 qual=1 planned=1 rest=75 cap=480 load=-
        ST exam-part-b-engine cat=engine mov=cardio.row metric=distanceMeters min=1380 qual=1 planned=1 rest=45 cap=720 load=-
        ST exam-part-c-pull cat=pull mov=exercise.cable-row-seated metric=reps min=60 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-push cat=push mov=exercise.machine-chest-press metric=reps min=60 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-lower cat=lower mov=exercise.leg-press metric=reps min=80 qual=1 planned=1 rest=75 cap=1800 load=-
        ST exam-part-c-carry cat=carryCore mov=carry.farmer-carry metric=distanceMeters min=240 qual=1 planned=1 rest=75 cap=1800 load=0.350
        ST exam-part-c-trunk cat=mobilityControl mov=exercise.plank metric=holdSeconds min=120 qual=1 planned=1 rest=90 cap=1800 load=-
    """
}
