import Foundation
import Combine

/// First integer run in a rep prescription string. "8-10"→8, "30s"→30,
/// "12 each side"→12, "AMRAP"→nil, ""→nil.
enum RepRange {
    static func lowerBound(_ s: String) -> Int? {
        var digits = ""
        for ch in s {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}

@MainActor
final class ActiveWorkoutSession: ObservableObject, Identifiable {
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

    let id: String
    let programId: String
    let dayNumber: Int
    let plannedWorkoutName: String
    let startedAt: Date
    let source: TrainingSessionSource

    @Published var exercises: [ActiveExercise]
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSetIndex: Int = 0

    init(workout: Workout, programId: String, dayNumber: Int, source: TrainingSessionSource = .program) {
        self.id = UUID().uuidString
        self.programId = programId
        self.dayNumber = dayNumber
        self.plannedWorkoutName = workout.name
        self.startedAt = Date()
        self.source = source
        self.exercises = workout.mainExercises.map { ex in
            let definition = Self.movementDefinition(for: ex.name)
            let metricKind = Self.metricKind(
                for: ex.reps,
                definitionDefault: definition?.defaultMetric
            )
            return ActiveExercise(
                id: ex.id,
                name: ex.name,
                plannedSets: ex.sets,
                plannedReps: ex.reps,
                restSeconds: RestPrescription.restSeconds(for: ex),
                muscleGroups: ex.muscleGroups,
                sets: (0..<max(1, ex.sets)).map { _ in
                    ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                              rpe: nil, isWarmup: false, logged: false,
                              suggestedWeightKg: nil,
                              suggestedReps: metricKind == .reps ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedHoldSeconds: metricKind == .holdSeconds ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedDurationSeconds: metricKind == .durationSeconds ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedDistanceMeters: metricKind == .distanceMeters ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedCalories: metricKind == .calories ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedRPE: ex.rpe,
                              suggestedRestSeconds: RestPrescription.restSeconds(for: ex))
                },
                skipped: false,
                notes: "",
                movementId: definition?.id,
                rankStandardMovementId: definition?.rankStandardMovementId,
                targetRPE: ex.rpe,
                formCues: ex.notes,
                substitution: ex.substitution,
                blockKind: definition?.blockKind ?? .strength,
                skillId: definition?.skillId,
                cardioType: definition?.cardioType,
                tracksHold: definition?.blockKind == .carry || metricKind == .holdSeconds || metricKind == .durationSeconds,
                metricKind: metricKind
            )
        }
        markCurrentExerciseStarted(at: startedAt)
    }

    init(snapshot s: Snapshot) {
        self.id = s.id
        self.programId = s.programId
        self.dayNumber = s.dayNumber
        self.plannedWorkoutName = s.plannedWorkoutName
        self.startedAt = s.startedAt
        self.source = s.source ?? .program
        self.exercises = s.exercises
        self.currentExerciseIndex = min(s.currentExerciseIndex, max(0, s.exercises.count - 1))
        self.currentSetIndex = s.currentSetIndex
        markCurrentExerciseStarted()
    }

    convenience init(trainingDraft draft: TrainingSessionDraft) {
        self.init(workout: TrainingSessionAdapters.workout(from: draft),
                  programId: draft.programId ?? "",
                  dayNumber: draft.dayNumber ?? 0,
                  source: draft.source)
        self.exercises = Self.activeExercises(from: draft)
        markCurrentExerciseStarted(at: startedAt)
    }

    func snapshot() -> Snapshot {
        Snapshot(id: id, programId: programId, dayNumber: dayNumber,
                 plannedWorkoutName: plannedWorkoutName, startedAt: startedAt, source: source,
                 exercises: exercises, currentExerciseIndex: currentExerciseIndex,
                 currentSetIndex: currentSetIndex)
    }

    var currentExercise: ActiveExercise? {
        exercises.indices.contains(currentExerciseIndex) ? exercises[currentExerciseIndex] : nil
    }

    var isLastSetOfWorkout: Bool {
        guard let last = exercises.indices.last else { return true }
        let lastActiveIdx = exercises.lastIndex(where: { !$0.skipped }) ?? last
        guard currentExerciseIndex == lastActiveIdx else { return false }
        return currentSetIndex >= exercises[lastActiveIdx].sets.count - 1
    }

    var hasUnloggedWorkingSets: Bool {
        exercises.contains { exercise in
            !exercise.skipped && exercise.sets.contains { !$0.isWarmup && !$0.logged }
        }
    }

    var progressSummary: ProgressSummary {
        let workSets = exercises
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
        let logged = workSets.filter(\.logged).count
        return ProgressSummary(
            loggedWorkingSets: logged,
            totalWorkingSets: workSets.count
        )
    }

    func logCurrentSet(weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        objectWillChange.send()
        markExerciseStarted(exerciseIndex: currentExerciseIndex)
        exercises[currentExerciseIndex].sets[currentSetIndex].weightKg = weightKg
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = reps
        exercises[currentExerciseIndex].sets[currentSetIndex].logged = true
        markExerciseCompletedIfReady(exerciseIndex: currentExerciseIndex)
    }

    func toggleCurrentWarmup() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        objectWillChange.send()
        exercises[currentExerciseIndex].sets[currentSetIndex].isWarmup.toggle()
    }

