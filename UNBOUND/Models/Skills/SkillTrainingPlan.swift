import Foundation

// MARK: - SkillTrainingPlan
//
// Per-skill training methodology. Surfaced in the SkillSessionView modal
// when the user taps TRAIN on a skill detail page. NOT a skill tree concept —
// these exercises are drills, not milestones.

struct SkillTrainingPlan {
    let skillId: String
    let regressions: [TrainingExercise]      // for users below Lv1 of the skill
    let mainSets: [TrainingPrescription]     // direct training — the bulk of the work
    let accessories: [TrainingExercise]      // supporting strength / mobility / structure
}

struct TrainingExercise: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let cues: [String]              // 1-3 short cues
}

struct TrainingPrescription: Identifiable, Hashable {
    var id: String { exerciseName + "_\(sets)x\(targetDescription)" }
    let exerciseName: String
    let sets: Int
    let target: PrescriptionTarget
    let restSeconds: Int
    let notes: String?              // e.g. "Add weight when 5 strict, RPE 8"
}

enum SkillTrainingRungSource: String, Codable, Hashable, Sendable {
    case regression
    case main
    case accessory
}

enum SkillTrainingAgentReviewOutcome: String, Codable, Hashable, Sendable {
    case promote
    case hold
    case regress
}

struct SkillTrainingAgentReview: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let performanceLogId: String
    let blockId: String
    let userId: String
    let skillId: String
    let skillTitle: String
    let selectedRungId: String?
    let selectedRungSource: SkillTrainingRungSource?
    let reviewedExerciseNames: [String]
    let outcome: SkillTrainingAgentReviewOutcome
    let confidence: Double
    let reason: String
    let completedSets: Int
    let plannedSets: Int
    let cleanSetRatio: Double
    let averageRPE: Double?
    let generatedAt: Date
    let reviewer: String
}

struct SkillTrainingRungDecision: Hashable {
    let targetSkillId: String
    let targetSkillTitle: String
    let selectedRungId: String
    let selectedRungTitle: String
    let source: SkillTrainingRungSource
    let reason: String
    let prescriptions: [TrainingPrescription]
}


enum PrescriptionTarget: Hashable {
    case reps(Int)                                       // "8 reps"
    case repsRange(Int, Int)                             // "5-8 reps"
    case amrap                                           // as many as possible
    case hold(seconds: Int)                              // "30s hold"
    case tempo(reps: Int, eccentric: Int, hold: Int, concentric: Int)  // "5 reps @ 3-1-3"
}

extension TrainingPrescription {
    var targetDescription: String {
        switch target {
        case .reps(let r):                            return "\(r) reps"
        case .repsRange(let lo, let hi):              return "\(lo)–\(hi) reps"
        case .amrap:                                  return "AMRAP"
        case .hold(let s):                            return "\(s)s hold"
        case .tempo(let r, let e, let h, let c):      return "\(r) reps @ \(e)-\(h)-\(c)"
        }
    }
}

// MARK: - SessionLog (persisted)

struct SessionLog: Codable, Identifiable {
    let id: String                  // UUID
    let userId: String
    let skillId: String             // the goal being trained
    var selectedRungId: String? = nil
    var selectedRungSource: SkillTrainingRungSource? = nil
    var selectedRungReason: String? = nil
    let createdAt: Date
    let durationSeconds: Int
    let exercises: [LoggedExercise]
    let xpAwarded: Int
}

struct LoggedExercise: Codable, Hashable {
    let name: String
    let sets: [LoggedSet]
}

struct LoggedSet: Codable, Hashable {
    let reps: Int                   // for reps/amrap/tempo
    let holdSeconds: Int?           // for hold-target sets
    let weightKg: Double?           // optional load
    let rpe: Int?                   // 1-10 perceived effort
    var qualityFlags: Set<PerformanceQualityFlag>? = nil
    var notes: String? = nil

    init(
        reps: Int,
        holdSeconds: Int?,
        weightKg: Double?,
        rpe: Int?,
        qualityFlags: Set<PerformanceQualityFlag> = [],
        notes: String? = nil
    ) {
        self.reps = reps
        self.holdSeconds = holdSeconds
        self.weightKg = weightKg
        self.rpe = rpe
        self.qualityFlags = qualityFlags.isEmpty ? nil : qualityFlags
        self.notes = notes
    }

    var effectiveQualityFlags: Set<PerformanceQualityFlag> {
        qualityFlags ?? []
    }
}
