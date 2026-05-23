import Foundation

struct PerformanceLog: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    var draftId: String?
    var source: TrainingSessionSource
    var title: String
    var startedAt: Date
    var completedAt: Date
    var programId: String?
    var dayNumber: Int?
    var blocks: [PerformanceBlock]
    var overallRPE: Int?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        userId: String,
        draftId: String? = nil,
        source: TrainingSessionSource,
        title: String,
        startedAt: Date,
        completedAt: Date = Date(),
        programId: String? = nil,
        dayNumber: Int? = nil,
        blocks: [PerformanceBlock],
        overallRPE: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.draftId = draftId
        self.source = source
        self.title = title
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.programId = programId
        self.dayNumber = dayNumber
        self.blocks = blocks
        self.overallRPE = overallRPE
        self.notes = notes
    }
}

struct PerformanceBlock: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var kind: TrainingBlockKind
    var title: String
    var skillId: String?
    var routineId: String?
    var cardioType: CardioType?
    var exercises: [PerformanceExercise]
    var durationSeconds: Int?
    var distanceMeters: Int?
    var calories: Int?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        kind: TrainingBlockKind,
        title: String,
        skillId: String? = nil,
        routineId: String? = nil,
        cardioType: CardioType? = nil,
        exercises: [PerformanceExercise],
        durationSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        calories: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.skillId = skillId
        self.routineId = routineId
        self.cardioType = cardioType
        self.exercises = exercises
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.notes = notes
    }
}

struct PerformanceExercise: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var movementId: String?
    var rankStandardMovementId: String?
    var plannedSets: Int
    var plannedTarget: String
    var sets: [PerformanceSet]
    var skipped: Bool
    var notes: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        movementId: String? = nil,
        rankStandardMovementId: String? = nil,
        plannedSets: Int,
        plannedTarget: String,
        sets: [PerformanceSet],
        skipped: Bool = false,
        notes: String? = nil
    ) {
        let resolved = MovementResolver.resolve(name)
        self.id = id
        self.name = name
        self.movementId = movementId ?? resolved.movementId
        self.rankStandardMovementId = rankStandardMovementId ?? resolved.rankStandardMovementId
        self.plannedSets = plannedSets
        self.plannedTarget = plannedTarget
        self.sets = sets
        self.skipped = skipped
        self.notes = notes
    }
}

struct PerformanceSet: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var setNumber: Int
    var reps: Int?
    var weightKg: Double?
    var holdSeconds: Int?
    var durationSeconds: Int?
    var distanceMeters: Int?
    var calories: Int?
    var side: TrainingSide?
    var rpe: Int?
    var isWarmup: Bool
    var qualityFlags: Set<PerformanceQualityFlag>
    var notes: String?

    init(
        id: String = UUID().uuidString,
        setNumber: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        holdSeconds: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        calories: Int? = nil,
        side: TrainingSide? = nil,
        rpe: Int? = nil,
        isWarmup: Bool = false,
        qualityFlags: Set<PerformanceQualityFlag> = [],
        notes: String? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.holdSeconds = holdSeconds
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.side = side
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.qualityFlags = qualityFlags
        self.notes = notes
    }
}

enum PerformanceQualityFlag: String, Codable, Hashable, Sendable {
    case clean
    case assisted
    case formBreak
    case partialRange
    case pain
}
