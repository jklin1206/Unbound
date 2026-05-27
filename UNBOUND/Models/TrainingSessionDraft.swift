import Foundation

enum TrainingSessionSource: String, Codable, Hashable, Sendable {
    case program
    case skill
    case cardio
    case custom
    case routine
    case vow
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

extension TrainingSessionDraft {
    static let weeklyVowProgramIdPrefix = "weekly-vow:"

    var weeklyVowId: String? {
        guard let programId,
              programId.hasPrefix(Self.weeklyVowProgramIdPrefix)
        else { return nil }

        let id = String(programId.dropFirst(Self.weeklyVowProgramIdPrefix.count))
        return id.isEmpty ? nil : id
    }

    var isWeeklyVowDraft: Bool {
        source == .vow || weeklyVowId != nil || id.hasPrefix("weekly-vow-draft-")
    }
}

enum TrainingSessionAdaptationKind: String, Codable, Hashable, Sendable {
    case scheduledSkill
    case travel
    case shortSession
    case substitution
    case deload
    case trialPrep
    case skillTaper
}

struct TrainingSessionAdaptationLine: Equatable, Sendable {
    let kind: TrainingSessionAdaptationKind
    let title: String
    let detail: String
}

enum ProgramModifierColorRole: String, Codable, Hashable, Sendable {
    case accent
    case warning
    case neutral
}

struct ProgramModifierLine: Equatable, Sendable {
    let kind: TrainingSessionAdaptationKind
    let priority: Int
    let iconName: String
    let colorRole: ProgramModifierColorRole
    let title: String
    let detail: String
}

struct ProgramModifierSummary: Equatable, Sendable {
    let lines: [ProgramModifierLine]
    let visibleLimit: Int

    var isEmpty: Bool {
        lines.isEmpty
    }

    var visibleLines: [ProgramModifierLine] {
        Array(lines.prefix(visibleLimit))
    }

    var overflowCount: Int {
        max(0, lines.count - visibleLimit)
    }

    static func summarize(
        draft: TrainingSessionDraft,
        isTravelDay: Bool = false,
        visibleLimit: Int = 3
    ) -> ProgramModifierSummary {
        let lines = TrainingSessionAdaptationSummary.summarize(
            draft: draft,
            isTravelDay: isTravelDay
        )
        .map(ProgramModifierLine.init(adaptation:))
        .sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.title < rhs.title
        }

        return ProgramModifierSummary(lines: lines, visibleLimit: visibleLimit)
    }
}

enum TrainingSessionAdaptationSummary {
    static func summarize(
        draft: TrainingSessionDraft,
        isTravelDay: Bool = false
    ) -> [TrainingSessionAdaptationLine] {
        let prescriptions = draft.blocks.flatMap(\.prescriptions)
        var lines: [TrainingSessionAdaptationLine] = []

        let scheduledSkillCount = draft.blocks.filter { $0.kind == .skill && $0.skillId != nil }.count
        if scheduledSkillCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .scheduledSkill,
                    title: scheduledSkillCount == 1 ? "Skill focus attached" : "\(scheduledSkillCount) skill focuses attached",
                    detail: "Placed before the base session so focused practice does not get buried."
                )
            )
        }

        if isTravelDay {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .travel,
                    title: "Travel mode active",
                    detail: "Using the travel plan and available-equipment work for this date."
                )
            )
        }

        let shortModeCount = prescriptions.filter { containsNote($0.notes, "Short mode") }.count
        if shortModeCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .shortSession,
                    title: "Short mode active",
                    detail: "\(shortModeCount) priority exercise\(shortModeCount == 1 ? "" : "s") kept; accessories trimmed for today."
                )
            )
        }

        let substitutedCount = prescriptions.filter {
            containsNote($0.notes, "today's modifiers") || containsNote($0.notes, "swapped from")
        }.count
        if substitutedCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .substitution,
                    title: substitutedCount == 1 ? "1 exercise swapped" : "\(substitutedCount) exercises swapped",
                    detail: "Replacement choices keep the same movement pattern where possible."
                )
            )
        }

        let deloadCount = prescriptions.filter { containsNote($0.notes, "deload") }.count
        if deloadCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .deload,
                    title: "Deload volume applied",
                    detail: "\(deloadCount) exercise\(deloadCount == 1 ? "" : "s") reduced to protect recovery."
                )
            )
        }

        let trialPrepCount = prescriptions.filter { containsNote($0.notes, "trial prep") }.count
        if trialPrepCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .trialPrep,
                    title: "Trial prep included",
                    detail: "\(trialPrepCount) requirement-focused movement\(trialPrepCount == 1 ? "" : "s") added."
                )
            )
        }

        let taperCount = prescriptions.filter { containsNote($0.notes, "scheduled skill work") }.count
        if taperCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .skillTaper,
                    title: "Base volume tapered",
                    detail: "\(taperCount) overlapping exercise\(taperCount == 1 ? "" : "s") trimmed because skill work is already attached."
                )
            )
        }

        return lines
    }

    private static func containsNote(_ note: String?, _ needle: String) -> Bool {
        note?.localizedCaseInsensitiveContains(needle) == true
    }
}

