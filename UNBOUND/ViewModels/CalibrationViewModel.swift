import Foundation
import Observation
import SwiftUI
import os.log

enum CalibrationStep: Int, CaseIterable {
    case intro = 0
    case baselines
    case preferences
    case custom
    case complete
}

enum CalibrationPreferenceState: String, Codable, Sendable {
    case none
    case yes
    case substitute
    case avoid

    mutating func advance() {
        switch self {
        case .none: self = .yes
        case .yes: self = .substitute
        case .substitute: self = .avoid
        case .avoid: self = .none
        }
    }
}

struct CalibrationPreferenceRow: Identifiable, Hashable {
    let id: String           // matches CatalogExercise.name (lowercase)
    let displayName: String
    let muscleGroups: [MuscleGroup]
    var state: CalibrationPreferenceState = .none
}

@Observable
@MainActor
final class CalibrationViewModel {
    var currentStep: CalibrationStep = .intro
    var baselines: [CalibrationBaseline] = []
    var preferenceRows: [CalibrationPreferenceRow] = []
    var didAddCustom: Bool = false

    private let userId: String
    private let equipment: Set<Equipment>
    private let experience: Experience?
    private let useMetricWeight: Bool
    private let calibrationService: any CalibrationServiceProtocol
    private let preferenceService: any ExercisePreferenceServiceProtocol
    private let logger = Logger(subsystem: "com.unbound.app", category: "calibration")

    init(
        userId: String,
        equipment: Set<Equipment>,
        experience: Experience?,
        useMetricWeight: Bool,
        calibrationService: any CalibrationServiceProtocol,
        preferenceService: any ExercisePreferenceServiceProtocol
    ) {
        self.userId = userId
        self.equipment = equipment.isEmpty ? [.bodyweight] : equipment
        self.experience = experience
        self.useMetricWeight = useMetricWeight
        self.calibrationService = calibrationService
        self.preferenceService = preferenceService
        self.baselines = generateBaselines()
        self.preferenceRows = generatePreferenceRows()
    }

    // MARK: Navigation

    func advance() {
        let next = currentStep.rawValue + 1
        guard let step = CalibrationStep(rawValue: next) else { return }
        currentStep = step
    }

    func back() {
        let prev = currentStep.rawValue - 1
        guard let step = CalibrationStep(rawValue: prev) else { return }
        currentStep = step
    }

    func jump(to step: CalibrationStep) { currentStep = step }

    // MARK: Binding helpers

    func binding(for baselineID: UUID) -> Binding<CalibrationBaseline>? {
        guard let idx = baselines.firstIndex(where: { $0.id == baselineID }) else { return nil }
        return Binding(
            get: { self.baselines[idx] },
            set: { self.baselines[idx] = $0 }
        )
    }

    func togglePreference(_ rowID: String) {
        guard let idx = preferenceRows.firstIndex(where: { $0.id == rowID }) else { return }
        preferenceRows[idx].state.advance()
    }

    var progressRatio: Double {
        let total = max(1, CalibrationStep.allCases.count - 1)
        return Double(currentStep.rawValue) / Double(total)
    }

    // MARK: Finish

    func finish() async {
        do {
            try await calibrationService.save(baselines, userId: userId)
        } catch {
            logger.error("Failed to persist calibration baselines: \(String(describing: error))")
            calibrationService.markCompleted(userId: userId)
        }

        for row in preferenceRows where row.state != .none {
            let status: ExercisePreferenceStatus
            switch row.state {
            case .yes: status = .available
            case .substitute: status = .substitute
            case .avoid: status = .avoid
            case .none: continue
            }
            let pref = ExercisePreference(
                id: "\(userId):\(row.id)",
                userId: userId,
                exerciseName: row.id,
                displayName: row.displayName,
                status: status,
                muscleGroups: row.muscleGroups,
                substitutePreference: nil,
                notes: nil,
                updatedAt: Date()
            )
            do {
                try await preferenceService.setPreference(pref)
            } catch {
                logger.error("Preference save failed for \(row.id): \(String(describing: error))")
            }
        }
    }

    // MARK: Adaptive baselines

    private var isBodyweightOnly: Bool {
        equipment == [.bodyweight]
    }

    private func generateBaselines() -> [CalibrationBaseline] {
        if isBodyweightOnly {
            return calisthenicBaselines()
        }

        var lifts: [(String, String)] = [
            ("back squat", "Barbell Squat"),
            ("bench press", "Bench Press"),
            ("deadlift", "Deadlift"),
            ("overhead press", "Overhead Press")
        ]
        if equipment.contains(.fullGym) {
            lifts.append(("weighted pullup", "Weighted Pullup"))
        } else {
            return lifts.map { weightBaseline(key: $0.0, name: $0.1) }
                + [repBaseline(key: "pullup", name: "Pullup")]
        }
        return lifts.map { weightBaseline(key: $0.0, name: $0.1) }
    }

