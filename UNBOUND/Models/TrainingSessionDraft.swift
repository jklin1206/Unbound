import Foundation

enum TrainingSessionSource: String, Codable, Hashable, Sendable {
    case program
    case skill
    case cardio
    case custom
    case routine
    case overallRankTrial
}

enum TrainingBlockKind: String, Codable, CaseIterable, Hashable, Sendable {
    case strength
    case bodyweight
    case skill
    case cardio
    case carry
    case routine
    case custom
}

enum TrainingSide: String, Codable, Hashable, Sendable {
    case left
    case right
    case both
}

enum TrainingMetricKind: String, Codable, Hashable, Sendable {
    case reps
    case holdSeconds
    case durationSeconds
    case distanceMeters
    case calories
}

struct TrainingSessionDraft: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    var source: TrainingSessionSource
    var title: String
    var date: Date
    var estimatedMinutes: Int
    var programId: String?
    var dayNumber: Int?
    var blocks: [TrainingBlock]

    init(
        id: String = UUID().uuidString,
        userId: String,
        source: TrainingSessionSource,
        title: String,
        date: Date = Date(),
        estimatedMinutes: Int,
        programId: String? = nil,
        dayNumber: Int? = nil,
        blocks: [TrainingBlock]
    ) {
        self.id = id
        self.userId = userId
        self.source = source
        self.title = title
        self.date = date
        self.estimatedMinutes = estimatedMinutes
        self.programId = programId
        self.dayNumber = dayNumber
        self.blocks = blocks
    }
}

struct TrainingBlock: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var kind: TrainingBlockKind
    var title: String
    var subtitle: String?
    var skillId: String?
    var routineId: String?
    var cardioType: CardioType?
    var prescriptions: [TrainingBlockPrescription]
    var notes: String?

    init(
        id: String = UUID().uuidString,
        kind: TrainingBlockKind,
        title: String,
        subtitle: String? = nil,
        skillId: String? = nil,
        routineId: String? = nil,
        cardioType: CardioType? = nil,
        prescriptions: [TrainingBlockPrescription],
        notes: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.skillId = skillId
        self.routineId = routineId
        self.cardioType = cardioType
        self.prescriptions = prescriptions
        self.notes = notes
    }
}

struct TrainingBlockPrescription: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var exerciseName: String
    var movementId: String?
    var rankStandardMovementId: String?
    var sets: Int
    var target: TrainingTarget
    var restSeconds: Int
    var muscleGroups: [MuscleGroup]
    var rpe: Int?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        exerciseName: String,
        movementId: String? = nil,
        rankStandardMovementId: String? = nil,
        sets: Int,
        target: TrainingTarget,
        restSeconds: Int,
        muscleGroups: [MuscleGroup] = [],
        rpe: Int? = nil,
        notes: String? = nil
    ) {
        let resolved = MovementResolver.resolve(exerciseName)
        self.id = id
        self.exerciseName = exerciseName
        self.movementId = movementId ?? resolved.movementId
        self.rankStandardMovementId = rankStandardMovementId ?? resolved.rankStandardMovementId
        self.sets = sets
        self.target = target
        self.restSeconds = restSeconds
        self.muscleGroups = muscleGroups
        self.rpe = rpe
        self.notes = notes
    }
}

enum TrainingTarget: Codable, Hashable, Sendable {
    case reps(Int)
    case repsRange(Int, Int)
    case amrap
    case holdSeconds(Int)
    case distanceMeters(Int)
    case calories(Int)
    case timedSeconds(Int)

    var displayText: String {
        switch self {
        case .reps(let count): return "\(count) reps"
        case .repsRange(let low, let high): return "\(low)-\(high) reps"
        case .amrap: return "AMRAP"
        case .holdSeconds(let seconds): return "\(seconds)s hold"
        case .distanceMeters(let meters): return meters >= 1000 ? String(format: "%.1f km", Double(meters) / 1000.0) : "\(meters)m"
        case .calories(let calories): return "\(calories) cal"
        case .timedSeconds(let seconds): return "\(seconds)s"
        }
    }

    var repsLowerBound: Int? {
        switch self {
        case .reps(let count): return count
        case .repsRange(let low, _): return low
        case .amrap, .holdSeconds, .distanceMeters, .calories, .timedSeconds: return nil
        }
    }

    var metricKind: TrainingMetricKind {
        switch self {
        case .reps, .repsRange, .amrap:
            return .reps
        case .holdSeconds:
            return .holdSeconds
        case .distanceMeters:
            return .distanceMeters
        case .calories:
            return .calories
        case .timedSeconds:
            return .durationSeconds
        }
    }

    var metricLowerBound: Int? {
        switch self {
        case .reps(let count):
            return count
        case .repsRange(let low, _):
            return low
        case .holdSeconds(let seconds):
            return seconds
        case .distanceMeters(let meters):
            return meters
        case .calories(let calories):
            return calories
        case .timedSeconds(let seconds):
            return seconds
        case .amrap:
            return nil
        }
    }

    func metricKind(defaultingTo catalogDefault: TrainingMetricKind?) -> TrainingMetricKind {
        switch self {
        case .amrap:
            return catalogDefault ?? .reps
        case .reps, .repsRange, .holdSeconds, .distanceMeters, .calories, .timedSeconds:
            return metricKind
        }
    }
}

extension TrainingTarget {
    init(_ prescriptionTarget: PrescriptionTarget) {
        switch prescriptionTarget {
        case .reps(let count):
            self = .reps(count)
        case .repsRange(let low, let high):
            self = .repsRange(low, high)
        case .amrap:
            self = .amrap
        case .hold(let seconds):
            self = .holdSeconds(seconds)
        case .tempo(let reps, _, _, _):
            self = .reps(reps)
        }
    }
}
