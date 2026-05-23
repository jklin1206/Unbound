import Foundation

enum TrainingSessionAdapters {
    static func draft(
        from workout: Workout,
        userId: String,
        programId: String?,
        dayNumber: Int?,
        scheduledSkillIds: [String] = []
    ) -> TrainingSessionDraft {
        var blocks: [TrainingBlock] = []

        if !workout.warmup.isEmpty {
            blocks.append(exerciseBlock(title: "Warmup", kind: .bodyweight, exercises: workout.warmup))
        }

        blocks.append(exerciseBlock(title: workout.name, kind: .strength, exercises: workout.mainExercises))

        for skillId in scheduledSkillIds {
            if let skill = SkillGraph.shared.node(id: skillId) {
                blocks.append(skillBlock(skillId: skill.id, title: skill.title))
            }
        }

        if !workout.cooldown.isEmpty {
            blocks.append(exerciseBlock(title: "Cooldown", kind: .routine, exercises: workout.cooldown))
        }

        return TrainingSessionDraft(
            userId: userId,
            source: .program,
            title: workout.name,
            estimatedMinutes: workout.estimatedMinutes,
            programId: programId,
            dayNumber: dayNumber,
            blocks: blocks
        )
    }

    static func draft(
        forSkillId skillId: String,
        title: String,
        userId: String,
        plan: SkillTrainingPlan? = nil
    ) -> TrainingSessionDraft {
        let prescriptions = plan?.mainSets.map { prescription in
            TrainingBlockPrescription(
                exerciseName: prescription.exerciseName,
                sets: prescription.sets,
                target: TrainingTarget(prescription.target),
                restSeconds: prescription.restSeconds,
                rpe: nil,
                notes: prescription.notes
            )
        } ?? [
            TrainingBlockPrescription(
                exerciseName: title,
                sets: 1,
                target: .amrap,
                restSeconds: 90
            )
        ]

        return TrainingSessionDraft(
            userId: userId,
            source: .skill,
            title: title,
            estimatedMinutes: 20,
            blocks: [
                TrainingBlock(
                    kind: .skill,
                    title: title,
                    skillId: skillId,
                    prescriptions: prescriptions
                )
            ]
        )
    }

    static func exerciseBlock(title: String, kind: TrainingBlockKind, exercises: [Exercise]) -> TrainingBlock {
        TrainingBlock(
            kind: kind,
            title: title,
            prescriptions: exercises.map { exercise in
                prescription(from: exercise)
            }
        )
    }

    static func skillBlock(skillId: String, title: String) -> TrainingBlock {
        let plan = SkillTrainingPlanLibrary.plan(for: skillId)
        let prescriptions = plan?.mainSets.prefix(3).map { prescription in
            TrainingBlockPrescription(
                exerciseName: prescription.exerciseName,
                sets: prescription.sets,
                target: TrainingTarget(prescription.target),
                restSeconds: prescription.restSeconds,
                notes: prescription.notes
            )
        } ?? []
        return TrainingBlock(
            kind: .skill,
            title: title,
            subtitle: "Scheduled skill work",
            skillId: skillId,
            prescriptions: Array(prescriptions)
        )
    }

    static func workout(from draft: TrainingSessionDraft) -> Workout {
        let exercises = draft.blocks
            .filter { $0.kind == .strength || $0.kind == .bodyweight || $0.kind == .custom }
            .flatMap { block in
                block.prescriptions.map { prescription in
                    Exercise(
                        id: prescription.id,
                        name: prescription.exerciseName,
                        muscleGroups: prescription.muscleGroups,
                        sets: prescription.sets,
                        reps: prescription.target.displayText,
                        restSeconds: prescription.restSeconds,
                        rpe: prescription.rpe,
                        notes: prescription.notes,
                        substitution: nil
                    )
                }
            }

        return Workout(
            name: draft.title,
            targetMuscleGroups: uniqueMuscleGroups(exercises.flatMap(\.muscleGroups)),
            warmup: [],
            mainExercises: exercises,
            cooldown: [],
            estimatedMinutes: draft.estimatedMinutes,
            notes: nil,
            blockType: nil
        )
    }

