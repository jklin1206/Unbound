// UNBOUND/Models/Standards/Gates/TrialStandards.swift
import Foundation

// MARK: - Overall-rank trial floor standards
//
// Gate-named performance floors for every Overall-Rank Trial. The definition
// builders still own loadout branching and assembly; this file owns only the
// tunable difficulty numbers they read.

enum TrialStandards {
    /// Gate I — First Light (Initiate → Novice, .firstLight)
    enum FirstLight {
        static let lowerReps = 20
        static let pushReps = 15
        static let pullReps = 20
        static let stepReps = 20
        static let stepWindowSeconds = 120
        static let trunkHoldSeconds = 25
        static let stationCapSeconds = 14 * 60
    }

    /// Gate II — The Count (Novice → Apprentice, .theCount)
    enum TheCount {
        static let engineMeters = 700
        static let engineCapSeconds = 6 * 60
        static let cadenceSecondsPerRep = 4
        static let lowerReps = 30
        static let pushReps = 18
        static let pullReps = 24
        static let stationCapSeconds = 2 * 60
        static let carryMeters = 80
        static let carryCapSeconds = 3 * 60
        static let carryLoadPercent = 0.20
        static let stillnessHoldSeconds = 60
    }

    /// Gate III — The Forging (Apprentice → Forged, .theForging)
    enum TheForging {
        static let stokeEngineMeters = 300
        static let strikeReps = [8, 5, 3]
        static let scoredStrikeReps = 3
        static let noGymHingeLoadPercent = 0.25
        static let scoredPullReps = 3
        static let quenchCarryMeters = 40
    }

    /// Gate IV — Deck of Proof (Forged → Veteran, .deckOfProof)
    enum DeckOfProof {
        static let aceReps = 11
        static let faceCardReps = 10
        static let restSeconds = 30
        static let rowConversionMultiplier = 1.5
    }

    /// Gate V — The Ascent (Veteran → Master, .theAscent)
    enum TheAscent {
        static let floor1Meters = 300
        static let lowerReps = 24
        static let pushReps = 20
        static let pullUpReps = 12
        static let rowFallbackReps = 18
        static let hingeReps = 30
        static let carryMeters = 100
        static let carryLoadPercentNoGym = 0.10
        static let carryLoadPercentLoaded = 0.25
        static let longEngineMeters = 500
        static let explosiveReps = 20
        static let blendPushReps = 15
        static let blendPullUpReps = 8
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
        static let powerStrikeReps = 3
        static let controlHoldSeconds = 60
        static let controlSets = 2
        static let mobilityDeepSquatHoldSeconds = 60
        static let mobilityCossackRepsPerSide = 10
        static let spiritCarryMeters = 200
        static let spiritCarryLoadPercentNoGym = 0.15
        static let spiritCarryLoadPercentLoaded = 0.30

        @available(*, deprecated, message: "TEMP shim")
        static let stationCapSeconds = sealCapSeconds // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let engineMeters = enduranceEngineMeters // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let lowerReps = vitalityLowerReps // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let powerReps = explosivenessReps // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let pushReps = 16 // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let pullReps = 16 // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let carryMeters = spiritCarryMeters // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let carryLoadPercentNoGym = spiritCarryLoadPercentNoGym // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let carryLoadPercentLoaded = spiritCarryLoadPercentLoaded // TEMP shim
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

        @available(*, deprecated, message: "TEMP shim")
        static let engineMeters = approachEngineMeters // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let engineSets = approachSets // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let engineCapSeconds = approachCapSeconds // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let workReps = breachReps // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let workSets = breachSets // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let workCapSeconds = breachCapSeconds // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let carryMeters = breachCarryMeters // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let controlHoldSeconds = holdTheLightSeconds // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let controlSets = holdSets // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let controlCapSeconds = holdCapSeconds // TEMP shim
    }

    /// Gate VIII — The Last Gate (Ascendant → Unbound, .theLastGate)
    enum TheLastGate {
        static let landing1LowerReps = 20
        static let landing1PushReps = 15
        static let landing1PullReps = 20
        static let landing1StepReps = 20
        static let landing1HoldSeconds = 25
        static let landing1CapSeconds = 8 * 60
        static let landing2EngineMeters = 400
        static let landing2WindowSeconds = 150
        static let landing3StrikeReps = 3
        static let landing4CardCount = 13
        static let landing4CapSeconds = 12 * 60
        static let landing5EngineMeters = 500
        static let landing5HoldSeconds = 60
        static let landing7CarryMeters = 240
        static let landing7CarryLoadPercentNoGym = 0.20
        static let landing7CarryLoadPercentLoaded = 0.35
        static let summitHoldSeconds = 120
        static let summitCapSeconds = 10 * 60

        @available(*, deprecated, message: "TEMP shim")
        static let explosiveReps = landing1StepReps // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let explosiveCapSeconds = landing1CapSeconds // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let engineMeters = landing2EngineMeters // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let engineCapSeconds = landing2WindowSeconds // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let pullReps = landing1PullReps // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let pushReps = landing1PushReps // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let lowerReps = landing1LowerReps // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let volumeCapSeconds = landing4CapSeconds // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let carryMeters = landing7CarryMeters // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let carryLoadPercentNoGym = landing7CarryLoadPercentNoGym // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let carryLoadPercentLoaded = landing7CarryLoadPercentLoaded // TEMP shim
        @available(*, deprecated, message: "TEMP shim")
        static let trunkHoldSeconds = summitHoldSeconds // TEMP shim
    }
}

// TEMPORARY shims — removed as gate definitions are rewritten (Plan Tasks 6–13).
extension TrialStandards {
    @available(*, deprecated, message: "TEMP shim")
    typealias BossRush = SevenSeals // TEMP shim
    @available(*, deprecated, message: "TEMP shim")
    typealias Raid = TheThreshold // TEMP shim
    @available(*, deprecated, message: "TEMP shim")
    typealias FinalExam = TheLastGate // TEMP shim
}
