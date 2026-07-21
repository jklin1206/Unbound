import Foundation

struct SavedWorkout: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var blocks: [TrainingBlock]
    var order: Int
    var preferredEquipment: Set<Equipment>
    var referenceExerciseName: String?
    /// Agent B adapter until Agent A lands a typed SessionRole.
    var sessionRole: String?
    var abPartnerID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        blocks: [TrainingBlock],
        order: Int = 0,
        preferredEquipment: Set<Equipment> = [],
        referenceExerciseName: String? = nil,
        sessionRole: String? = nil,
        abPartnerID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.blocks = blocks
        self.order = order
        self.preferredEquipment = preferredEquipment
        self.referenceExerciseName = TrainingSessionDraft.cleanedReferenceExerciseName(
            referenceExerciseName,
            in: blocks
        )
        self.sessionRole = Self.normalizedSessionRole(sessionRole)
        self.abPartnerID = abPartnerID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: SavedWorkout, rhs: SavedWorkout) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var exerciseCount: Int {
        blocks.reduce(0) { $0 + $1.prescriptions.count }
    }

    var estimatedMinutes: Int {
        max(10, blocks.reduce(0) { total, block in
            total + block.prescriptions.reduce(0) { blockTotal, prescription in
                let setMinutes = prescription.effectiveSetPlans.reduce(0) { setTotal, plan in
                    let workSeconds: Int
                    switch plan.target {
                    case .holdSeconds(let seconds), .timedSeconds(let seconds):
                        workSeconds = seconds
                    default:
                        workSeconds = 45
                    }
                    return setTotal + max(1, Int(ceil(Double(workSeconds + plan.restSeconds) / 60.0)))
                }
                return blockTotal + max(3, setMinutes)
            }
        })
    }

    func asDraft(
        userId: String,
        date: Date = Date(),
        programId: String? = nil,
        dayNumber: Int? = nil
    ) -> TrainingSessionDraft {
        TrainingSessionDraft(
            userId: userId,
            source: .custom,
            title: title,
            date: date,
            estimatedMinutes: estimatedMinutes,
            programId: programId,
            dayNumber: dayNumber,
            referenceExerciseName: referenceExerciseName,
            blocks: blocks
        )
    }

    /// Draft for editing this loadout in place: keyed to the loadout's id so
    /// the library's id-keyed auto-save updates this entry instead of
    /// duplicating it.
    func asEditingDraft(userId: String) -> TrainingSessionDraft {
        TrainingSessionDraft(
            id: id.uuidString,
            userId: userId,
            source: .custom,
            title: title,
            estimatedMinutes: estimatedMinutes,
            referenceExerciseName: referenceExerciseName,
            blocks: blocks
        )
    }

    static func from(
        _ workout: Workout,
        title: String? = nil,
        order: Int = 0,
        preferredEquipment: Set<Equipment> = [],
        referenceExerciseName: String? = nil,
        sessionRole: String? = nil,
        now: Date = Date()
    ) -> SavedWorkout {
        var blocks: [TrainingBlock] = []
        if !workout.warmup.isEmpty {
            blocks.append(TrainingSessionAdapters.exerciseBlock(title: "Warmup", kind: .bodyweight, exercises: workout.warmup))
        }
        if !workout.mainExercises.isEmpty {
            blocks.append(TrainingSessionAdapters.exerciseBlock(title: workout.name, kind: .strength, exercises: workout.mainExercises))
        }
        if !workout.cooldown.isEmpty {
            blocks.append(TrainingSessionAdapters.exerciseBlock(title: "Cooldown", kind: .routine, exercises: workout.cooldown))
        }

        return SavedWorkout(
            title: title ?? workout.name,
            blocks: blocks,
            order: order,
            preferredEquipment: preferredEquipment,
            referenceExerciseName: referenceExerciseName,
            sessionRole: sessionRole ?? inferredSessionRole(from: workout),
            createdAt: now,
            updatedAt: now
        )
    }

    static func from(
        _ draft: TrainingSessionDraft,
        title: String? = nil,
        order: Int = 0,
        preferredEquipment: Set<Equipment> = [],
        referenceExerciseName: String? = nil,
        sessionRole: String? = nil,
        now: Date = Date()
    ) -> SavedWorkout {
        SavedWorkout(
            title: title ?? draft.title,
            blocks: draft.blocks,
            order: order,
            preferredEquipment: preferredEquipment,
            referenceExerciseName: referenceExerciseName ?? draft.referenceExerciseName,
            sessionRole: sessionRole ?? inferredSessionRole(from: draft),
            createdAt: now,
            updatedAt: now
        )
    }

    static func normalizedSessionRole(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return normalized.isEmpty ? nil : normalized
    }

    static func inferredSessionRole(from draft: TrainingSessionDraft) -> String? {
        inferRole(title: draft.title, muscleGroups: draft.blocks.flatMap { block in
            block.prescriptions.flatMap(\.muscleGroups)
        })
    }

    var referenceExerciseOptions: [String] {
        TrainingSessionDraft.referenceExerciseOptions(in: blocks)
    }

    var effectiveReferenceExerciseName: String? {
        TrainingSessionDraft.effectiveReferenceExerciseName(referenceExerciseName, in: blocks)
    }

    static func inferredSessionRole(from workout: Workout) -> String? {
        inferRole(title: workout.name, muscleGroups: workout.targetMuscleGroups)
    }

    private static func inferRole(title: String, muscleGroups: [MuscleGroup]) -> String? {
        let normalizedTitle = normalizedSessionRole(title) ?? ""
        let directMatches: [(needle: String, role: String)] = [
            ("full-body", "full-body"),
            ("fullbody", "full-body"),
            ("upper", "upper"),
            ("lower", "lower"),
            ("push", "push"),
            ("pull", "pull"),
            ("legs", "legs"),
            ("leg", "legs"),
            ("chest", "push"),
            ("back", "pull")
        ]
        if let match = directMatches.first(where: { normalizedTitle.contains($0.needle) }) {
            return match.role
        }

        let counts = Dictionary(grouping: muscleGroups, by: { $0 }).mapValues(\.count)
        let push = (counts[.chest] ?? 0) + (counts[.shoulders] ?? 0)
        let pull = counts[.back] ?? 0
        // .legs/.arms are legacy coarse tags kept for persisted data alongside the fine-grained cases.
        let legs = (counts[.quads] ?? 0) + (counts[.hamstrings] ?? 0) + (counts[.glutes] ?? 0) + (counts[.legs] ?? 0)
        let upper = push + pull + (counts[.biceps] ?? 0) + (counts[.triceps] ?? 0) + (counts[.arms] ?? 0)
        if legs > upper { return "legs" }
        if push > pull { return "push" }
        if pull > push { return "pull" }
        if upper > 0 { return "upper" }
        if counts[.core] ?? 0 > 0 { return "core" }
        return nil
    }
}