    static func workoutLog(from log: PerformanceLog) -> WorkoutLog? {
        let entries: [ExerciseLogEntry] = log.blocks
            .filter { $0.kind == .strength || $0.kind == .bodyweight || $0.kind == .custom || $0.kind == .skill || $0.kind == .carry }
            .flatMap { block in
                block.exercises.compactMap { exercise in
                    let completedSets = exercise.sets.filter(\.hasCompletedTrainingMetric)
                    guard !completedSets.isEmpty || exercise.skipped else { return nil }

                    return ExerciseLogEntry(
                        id: exercise.id,
                        exerciseName: exercise.name,
                        movementId: exercise.movementId,
                        rankStandardMovementId: exercise.rankStandardMovementId,
                        plannedSets: exercise.plannedSets,
                        plannedReps: exercise.plannedTarget,
                        sets: completedSets.map { set in
                            SetLog(
                                id: set.id,
                                setNumber: set.setNumber,
                                weightKg: set.weightKg,
                                reps: set.reps ?? set.holdSeconds ?? set.durationSeconds ?? 0,
                                rpe: set.rpe,
                                isWarmup: set.isWarmup
                            )
                        },
                        skipped: exercise.skipped,
                        notes: exercise.notes
                    )
                }
            }

        guard entries.contains(where: { !$0.sets.isEmpty }) else { return nil }

        return WorkoutLog(
            id: log.id,
            userId: log.userId,
            programId: log.programId ?? log.source.rawValue,
            dayNumber: log.dayNumber ?? 0,
            plannedWorkoutName: log.title,
            startedAt: log.startedAt,
            completedAt: log.completedAt,
            exerciseEntries: entries,
            overallNotes: log.notes,
            overallRPE: log.overallRPE,
            durationMinutes: max(0, Int(log.completedAt.timeIntervalSince(log.startedAt) / 60))
        )
    }

    static func sessionLogs(from log: PerformanceLog, xpAwarded: Int = 25) -> [SessionLog] {
        log.blocks.compactMap { block in
            guard block.kind == .skill, let skillId = block.skillId else { return nil }
            let exercises = block.exercises.compactMap { exercise -> LoggedExercise? in
                let completedSets = exercise.sets.compactMap { set -> LoggedSet? in
                    guard set.hasCompletedSkillSessionMetric else { return nil }
                    return LoggedSet(
                        reps: set.reps ?? 0,
                        holdSeconds: set.holdSeconds,
                        weightKg: set.weightKg,
                        rpe: set.rpe
                    )
                }
                guard !completedSets.isEmpty else { return nil }
                return LoggedExercise(
                    name: exercise.name,
                    sets: completedSets
                )
            }
            guard !exercises.isEmpty else { return nil }
            return SessionLog(
                id: "\(log.id):\(block.id):session",
                userId: log.userId,
                skillId: skillId,
                createdAt: log.completedAt,
                durationSeconds: block.durationSeconds ?? Int(log.completedAt.timeIntervalSince(log.startedAt)),
                exercises: exercises,
                xpAwarded: xpAwarded
            )
        }
    }

    static func performanceLogForSkillSession(
        id: String = UUID().uuidString,
        userId: String,
        skillId: String,
        skillTitle: String,
        startedAt: Date,
        completedAt: Date = Date(),
        durationSeconds: Int,
        exercises: [LoggedExercise],
        source: TrainingSessionSource = .skill
    ) -> PerformanceLog {
        PerformanceLog(
            id: id,
            userId: userId,
            source: source,
            title: skillTitle,
            startedAt: startedAt,
            completedAt: completedAt,
            blocks: [
                PerformanceBlock(
                    kind: .skill,
                    title: skillTitle,
                    skillId: skillId,
                    exercises: exercises.map { exercise in
                        let resolved = MovementResolver.resolve(exercise.name)
                        return PerformanceExercise(
                            name: exercise.name,
                            movementId: resolved.movementId,
                            rankStandardMovementId: resolved.rankStandardMovementId,
                            plannedSets: exercise.sets.count,
                            plannedTarget: "Skill work",
                            sets: exercise.sets.enumerated().map { index, set in
                                PerformanceSet(
                                    setNumber: index + 1,
                                    reps: set.reps,
                                    weightKg: set.weightKg,
                                    holdSeconds: set.holdSeconds,
                                    rpe: set.rpe
                                )
                            }
                        )
                    },
                    durationSeconds: durationSeconds
                )
            ]
        )
    }