    func advance() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        if currentSetIndex < exercises[currentExerciseIndex].sets.count - 1 {
            currentSetIndex += 1
        } else {
            advanceToNextUnskippedExercise(after: currentExerciseIndex)
        }
    }

    private func advanceToNextUnskippedExercise(after idx: Int) {
        var next = idx + 1
        while next < exercises.count && exercises[next].skipped { next += 1 }
        if next < exercises.count {
            currentExerciseIndex = next
            currentSetIndex = 0
            markCurrentExerciseStarted()
        }
    }

    private func advanceAfterLogging(exerciseIndex ei: Int, setIndex si: Int) {
        guard currentExerciseIndex == ei, currentSetIndex == si else { return }

        if let nextSet = exercises[ei].sets.indices.first(where: { $0 > si && !exercises[ei].sets[$0].logged }) {
            currentSetIndex = nextSet
            return
        }

        markExerciseCompletedIfReady(exerciseIndex: ei)

        if let nextExercise = exercises.indices.first(where: { idx in
            idx > ei && !exercises[idx].skipped && exercises[idx].sets.contains(where: { !$0.logged })
        }) {
            currentExerciseIndex = nextExercise
            currentSetIndex = exercises[nextExercise].sets.firstIndex(where: { !$0.logged }) ?? 0
            markCurrentExerciseStarted()
        }
    }

    func jumpToExercise(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
        currentSetIndex = 0
        markCurrentExerciseStarted()
    }

    func addSetToCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        let exercise = exercises[currentExerciseIndex]
        objectWillChange.send()
        exercises[currentExerciseIndex].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      rpe: nil, isWarmup: false, logged: false,
                      suggestedReps: exercise.metricKind == .reps ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedHoldSeconds: exercise.metricKind == .holdSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDurationSeconds: exercise.metricKind == .durationSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDistanceMeters: exercise.metricKind == .distanceMeters ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedCalories: exercise.metricKind == .calories ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedRPE: exercise.targetRPE,
                      suggestedRestSeconds: exercise.restSeconds))
    }

    func removeLastSetFromCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.count > 1 else { return }
        objectWillChange.send()
        exercises[currentExerciseIndex].sets.removeLast()
        if currentSetIndex >= exercises[currentExerciseIndex].sets.count {
            currentSetIndex = exercises[currentExerciseIndex].sets.count - 1
        }
    }

    func skipCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        objectWillChange.send()
        exercises[currentExerciseIndex].skipped = true
        advanceToNextUnskippedExercise(after: currentExerciseIndex)
    }

    func setNotes(_ text: String, forExerciseAt index: Int) {
        guard exercises.indices.contains(index) else { return }
        objectWillChange.send()
        exercises[index].notes = text
    }

    // MARK: Index-addressed mutators (grid logs any set in any order)

    func logSet(exerciseIndex ei: Int, setIndex si: Int, weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        markExerciseStarted(exerciseIndex: ei)
        exercises[ei].sets[si].weightKg = weightKg
        exercises[ei].sets[si].reps = reps
        exercises[ei].sets[si].logged = true
        markExerciseCompletedIfReady(exerciseIndex: ei)
    }

    func setRPE(exerciseIndex ei: Int, setIndex si: Int, _ rpe: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        exercises[ei].sets[si].rpe = rpe
    }

    func toggleQualityFlag(_ flag: PerformanceQualityFlag, exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        if exercises[ei].sets[si].qualityFlags.contains(flag) {
            exercises[ei].sets[si].qualityFlags.remove(flag)
        } else {
            exercises[ei].sets[si].qualityFlags.insert(flag)
            exercises[ei].sets[si].qualityFlags.remove(.clean)
        }
    }

    /// One-tap confirmation: preserve any values the user entered, fill only
    /// missing fields from the plan, then mark the set logged.
    func confirmAsPlanned(exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si),
              !exercises[ei].sets[si].logged else { return }
        objectWillChange.send()
        markExerciseStarted(exerciseIndex: ei)
        if exercises[ei].sets[si].weightKg == nil {
            exercises[ei].sets[si].weightKg = exercises[ei].sets[si].suggestedWeightKg
        }
        if exercises[ei].sets[si].reps == nil {
            exercises[ei].sets[si].reps = exercises[ei].sets[si].suggestedReps
        }
        if exercises[ei].sets[si].holdSeconds == nil {
            exercises[ei].sets[si].holdSeconds = exercises[ei].sets[si].suggestedHoldSeconds
        }
        if exercises[ei].sets[si].durationSeconds == nil {
            exercises[ei].sets[si].durationSeconds = exercises[ei].sets[si].suggestedDurationSeconds
        }
        if exercises[ei].sets[si].distanceMeters == nil {
            exercises[ei].sets[si].distanceMeters = exercises[ei].sets[si].suggestedDistanceMeters
        }
        if exercises[ei].sets[si].calories == nil {
            exercises[ei].sets[si].calories = exercises[ei].sets[si].suggestedCalories
        }
        if exercises[ei].sets[si].rpe == nil {
            exercises[ei].sets[si].rpe = exercises[ei].sets[si].suggestedRPE
        }
        exercises[ei].sets[si].logged = true
        markExerciseCompletedIfReady(exerciseIndex: ei)
        advanceAfterLogging(exerciseIndex: ei, setIndex: si)
    }

    /// Implicit logging follows the set's required fields. Returns true only
    /// on the false→true edge so the caller can fire haptic/rest once.
    @discardableResult
    func recomputeLogged(exerciseIndex ei: Int, setIndex si: Int) -> Bool {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return false }
        let was = exercises[ei].sets[si].logged
        let complete = exercises[ei].sets[si].hasRequiredLogFields(exercises[ei].metricKind)
        if complete {
            objectWillChange.send()
            markExerciseStarted(exerciseIndex: ei)
            if exercises[ei].sets[si].rpe == nil {
                exercises[ei].sets[si].rpe = exercises[ei].sets[si].suggestedRPE
            }
            exercises[ei].sets[si].logged = true
            markExerciseCompletedIfReady(exerciseIndex: ei)
            if !was {
                advanceAfterLogging(exerciseIndex: ei, setIndex: si)
            }
        } else if was {
            objectWillChange.send()
            exercises[ei].sets[si].logged = false
            exercises[ei].completedAt = nil
        }
        return complete && !was
    }

    func addSet(toExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei) else { return }
        let exercise = exercises[ei]
        objectWillChange.send()
        exercises[ei].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      rpe: nil, isWarmup: false, logged: false,
                      suggestedReps: exercise.metricKind == .reps ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedHoldSeconds: exercise.metricKind == .holdSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDurationSeconds: exercise.metricKind == .durationSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDistanceMeters: exercise.metricKind == .distanceMeters ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedCalories: exercise.metricKind == .calories ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedRPE: exercise.targetRPE,
                      suggestedRestSeconds: exercise.restSeconds))
    }

    func removeLastSet(fromExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.count > 1 else { return }
        objectWillChange.send()
        exercises[ei].sets.removeLast()
    }

    func appendCustomExercise(_ custom: CustomExercise) {
        let plannedSets = Self.defaultSetCount(for: custom.classification)
        let plannedReps = "\(custom.defaultRepMin)-\(custom.defaultRepMax)"
        let targetRPE = 8
        let exercise = ActiveExercise(
            id: custom.id.uuidString,
            name: custom.displayName,
            plannedSets: plannedSets,
            plannedReps: plannedReps,
            restSeconds: Self.defaultRestSeconds(for: custom.classification),
            muscleGroups: Self.muscleGroups(for: custom.pattern),
            sets: (0..<plannedSets).map { _ in
                ActiveSet(
                    id: UUID().uuidString,
                    weightKg: nil,
                    reps: nil,
                    rpe: nil,
                    isWarmup: false,
                    logged: false,
                    suggestedReps: custom.defaultRepMin,
                    suggestedRPE: targetRPE,
                    suggestedRestSeconds: Self.defaultRestSeconds(for: custom.classification)
                )
            },
            skipped: false,
            notes: custom.notes ?? "",
            targetRPE: targetRPE,
            substitution: "Custom exercise",
            blockKind: custom.classification == .bodyweightSkill ? .bodyweight : .strength,
            metricKind: .reps
        )

        objectWillChange.send()
        exercises.append(exercise)
    }

    func replaceExercise(at index: Int, with alternative: CatalogExercise) {
        guard exercises.indices.contains(index) else { return }
        let previousName = exercises[index].name
        let definition = Self.movementDefinition(for: alternative.displayName)
            ?? MovementCatalog.canonicalExercise(named: alternative.name)
        let resolved = MovementResolver.resolve(alternative.displayName)
        let metricKind = Self.metricKind(
            for: exercises[index].plannedReps,
            definitionDefault: definition?.defaultMetric
        )

        objectWillChange.send()
        exercises[index].name = alternative.displayName
        exercises[index].movementId = definition?.id ?? resolved.movementId
        exercises[index].rankStandardMovementId = definition?.rankStandardMovementId ?? resolved.rankStandardMovementId
        exercises[index].muscleGroups = alternative.muscleGroups
        exercises[index].blockKind = definition?.blockKind ?? exercises[index].blockKind
        exercises[index].skillId = definition?.skillId
        exercises[index].cardioType = definition?.cardioType
        exercises[index].metricKind = metricKind
        exercises[index].tracksHold = definition?.blockKind == .carry || metricKind == .holdSeconds || metricKind == .durationSeconds
        exercises[index].substitution = "Swapped from \(previousName)"

        for setIndex in exercises[index].sets.indices where !exercises[index].sets[setIndex].logged {
            exercises[index].sets[setIndex].suggestedReps = metricKind == .reps
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedHoldSeconds = metricKind == .holdSeconds
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedDurationSeconds = metricKind == .durationSeconds
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedDistanceMeters = metricKind == .distanceMeters
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedCalories = metricKind == .calories
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
        }
    }

    private func markCurrentExerciseStarted(at date: Date = Date()) {
        markExerciseStarted(exerciseIndex: currentExerciseIndex, at: date)
    }

    private func markExerciseStarted(exerciseIndex index: Int, at date: Date = Date()) {
        guard exercises.indices.contains(index), exercises[index].startedAt == nil else { return }
        exercises[index].startedAt = date
    }

    private func markExerciseCompletedIfReady(exerciseIndex index: Int, at date: Date = Date()) {
        guard exercises.indices.contains(index) else { return }
        let workingSets = exercises[index].sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty, workingSets.allSatisfy(\.logged) else { return }
        exercises[index].completedAt = date
    }
}

private extension ActiveWorkoutSession.ActiveSet {
    func hasRequiredLogFields(_ metricKind: TrainingMetricKind) -> Bool {
        switch metricKind {
        case .reps:
            guard reps != nil else { return false }
            return suggestedWeightKg == nil || weightKg != nil
        case .holdSeconds: return holdSeconds != nil
        case .durationSeconds: return durationSeconds != nil
        case .distanceMeters: return distanceMeters != nil
        case .calories: return calories != nil
        }
    }
}