private extension ProgramModifierLine {
    init(adaptation: TrainingSessionAdaptationLine) {
        self.init(
            kind: adaptation.kind,
            priority: adaptation.kind.priority,
            iconName: adaptation.kind.iconName,
            colorRole: adaptation.kind.colorRole,
            title: adaptation.title,
            detail: adaptation.detail
        )
    }
}

private extension TrainingSessionAdaptationKind {
    var priority: Int {
        switch self {
        case .deload:
            return 10
        case .shortSession:
            return 15
        case .substitution:
            return 20
        case .travel:
            return 30
        case .scheduledSkill:
            return 40
        case .trialPrep:
            return 50
        case .skillTaper:
            return 60
        }
    }

    var iconName: String {
        switch self {
        case .scheduledSkill:
            return "figure.strengthtraining.traditional"
        case .travel:
            return "airplane"
        case .shortSession:
            return "timer"
        case .substitution:
            return "arrow.triangle.2.circlepath"
        case .deload:
            return "gauge.with.dots.needle.33percent"
        case .trialPrep:
            return "target"
        case .skillTaper:
            return "scissors"
        }
    }

    var colorRole: ProgramModifierColorRole {
        switch self {
        case .scheduledSkill, .trialPrep, .shortSession:
            return .accent
        case .travel, .substitution:
            return .warning
        case .deload, .skillTaper:
            return .neutral
        }
    }
}

enum TrainingSessionEditPersistence: String, Codable, CaseIterable, Hashable, Sendable {
    case todayOnly
    case recurringSubstitution
    case equipmentPreference
    case nextBlockBias

    var displayName: String {
        switch self {
        case .todayOnly: return "Today only"
        case .recurringSubstitution: return "Repeat swap"
        case .equipmentPreference: return "Preference"
        case .nextBlockBias: return "Next block"
        }
    }

    var explanation: String {
        switch self {
        case .todayOnly:
            return "Starts this edited session without changing the base program."
        case .recurringSubstitution:
            return "Use the selected swap again when this movement appears."
        case .equipmentPreference:
            return "Treat the change as an equipment or availability preference."
        case .nextBlockBias:
            return "Keep the current block intact and bias the next block proposal."
        }
    }

    var isImplemented: Bool {
        switch self {
        case .todayOnly, .recurringSubstitution, .equipmentPreference, .nextBlockBias:
            return true
        }
    }
}

struct TrainingSessionSwapEdit: Equatable, Sendable {
    let originalExerciseName: String
    let replacementExerciseName: String
    let originalMovementId: String?
    let replacementMovementId: String?
    let muscleGroups: [MuscleGroup]
}

enum TrainingSessionEditPreferenceBuilder {
    static func swapEdits(
        original: TrainingSessionDraft,
        edited: TrainingSessionDraft
    ) -> [TrainingSessionSwapEdit] {
        let originalPrescriptions = flattenedPrescriptions(from: original)
        let editedPrescriptions = flattenedPrescriptions(from: edited)
        let sharedCount = min(originalPrescriptions.count, editedPrescriptions.count)

        return (0..<sharedCount).compactMap { index in
            let original = originalPrescriptions[index]
            let edited = editedPrescriptions[index]
            guard MovementCatalog.normalized(original.exerciseName) != MovementCatalog.normalized(edited.exerciseName) else {
                return nil
            }
            return TrainingSessionSwapEdit(
                originalExerciseName: original.exerciseName,
                replacementExerciseName: edited.exerciseName,
                originalMovementId: original.movementId,
                replacementMovementId: edited.movementId,
                muscleGroups: original.muscleGroups.isEmpty ? edited.muscleGroups : original.muscleGroups
            )
        }
    }