    static func performanceLogForCardioSession(_ session: CardioSession) -> PerformanceLog {
        let durationSeconds = max(60, session.durationMinutes * 60)
        let completedAt = session.date
        let startedAt = completedAt.addingTimeInterval(-TimeInterval(durationSeconds))
        let distanceMeters = session.distanceKm.map { Int(($0 * 1_000).rounded()) }

        var blockNotes: [String] = []
        if let avgHR = session.avgHR {
            blockNotes.append("Avg HR \(avgHR)")
        }
        if let notes = session.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockNotes.append(notes)
        }

        return PerformanceLog(
            id: "cardio-\(session.id.uuidString)",
            userId: session.userId,
            source: .cardio,
            title: "\(session.type.displayName) Session",
            startedAt: startedAt,
            completedAt: completedAt,
            blocks: [
                PerformanceBlock(
                    kind: .cardio,
                    title: session.type.displayName,
                    cardioType: session.type,
                    exercises: [],
                    durationSeconds: durationSeconds,
                    distanceMeters: distanceMeters,
                    notes: blockNotes.isEmpty ? nil : blockNotes.joined(separator: " · ")
                )
            ],
            overallRPE: session.perceivedEffort,
            notes: session.notes
        )
    }

    static func performanceLogForRoutine(
        _ routine: RoutineDef,
        record: RoutineCompletionRecord,
        userId: String
    ) -> PerformanceLog {
        let completedAt = record.completedAt
        let elapsedSeconds = max(1, record.elapsedSeconds)
        let startedAt = completedAt.addingTimeInterval(-TimeInterval(elapsedSeconds))
        let exercises = record.performanceEntries.isEmpty
            ? routinePerformanceExercises(from: routine, record: record)
            : routinePerformanceExercises(from: record.performanceEntries)

        return PerformanceLog(
            id: "routine-\(record.id)",
            userId: userId,
            source: .routine,
            title: routine.title,
            startedAt: startedAt,
            completedAt: completedAt,
            blocks: [
                PerformanceBlock(
                    kind: .routine,
                    title: routine.title,
                    routineId: routine.id,
                    exercises: exercises,
                    durationSeconds: elapsedSeconds,
                    notes: routine.category.label
                )
            ],
            notes: routine.subtitle
        )
    }

    private static func routinePerformanceExercises(
        from entries: [RoutinePerformanceEntry]
    ) -> [PerformanceExercise] {
        var orderedNames: [String] = []
        var grouped: [String: [RoutinePerformanceEntry]] = [:]
        var inferredExercises: [PerformanceExercise] = []

        for entry in entries {
            if entry.hasDirectMetric {
                let name = cleanRoutineExerciseName(entry.name)
                if grouped[name] == nil { orderedNames.append(name) }
                grouped[name, default: []].append(entry)
            } else if entry.source == .instruction,
                      let inferred = instructionRoutineExercise(from: entry.name) {
                inferredExercises.append(inferred)
            }
        }

        var exercises = orderedNames.compactMap { name -> PerformanceExercise? in
            guard let group = grouped[name] else { return nil }
            let sets = group.flatMap { performanceSets(from: $0) }
            guard !sets.isEmpty else { return nil }
            return PerformanceExercise(
                name: name,
                plannedSets: sets.count,
                plannedTarget: plannedTarget(from: group),
                sets: renumbered(sets),
                notes: group.compactMap(\.notes).nilIfEmpty?.joined(separator: " · ")
            )
        }

        exercises.append(contentsOf: inferredExercises)
        return exercises.filter { exercise in
            exercise.sets.contains { set in
                (set.reps ?? 0) > 0
                    || (set.holdSeconds ?? 0) > 0
                    || (set.durationSeconds ?? 0) > 0
                    || (set.distanceMeters ?? 0) > 0
                    || (set.calories ?? 0) > 0
            }
        }
    }

    private static func target(from reps: String) -> TrainingTarget {
        let trimmed = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().contains("amrap") { return .amrap }
        if trimmed.lowercased().contains("cal"), let first = RepRange.lowerBound(trimmed) { return .calories(first) }
        if trimmed.lowercased().contains("m"), let first = RepRange.lowerBound(trimmed) { return .distanceMeters(first) }
        if trimmed.lowercased().contains("s"), let first = RepRange.lowerBound(trimmed) { return .holdSeconds(first) }
        if trimmed.contains("-") || trimmed.contains("–") {
            let parts = trimmed
                .replacingOccurrences(of: "–", with: "-")
                .split(separator: "-")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count >= 2 { return .repsRange(parts[0], parts[1]) }
        }
        if let first = RepRange.lowerBound(trimmed) { return .reps(first) }
        return .amrap
    }

    private static func prescription(from exercise: Exercise) -> TrainingBlockPrescription {
        let resolved = MovementResolver.resolve(exercise.name)
        let definition = MovementCatalog.definition(for: resolved.movementId)
        let muscleGroups: [MuscleGroup]
        if let definition, !definition.muscleGroups.isEmpty {
            muscleGroups = definition.muscleGroups
        } else {
            muscleGroups = exercise.muscleGroups
        }

        return TrainingBlockPrescription(
            id: exercise.id,
            exerciseName: exercise.name,
            movementId: definition?.id,
            rankStandardMovementId: definition?.rankStandardMovementId,
            sets: exercise.sets,
            target: target(from: exercise.reps),
            restSeconds: exercise.restSeconds,
            muscleGroups: muscleGroups,
            rpe: exercise.rpe,
            notes: exercise.notes
        )
    }

    private static func uniqueMuscleGroups(_ groups: [MuscleGroup]) -> [MuscleGroup] {
        var result: [MuscleGroup] = []
        for group in groups where !result.contains(group) {
            result.append(group)
        }
        return result
    }

    private static func routinePerformanceExercises(
        from routine: RoutineDef,
        record: RoutineCompletionRecord
    ) -> [PerformanceExercise] {
        let run = RoutineRun.build(routine.steps).run
        let repTargetCount = run.filter {
            if case .repTarget = $0.kind { return true }
            return false
        }.count

        var repBursts: [Int] = []
        var totalRepCount = 0
        if case .repCount(let total, let bursts) = record.primaryMetric {
            repBursts = bursts.filter { $0 > 0 }
            totalRepCount = max(0, total)
        }

        var exercises: [PerformanceExercise] = []
        for step in run {
            switch step.kind {
            case .timed(let label, let seconds, let style):
                guard style == .work, seconds > 0 else { continue }
                exercises.append(timedRoutineExercise(name: label, seconds: seconds))

            case .interval(let label, let rounds, let segments):
                let workSegments = segments.filter { $0.seconds > 0 && !isRestLike($0.label) }
                guard rounds > 0, !workSegments.isEmpty else { continue }
                let sets = (0..<rounds).flatMap { _ in
                    workSegments.map { timedRoutineSet(name: label, seconds: $0.seconds) }
                }
                exercises.append(
                    PerformanceExercise(
                        name: cleanRoutineExerciseName(label),
                        plannedSets: sets.count,
                        plannedTarget: "Interval work",
                        sets: renumbered(sets)
                    )
                )

            case .repTarget(let name, let target, _):
                let sets: [PerformanceSet]
                if repTargetCount == 1, !repBursts.isEmpty {
                    sets = repBursts.enumerated().map { index, reps in
                        PerformanceSet(setNumber: index + 1, reps: reps)
                    }
                } else {
                    let reps = target ?? (repTargetCount == 1 ? totalRepCount : 0)
                    guard reps > 0 else { continue }
                    sets = [PerformanceSet(setNumber: 1, reps: reps)]
                }
                exercises.append(
                    PerformanceExercise(
                        name: cleanRoutineExerciseName(name),
                        plannedSets: max(1, sets.count),
                        plannedTarget: target.map { "\($0) reps" } ?? "AMRAP",
                        sets: sets
                    )
                )

            case .instruction(let text, _):
                if let exercise = instructionRoutineExercise(from: text) {
                    exercises.append(exercise)
                }

            case .circuit, .note:
                continue
            }
        }

        return exercises.filter { exercise in
            exercise.sets.contains { set in
                (set.reps ?? 0) > 0
                    || (set.holdSeconds ?? 0) > 0
                    || (set.durationSeconds ?? 0) > 0
                    || (set.distanceMeters ?? 0) > 0
                    || (set.calories ?? 0) > 0
            }
        }
    }

    private static func timedRoutineExercise(name: String, seconds: Int) -> PerformanceExercise {
        PerformanceExercise(
            name: cleanRoutineExerciseName(name),
            plannedSets: 1,
            plannedTarget: "\(seconds)s",
            sets: [timedRoutineSet(name: name, seconds: seconds)]
        )
    }

    private static func timedRoutineSet(name: String, seconds: Int) -> PerformanceSet {
        let resolved = MovementResolver.resolve(name)
        let metric = MovementCatalog.definition(for: resolved.movementId)?.defaultMetric
        if metric == .holdSeconds {
            return PerformanceSet(setNumber: 1, holdSeconds: seconds)
        }
        return PerformanceSet(setNumber: 1, durationSeconds: seconds)
    }

    private static func instructionRoutineExercise(from text: String) -> PerformanceExercise? {
        let cleaned = cleanRoutineExerciseName(text)
        let lower = cleaned.lowercased()
        let originalLower = text.lowercased()

        if lower.contains("run") || lower.contains("sprint") || lower.contains("walk") || lower.contains("jog") {
            if let meters = distanceMeters(in: originalLower) {
                let name = lower.contains("walk") ? "Walk" : "Run"
                return PerformanceExercise(
                    name: name,
                    plannedSets: 1,
                    plannedTarget: meters >= 1_000 ? "\(meters / 1_000) km" : "\(meters)m",
                    sets: [PerformanceSet(setNumber: 1, distanceMeters: meters)]
                )
            }
        }

        if lower.contains("farmer carry"), let meters = distanceMeters(in: originalLower) {
            let multiplier = repetitionMultiplier(in: originalLower) ?? 1
            return PerformanceExercise(
                name: "Farmer Carry",
                plannedSets: 1,
                plannedTarget: "\(meters * multiplier)m",
                sets: [PerformanceSet(setNumber: 1, distanceMeters: meters * multiplier)]
            )
        }

        if let parsed = repPrescription(in: cleaned) {
            return PerformanceExercise(
                name: parsed.name,
                plannedSets: 1,
                plannedTarget: "\(parsed.reps) reps",
                sets: [PerformanceSet(setNumber: 1, reps: parsed.reps)]
            )
        }

        return nil
    }

    private static func performanceSets(from entry: RoutinePerformanceEntry) -> [PerformanceSet] {
        let bursts = entry.bursts.filter { $0 > 0 }
        if !bursts.isEmpty {
            return bursts.enumerated().map { index, reps in
                PerformanceSet(
                    setNumber: index + 1,
                    reps: reps,
                    weightKg: entry.loadKg,
                    notes: entry.notes
                )
            }
        }

        guard entry.hasDirectMetric else { return [] }
        return [
            PerformanceSet(
                setNumber: 1,
                reps: entry.reps,
                weightKg: entry.loadKg,
                holdSeconds: entry.holdSeconds,
                durationSeconds: entry.durationSeconds,
                distanceMeters: entry.distanceMeters,
                calories: entry.calories,
                notes: entry.notes
            )
        ]
    }

    private static func plannedTarget(from entries: [RoutinePerformanceEntry]) -> String {
        if entries.contains(where: { !$0.bursts.isEmpty || ($0.reps ?? 0) > 0 }) {
            return "Routine reps"
        }
        if entries.contains(where: { ($0.holdSeconds ?? 0) > 0 }) {
            return "Routine hold"
        }
        if entries.contains(where: { ($0.distanceMeters ?? 0) > 0 }) {
            return "Routine distance"
        }
        if entries.contains(where: { ($0.durationSeconds ?? 0) > 0 }) {
            return "Routine time"
        }
        if entries.contains(where: { ($0.calories ?? 0) > 0 }) {
            return "Routine calories"
        }
        return "Routine work"
    }

    private static func repPrescription(in text: String) -> (name: String, reps: Int)? {
        let normalized = text.replacingOccurrences(of: "×", with: "x")
        if let range = normalized.range(of: #"(?i)\bx\s*(\d+)"#, options: .regularExpression),
           let reps = Int(normalized[range].filter(\.isNumber)) {
            let name = normalized[..<range.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-:"))
            guard !name.isEmpty else { return nil }
            return (cleanRoutineExerciseName(String(name)), reps)
        }

        if let range = normalized.range(of: #"^\s*(\d+)\s+"#, options: .regularExpression),
           let reps = Int(normalized[range].filter(\.isNumber)) {
            let name = normalized[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (cleanRoutineExerciseName(String(name)), reps)
        }

        return nil
    }

    private static func distanceMeters(in text: String) -> Int? {
        let normalized = text.replacingOccurrences(of: ",", with: "")
        guard let range = normalized.range(
            of: #"(\d+(?:\.\d+)?)\s*(km|m)\b"#,
            options: .regularExpression
        ) else { return nil }

        let match = String(normalized[range])
        let valueText = match
            .split(whereSeparator: { $0.isWhitespace || $0.isLetter })
            .first
            .map(String.init)
        guard let value = valueText.flatMap(Double.init) else { return nil }
        return match.contains("km") ? Int((value * 1_000).rounded()) : Int(value.rounded())
    }

    private static func repetitionMultiplier(in text: String) -> Int? {
        let normalized = text.replacingOccurrences(of: "×", with: "x")
        guard let range = normalized.range(
            of: #"(?i)\bx\s*(\d+)\b"#,
            options: .regularExpression
        ) else { return nil }
        return Int(normalized[range].filter(\.isNumber))
    }

    private static func cleanRoutineExerciseName(_ value: String) -> String {
        var cleaned = value
        if let range = cleaned.range(of: " — ") {
            let prefix = cleaned[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = cleaned[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerPrefix = prefix.lowercased()
            cleaned = (lowerPrefix.hasPrefix("gate") || lowerPrefix.hasPrefix("finish"))
                ? String(suffix)
                : String(prefix)
        } else if let range = cleaned.range(of: " - ") {
            cleaned = String(cleaned[..<range.lowerBound])
        }
        cleaned = cleaned
            .replacingOccurrences(of: #"(?i)\b(final|finish|gate \d+)\s*:\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s*/\s*(side|arm|leg)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.lowercased() == "db goblet squat" { return "Goblet Squat" }
        if cleaned.lowercased() == "db romanian deadlift" { return "Romanian Deadlift" }
        if cleaned.lowercased() == "db bent-over row" { return "Dumbbell Row" }
        if cleaned.lowercased() == "db shoulder press" { return "Dumbbell Shoulder Press" }
        if cleaned.lowercased() == "db chest press" { return "Dumbbell Bench Press" }
        if cleaned.lowercased() == "db curl" { return "Dumbbell Curl" }
        return cleaned
    }

    private static func isRestLike(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("rest") || lower.contains("recover") || lower.contains("cool-down")
    }

    private static func renumbered(_ sets: [PerformanceSet]) -> [PerformanceSet] {
        sets.enumerated().map { index, set in
            PerformanceSet(
                id: set.id,
                setNumber: index + 1,
                reps: set.reps,
                weightKg: set.weightKg,
                holdSeconds: set.holdSeconds,
                durationSeconds: set.durationSeconds,
                distanceMeters: set.distanceMeters,
                calories: set.calories,
                side: set.side,
                rpe: set.rpe,
                isWarmup: set.isWarmup,
                qualityFlags: set.qualityFlags,
                notes: set.notes
            )
        }
    }
}

private extension PerformanceSet {
    var hasCompletedTrainingMetric: Bool {
        positive(reps)
            || positive(holdSeconds)
            || positive(durationSeconds)
            || positive(distanceMeters)
            || positive(calories)
    }

    var hasCompletedSkillSessionMetric: Bool {
        positive(reps) || positive(holdSeconds)
    }

    private func positive(_ value: Int?) -> Bool {
        (value ?? 0) > 0
    }
}

private extension RoutinePerformanceEntry {
    var hasDirectMetric: Bool {
        (reps ?? 0) > 0
            || !bursts.filter { $0 > 0 }.isEmpty
            || (holdSeconds ?? 0) > 0
            || (durationSeconds ?? 0) > 0
            || (distanceMeters ?? 0) > 0
            || (calories ?? 0) > 0
            || (loadKg ?? 0) > 0
    }
}

private extension Array {
    var nilIfEmpty: [Element]? {
        isEmpty ? nil : self
    }
}
