import Foundation
import Combine

extension ActiveWorkoutSession {
    struct ProgressSummary: Equatable, Sendable {
        let loggedWorkingSets: Int
        let totalWorkingSets: Int

        var remainingWorkingSets: Int {
            max(0, totalWorkingSets - loggedWorkingSets)
        }

        var isComplete: Bool {
            remainingWorkingSets == 0
        }

        var footerText: String {
            guard totalWorkingSets > 0 else { return "No work sets planned" }
            if isComplete { return "Ready to finish" }
            let setWord = remainingWorkingSets == 1 ? "set" : "sets"
            return "\(loggedWorkingSets)/\(totalWorkingSets) work sets logged · \(remainingWorkingSets) \(setWord) left"
        }
    }

    struct ActiveSet: Identifiable, Codable, Sendable {
        let id: String
        var weightKg: Double?
        var reps: Int?
        var rpe: Int?
        var holdSeconds: Int?
        var durationSeconds: Int?
        var distanceMeters: Int?
        var calories: Int?
        var isWarmup: Bool
        var logged: Bool
        var suggestedWeightKg: Double?
        var suggestedReps: Int?
        var suggestedHoldSeconds: Int?
        var suggestedDurationSeconds: Int?
        var suggestedDistanceMeters: Int?
        var suggestedCalories: Int?
        var suggestedRPE: Int?
        var suggestedRestSeconds: Int?
        var qualityFlags: Set<PerformanceQualityFlag>

        init(id: String, weightKg: Double?, reps: Int?, rpe: Int?,
             isWarmup: Bool, logged: Bool,
             suggestedWeightKg: Double? = nil,
             suggestedReps: Int? = nil,
             holdSeconds: Int? = nil,
             suggestedHoldSeconds: Int? = nil,
             durationSeconds: Int? = nil,
             suggestedDurationSeconds: Int? = nil,
             distanceMeters: Int? = nil,
             suggestedDistanceMeters: Int? = nil,
             calories: Int? = nil,
             suggestedCalories: Int? = nil,
             suggestedRPE: Int? = nil,
             suggestedRestSeconds: Int? = nil,
             qualityFlags: Set<PerformanceQualityFlag> = []) {
            self.id = id; self.weightKg = weightKg; self.reps = reps
            self.rpe = rpe; self.holdSeconds = holdSeconds
            self.durationSeconds = durationSeconds
            self.distanceMeters = distanceMeters
            self.calories = calories
            self.isWarmup = isWarmup; self.logged = logged
            self.suggestedWeightKg = suggestedWeightKg
            self.suggestedReps = suggestedReps
            self.suggestedHoldSeconds = suggestedHoldSeconds
            self.suggestedDurationSeconds = suggestedDurationSeconds
            self.suggestedDistanceMeters = suggestedDistanceMeters
            self.suggestedCalories = suggestedCalories
            self.suggestedRPE = suggestedRPE
            self.suggestedRestSeconds = suggestedRestSeconds
            self.qualityFlags = qualityFlags
        }