    static func preferences(
        for swaps: [TrainingSessionSwapEdit],
        mode: TrainingSessionEditPersistence,
        userId: String,
        updatedAt: Date = Date()
    ) -> [ExercisePreference] {
        switch mode {
        case .recurringSubstitution, .nextBlockBias:
            return uniqueSwaps(swaps).map { swap in
                let originalDefinition = definition(named: swap.originalExerciseName, movementId: swap.originalMovementId)
                let replacementDefinition = definition(named: swap.replacementExerciseName, movementId: swap.replacementMovementId)
                let originalKey = originalDefinition?.canonicalExerciseName
                    ?? MovementCatalog.normalized(swap.originalExerciseName)
                let replacementKey = replacementDefinition?.canonicalExerciseName
                    ?? MovementCatalog.normalized(swap.replacementExerciseName)

                return ExercisePreference(
                    id: "\(userId):\(originalKey)",
                    userId: userId,
                    exerciseName: originalKey,
                    displayName: originalDefinition?.displayName ?? swap.originalExerciseName,
                    status: .substitute,
                    muscleGroups: originalDefinition?.muscleGroups ?? swap.muscleGroups,
                    substitutePreference: replacementKey,
                    notes: mode == .nextBlockBias
                        ? "Queued from Session Editor for the next block proposal."
                        : "Set from Session Editor repeat swap.",
                    updatedAt: updatedAt
                )
            }

        case .equipmentPreference:
            return uniqueSwaps(swaps).map { swap in
                let replacementDefinition = definition(named: swap.replacementExerciseName, movementId: swap.replacementMovementId)
                let replacementKey = replacementDefinition?.canonicalExerciseName
                    ?? MovementCatalog.normalized(swap.replacementExerciseName)

                return ExercisePreference(
                    id: "\(userId):\(replacementKey)",
                    userId: userId,
                    exerciseName: replacementKey,
                    displayName: replacementDefinition?.displayName ?? swap.replacementExerciseName,
                    status: .available,
                    muscleGroups: replacementDefinition?.muscleGroups ?? swap.muscleGroups,
                    substitutePreference: nil,
                    notes: "Marked available from Session Editor.",
                    updatedAt: updatedAt
                )
            }

        case .todayOnly:
            return []
        }
    }

    private static func flattenedPrescriptions(from draft: TrainingSessionDraft) -> [TrainingBlockPrescription] {
        draft.blocks.flatMap(\.prescriptions)
    }

    private static func uniqueSwaps(_ swaps: [TrainingSessionSwapEdit]) -> [TrainingSessionSwapEdit] {
        var seen = Set<String>()
        return swaps.filter { swap in
            let key = [
                MovementCatalog.normalized(swap.originalExerciseName),
                MovementCatalog.normalized(swap.replacementExerciseName)
            ].joined(separator: "->")
            return seen.insert(key).inserted
        }
    }

    private static func definition(named name: String, movementId: String?) -> MovementDefinition? {
        if let movementId, let definition = MovementCatalog.definition(for: movementId) {
            return definition
        }
        return MovementCatalog.canonicalExercise(named: name)
    }
}

struct TrainingSessionEditSummary: Equatable, Sendable {
    let originalExerciseCount: Int
    let editedExerciseCount: Int
    let addedCount: Int
    let removedCount: Int
    let changedSlotCount: Int
    let reordered: Bool

    var isChanged: Bool {
        addedCount > 0 || removedCount > 0 || changedSlotCount > 0 || reordered
    }

    var headline: String {
        guard isChanged else { return "No edits yet" }

        let total = addedCount + removedCount + changedSlotCount + (reordered ? 1 : 0)
        return "\(total) edit\(total == 1 ? "" : "s") staged"
    }

    var details: [String] {
        var parts: [String] = []
        if addedCount > 0 { parts.append("+\(addedCount) added") }
        if removedCount > 0 { parts.append("-\(removedCount) removed") }
        if changedSlotCount > 0 { parts.append("\(changedSlotCount) swapped") }
        if reordered { parts.append("order changed") }
        return parts
    }

    static func compare(original: TrainingSessionDraft, edited: TrainingSessionDraft) -> TrainingSessionEditSummary {
        let originalNames = flattenedExerciseNames(from: original)
        let editedNames = flattenedExerciseNames(from: edited)

        let originalCounts = countsByName(originalNames)
        let editedCounts = countsByName(editedNames)
        let allNames = Set(originalCounts.keys).union(editedCounts.keys)

        let rawAdded = allNames.reduce(0) { total, name in
            total + max(0, (editedCounts[name] ?? 0) - (originalCounts[name] ?? 0))
        }
        let rawRemoved = allNames.reduce(0) { total, name in
            total + max(0, (originalCounts[name] ?? 0) - (editedCounts[name] ?? 0))
        }

        let sharedCount = min(originalNames.count, editedNames.count)
        let changedSlots = (0..<sharedCount).reduce(0) { total, index in
            originalNames[index] == editedNames[index] ? total : total + 1
        }

        let reordered = originalCounts == editedCounts && originalNames != editedNames
        let swapCount = reordered || originalNames.count != editedNames.count ? 0 : changedSlots

        return TrainingSessionEditSummary(
            originalExerciseCount: originalNames.count,
            editedExerciseCount: editedNames.count,
            addedCount: max(0, rawAdded - swapCount),
            removedCount: max(0, rawRemoved - swapCount),
            changedSlotCount: swapCount,
            reordered: reordered
        )
    }

    private static func flattenedExerciseNames(from draft: TrainingSessionDraft) -> [String] {
        draft.blocks.flatMap { block in
            block.prescriptions.map { prescription in
                MovementCatalog.normalized(prescription.exerciseName)
            }
        }
    }

    private static func countsByName(_ names: [String]) -> [String: Int] {
        names.reduce(into: [:]) { counts, name in
            counts[name, default: 0] += 1
        }
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
