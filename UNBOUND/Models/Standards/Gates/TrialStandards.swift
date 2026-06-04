// UNBOUND/Models/Standards/Gates/TrialStandards.swift
import Foundation

// MARK: - Overall-rank trial floor standards
//
// The per-station performance floors for every Overall-Rank Trial, pulled out of
// OverallRankTrialService's builders (audit Q2) so the tunable difficulty knobs
// — reps, hold seconds, run/carry meters, %bw carry loads, time caps, qualifying
// sets — live in one place. The builders still own HOW each trial is assembled
// (loadout branching, the descending-rounds math, the deck loop, the ×1.15 row
// conversion in `engineMovement`); this owns only the seed numbers they read.
//
// One enum per trial, named for the trial. Loaded-loadout carries use a higher
// %bw than no-gym backpack carries. `TrialStandardsSnapshotTests` locks every
// resolved floor so changes here are intentional.

enum TrialStandards {

    /// Daily 100 — Initiate → Novice (`foundationProof`, daily100).
    enum Daily100 {
        static let lowerReps = 20
        static let pushReps = 15
        static let pullReps = 20
        static let engineReps = 20
        static let trunkHoldSeconds = 25
        static let stationCapSeconds = 14 * 60
    }

    /// Operator Screen — Novice → Apprentice (`calibration`, operatorScreen).
    enum OperatorScreen {
        static let engineMeters = 700
        static let engineCapSeconds = 6 * 60
        static let lowerReps = 30
        static let pushReps = 18
        static let pullReps = 24
        static let stationCapSeconds = 2 * 60
        static let coreHoldSeconds = 60          // no-gym plank
        static let carryMeters = 80              // loaded suitcase carry
        static let carryCapSeconds = 3 * 60
        static let carryLoadPercent = 0.20
    }

    /// The Finisher — Apprentice → Forged (`forge`, finisher).
    /// Three descending rounds; hinge/push use the round rep, pull uses
    /// `max(3, round / 3)`.
    enum Finisher {
        static let roundReps = [21, 15, 9]
        static let engineMeters = 300
        static let carryMeters = 40
    }

    /// Deck of Proof — Forged → Veteran (`reckoning`, fixedDeck).
    enum DeckOfProof {
        static let aceReps = 11
        static let faceCardReps = 10
        static let restSeconds = 30
    }

    /// The Tower — Veteran → Master (`gauntlet`, tower).
    enum Tower {
        static let floor1Meters = 300
        static let lowerReps = 24
        static let pushReps = 20
        static let pullReps = 20
        static let hingeReps = 30
        static let carryMeters = 100
        static let carryLoadPercentNoGym = 0.10
        static let carryLoadPercentLoaded = 0.25
        static let longEngineMeters = 500
        static let explosiveReps = 20
        static let blendPushReps = 15
        static let blendPullReps = 15
        static let bossHoldSeconds = 90
        static let bossHoldCapSeconds = 5 * 60
    }

    /// Boss Rush — Master → Vessel (`crucible`, bossRush). Every station is
    /// capped at the same 6-minute boss clock.
    enum BossRush {
        static let engineMeters = 800
        static let stationCapSeconds = 6 * 60
        static let lowerReps = 48
        static let powerReps = 40
        static let pushReps = 16
        static let pullReps = 16
        static let controlHoldSeconds = 60
        static let controlSets = 2
        static let carryMeters = 200
        static let carryLoadPercentNoGym = 0.15
        static let carryLoadPercentLoaded = 0.30
    }

    /// Threshold Raid — Vessel → Unbound (`threshold`, raid).
    enum Raid {
        static let engineMeters = 400
        static let engineSets = 3
        static let engineCapSeconds = 18 * 60
        static let workReps = 10                 // hinge / upper / carry
        static let workSets = 4
        static let workCapSeconds = 32 * 60
        static let carryMeters = 60
        static let carryLoadPercentNoGym = 0.15
        static let carryLoadPercentLoaded = 0.30
        static let controlHoldSeconds = 120
        static let controlSets = 1
        static let controlCapSeconds = 15 * 60
    }

    /// Final Exam — Unbound → Ascendant (`ascension`, finalExam).
    enum FinalExam {
        static let explosiveReps = 30
        static let explosiveCapSeconds = 8 * 60
        static let engineMeters = 1200
        static let engineCapSeconds = 12 * 60
        static let pullReps = 60
        static let pushReps = 60
        static let lowerReps = 80
        static let volumeCapSeconds = 30 * 60
        static let carryMeters = 240
        static let carryLoadPercentNoGym = 0.20
        static let carryLoadPercentLoaded = 0.35
        static let trunkHoldSeconds = 120
    }
}