    private func calisthenicBaselines() -> [CalibrationBaseline] {
        [
            repBaseline(key: "pushup", name: "Pushup"),
            repBaseline(key: "pullup", name: "Pullup"),
            repBaseline(key: "dip", name: "Dip"),
            repBaseline(key: "pistol squat", name: "Pistol Squat")
        ]
    }

    private func weightBaseline(key: String, name: String) -> CalibrationBaseline {
        let unit = useMetricWeight ? "kg" : "lbs"
        let defaultValue = archetypeDefaultWeight(for: key)
        return CalibrationBaseline(
            userId: userId,
            exerciseKey: key,
            displayName: name,
            kind: .weight,
            value: defaultValue,
            unit: unit,
            isKnown: false
        )
    }

    private func repBaseline(key: String, name: String) -> CalibrationBaseline {
        CalibrationBaseline(
            userId: userId,
            exerciseKey: key,
            displayName: name,
            kind: .reps,
            value: Double(archetypeDefaultReps(for: key)),
            unit: "reps",
            isKnown: false
        )
    }

    private func archetypeDefaultWeight(for key: String) -> Double {
        // Conservative defaults scaled to experience. Keep in native unit.
        let isBeginner = experience == .never || experience == .tried
        let imperial = !useMetricWeight
        switch key {
        case "back squat", "front squat":
            return imperial ? (isBeginner ? 95 : 135) : (isBeginner ? 40 : 60)
        case "bench press":
            return imperial ? (isBeginner ? 75 : 115) : (isBeginner ? 35 : 50)
        case "deadlift":
            return imperial ? (isBeginner ? 115 : 155) : (isBeginner ? 50 : 70)
        case "overhead press":
            return imperial ? (isBeginner ? 45 : 75) : (isBeginner ? 20 : 35)
        case "incline dumbbell press":
            return imperial ? (isBeginner ? 25 : 40) : (isBeginner ? 12 : 18)
        case "weighted pullup":
            return imperial ? (isBeginner ? 0 : 25) : (isBeginner ? 0 : 10)
        default:
            return imperial ? 45 : 20
        }
    }

    private func archetypeDefaultReps(for key: String) -> Int {
        let isBeginner = experience == .never || experience == .tried
        switch key {
        case "pushup":        return isBeginner ? 8 : 20
        case "pullup":        return isBeginner ? 0 : 5
        case "dip":           return isBeginner ? 2 : 8
        case "pistol squat":  return isBeginner ? 0 : 3
        default:              return 5
        }
    }

    // MARK: Adaptive preferences

    private func generatePreferenceRows() -> [CalibrationPreferenceRow] {
        let useCalisthenic = isBodyweightOnly

        let universal: [(String, String, [MuscleGroup])] = [
            ("bench press", "Bench Press", [.chest, .shoulders, .arms]),
            ("overhead press", "Overhead Press", [.shoulders, .arms]),
            ("lateral raise", "Lateral Raise", [.shoulders]),
            ("bent-over row", "Bent-over Row", [.back, .lats])
        ]

        let barbell: [(String, String, [MuscleGroup])] = [
            ("back squat", "Barbell Squat", [.legs, .glutes]),
            ("deadlift", "Deadlift", [.back, .legs, .glutes]),
            ("romanian deadlift", "Romanian Deadlift", [.legs, .glutes, .back]),
            ("front squat", "Front Squat", [.legs, .glutes, .core]),
            ("chin-up", "Chin-up", [.back, .lats, .arms]),
            ("face pull", "Face Pull", [.shoulders, .back])
        ]

        let calisthenic: [(String, String, [MuscleGroup])] = [
            ("pushup", "Pushup", [.chest, .shoulders, .arms]),
            ("pullup", "Pullup", [.back, .lats, .arms]),
            ("dip", "Dip", [.chest, .shoulders, .arms]),
            ("l-sit progression", "L-Sit", [.core, .shoulders]),
            ("dragon flag", "Dragon Flag", [.core]),
            ("hollow rock", "Hollow Rock", [.core]),
            ("pistol squat", "Pistol Squat", [.legs, .glutes, .core]),
            ("hanging leg raise", "Hanging Leg Raise", [.core]),
            ("bulgarian split squat", "Bulgarian Split Squat", [.legs, .glutes])
        ]

        let additions: [(String, String, [MuscleGroup])]
        if useCalisthenic {
            additions = calisthenic
        } else {
            additions = barbell + calisthenic.prefix(3)
        }

        let combined = universal + additions
        var seen = Set<String>()
        return combined.compactMap { key, name, groups in
            guard seen.insert(key).inserted else { return nil }
            return CalibrationPreferenceRow(id: key, displayName: name, muscleGroups: groups)
        }
    }
}