        enum CodingKeys: String, CodingKey {
            case id, weightKg, reps, rpe, isWarmup, logged
            case holdSeconds, durationSeconds, distanceMeters, calories
            case suggestedWeightKg, suggestedReps, suggestedHoldSeconds
            case suggestedDurationSeconds, suggestedDistanceMeters, suggestedCalories, suggestedRPE, suggestedRestSeconds, qualityFlags
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
            reps = try c.decodeIfPresent(Int.self, forKey: .reps)
            rpe = try c.decodeIfPresent(Int.self, forKey: .rpe)
            holdSeconds = try c.decodeIfPresent(Int.self, forKey: .holdSeconds)
            durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
            distanceMeters = try c.decodeIfPresent(Int.self, forKey: .distanceMeters)
            calories = try c.decodeIfPresent(Int.self, forKey: .calories)
            isWarmup = try c.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
            logged = try c.decodeIfPresent(Bool.self, forKey: .logged) ?? false
            suggestedWeightKg = try c.decodeIfPresent(Double.self, forKey: .suggestedWeightKg)
            suggestedReps = try c.decodeIfPresent(Int.self, forKey: .suggestedReps)
            suggestedHoldSeconds = try c.decodeIfPresent(Int.self, forKey: .suggestedHoldSeconds)
            suggestedDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .suggestedDurationSeconds)
            suggestedDistanceMeters = try c.decodeIfPresent(Int.self, forKey: .suggestedDistanceMeters)
            suggestedCalories = try c.decodeIfPresent(Int.self, forKey: .suggestedCalories)
            suggestedRPE = try c.decodeIfPresent(Int.self, forKey: .suggestedRPE)
            suggestedRestSeconds = try c.decodeIfPresent(Int.self, forKey: .suggestedRestSeconds)
            qualityFlags = try c.decodeIfPresent(Set<PerformanceQualityFlag>.self, forKey: .qualityFlags) ?? []
        }
    }

    struct ActiveExercise: Identifiable, Codable, Sendable {
        let id: String
        var name: String
        var movementId: String?
        var rankStandardMovementId: String?
        var plannedSets: Int
        var plannedReps: String
        var restSeconds: Int
        var muscleGroups: [MuscleGroup]
        var sets: [ActiveSet]
        var skipped: Bool
        var notes: String
        var targetRPE: Int?
        var formCues: String?
        var substitution: String?
        var blockKind: TrainingBlockKind
        var blockId: String?
        var blockTitle: String?
        var skillId: String?
        var selectedRungId: String?
        var selectedRungSource: SkillTrainingRungSource?
        var selectedRungReason: String?
        var routineId: String?
        var cardioType: CardioType?
        var tracksHold: Bool
        var metricKind: TrainingMetricKind
        var startedAt: Date?
        var completedAt: Date?

        init(id: String, name: String, plannedSets: Int, plannedReps: String,
             restSeconds: Int, muscleGroups: [MuscleGroup], sets: [ActiveSet],
             skipped: Bool, notes: String,
             movementId: String? = nil,
             rankStandardMovementId: String? = nil,
             targetRPE: Int? = nil, formCues: String? = nil,
             substitution: String? = nil,
             blockKind: TrainingBlockKind = .strength,
             blockId: String? = nil,
             blockTitle: String? = nil,
             skillId: String? = nil,
             selectedRungId: String? = nil,
             selectedRungSource: SkillTrainingRungSource? = nil,
             selectedRungReason: String? = nil,
             routineId: String? = nil,
             cardioType: CardioType? = nil,
             tracksHold: Bool = false,
             metricKind: TrainingMetricKind = .reps,
             startedAt: Date? = nil,
             completedAt: Date? = nil) {
            let resolved = MovementResolver.resolve(name)
            self.id = id; self.name = name; self.plannedSets = plannedSets
            self.movementId = movementId ?? resolved.movementId
            self.rankStandardMovementId = rankStandardMovementId ?? resolved.rankStandardMovementId
            self.plannedReps = plannedReps; self.restSeconds = restSeconds
            self.muscleGroups = muscleGroups; self.sets = sets
            self.skipped = skipped; self.notes = notes
            self.targetRPE = targetRPE; self.formCues = formCues
            self.substitution = substitution
            self.blockKind = blockKind
            self.blockId = blockId
            self.blockTitle = blockTitle
            self.skillId = skillId
            self.selectedRungId = selectedRungId
            self.selectedRungSource = selectedRungSource
            self.selectedRungReason = selectedRungReason
            self.routineId = routineId
            self.cardioType = cardioType
            self.tracksHold = tracksHold
            self.metricKind = metricKind
            self.startedAt = startedAt
            self.completedAt = completedAt
        }

        enum CodingKeys: String, CodingKey {
            case id, name, plannedSets, plannedReps, restSeconds
            case muscleGroups, sets, skipped, notes
            case movementId, rankStandardMovementId
            case targetRPE, formCues, substitution
            case blockKind, blockId, blockTitle, skillId, selectedRungId, selectedRungSource, selectedRungReason, routineId, cardioType, tracksHold, metricKind, startedAt, completedAt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            let resolved = MovementResolver.resolve(name)
            movementId = try c.decodeIfPresent(String.self, forKey: .movementId) ?? resolved.movementId
            rankStandardMovementId = try c.decodeIfPresent(String.self, forKey: .rankStandardMovementId) ?? resolved.rankStandardMovementId
            plannedSets = try c.decodeIfPresent(Int.self, forKey: .plannedSets) ?? 0
            plannedReps = try c.decodeIfPresent(String.self, forKey: .plannedReps) ?? ""
            restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 0
            muscleGroups = try c.decodeIfPresent([MuscleGroup].self, forKey: .muscleGroups) ?? []
            sets = try c.decodeIfPresent([ActiveSet].self, forKey: .sets) ?? []
            skipped = try c.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
            notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
            targetRPE = try c.decodeIfPresent(Int.self, forKey: .targetRPE)
            formCues = try c.decodeIfPresent(String.self, forKey: .formCues)
            substitution = try c.decodeIfPresent(String.self, forKey: .substitution)
            blockKind = try c.decodeIfPresent(TrainingBlockKind.self, forKey: .blockKind) ?? .strength
            blockId = try c.decodeIfPresent(String.self, forKey: .blockId)
            blockTitle = try c.decodeIfPresent(String.self, forKey: .blockTitle)
            skillId = try c.decodeIfPresent(String.self, forKey: .skillId)
            selectedRungId = try c.decodeIfPresent(String.self, forKey: .selectedRungId)
            selectedRungSource = try c.decodeIfPresent(SkillTrainingRungSource.self, forKey: .selectedRungSource)
            selectedRungReason = try c.decodeIfPresent(String.self, forKey: .selectedRungReason)
            routineId = try c.decodeIfPresent(String.self, forKey: .routineId)
            cardioType = try c.decodeIfPresent(CardioType.self, forKey: .cardioType)
            tracksHold = try c.decodeIfPresent(Bool.self, forKey: .tracksHold) ?? false
            metricKind = try c.decodeIfPresent(TrainingMetricKind.self, forKey: .metricKind) ?? (tracksHold ? .holdSeconds : .reps)
            startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
            completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        }
    }

    struct Snapshot: Codable, Sendable {
        let id: String
        let programId: String
        let dayNumber: Int
        let plannedWorkoutName: String
        let startedAt: Date
        var source: TrainingSessionSource?
        var exercises: [ActiveExercise]
        var currentExerciseIndex: Int
        var currentSetIndex: Int
    }
}
