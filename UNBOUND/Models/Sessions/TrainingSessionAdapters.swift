import Foundation

enum TrainingSessionAdapters {
    static func draft(
        from workout: Workout,
        userId: String,
        programId: String?,
        dayNumber: Int?,
        scheduledSkillIds: [String] = [],
        scheduledSkillBlocks: [TrainingBlock] = []
    ) -> TrainingSessionDraft {
        var blocks: [TrainingBlock] = []

        if !workout.warmup.isEmpty {
            blocks.append(exerciseBlock(title: "Warmup", kind: .bodyweight, exercises: workout.warmup))
        }

        blocks.append(exerciseBlock(title: workout.name, kind: .strength, exercises: workout.mainExercises))

        let skillBlocks = scheduledSkillBlocks.isEmpty
            ? scheduledSkillIds.compactMap { skillId -> TrainingBlock? in
                guard let skill = SkillGraph.shared.node(id: skillId) else { return nil }
                return skillBlock(skillId: skill.id, title: skill.title)
            }
            : scheduledSkillBlocks
        blocks.append(contentsOf: skillBlocks)

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
        if let decision = SkillRungResolver.resolve(skillId: skillId, isTrainable: true) {
            return skillBlock(decision: decision)
        }
        return TrainingBlock(
            kind: .skill,
            title: title,
            subtitle: "Scheduled skill work",
            skillId: skillId,
            prescriptions: []
        )
    }

    static func skillBlock(decision: SkillTrainingRungDecision) -> TrainingBlock {
        let prescriptions = decision.prescriptions.prefix(3).map { prescription in
            TrainingBlockPrescription(
                exerciseName: prescription.exerciseName,
                sets: prescription.sets,
                target: TrainingTarget(prescription.target),
                restSeconds: prescription.restSeconds,
                notes: prescription.notes
            )
        }
        return TrainingBlock(
            kind: .skill,
            title: decision.targetSkillTitle,
            subtitle: decision.selectedRungTitle,
            skillId: decision.targetSkillId,
            selectedRungId: decision.selectedRungId,
            selectedRungSource: decision.source,
            selectedRungReason: decision.reason,
            prescriptions: Array(prescriptions)
        )
    }

    static func workout(from draft: TrainingSessionDraft) -> Workout {
        let exercises = draft.blocks
            .flatMap { block in
                block.prescriptions.map { prescription in
                    Exercise(
                        id: prescription.id,
                        name: prescription.exerciseName,
                        muscleGroups: prescription.muscleGroups,
                        sets: prescription.sets,
                        reps: prescription.displayTargetText,
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
                                reps: set.reps ?? 0,
                                rpe: set.rpe,
                                isWarmup: set.isWarmup,
                                durationSeconds: set.holdSeconds ?? set.durationSeconds,
                                qualityFlags: set.qualityFlags.isEmpty ? nil : set.qualityFlags,
                                notes: set.notes
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
            programId: log.programId ?? "",
            dayNumber: log.dayNumber ?? 0,
            plannedWorkoutName: log.title,
            startedAt: log.startedAt,
            completedAt: log.completedAt,
            exerciseEntries: entries,
            overallNotes: log.notes,
            overallRPE: log.overallRPE,
            durationMinutes: max(0, Int(log.completedAt.timeIntervalSince(log.startedAt) / 60)),
            localStartHour: Calendar.current.component(.hour, from: log.startedAt)
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
                        rpe: set.rpe,
                        qualityFlags: set.qualityFlags,
                        notes: set.notes
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
                id: "\(log.id):\(skillId):session",
                userId: log.userId,
                skillId: skillId,
                selectedRungId: block.selectedRungId,
                selectedRungSource: block.selectedRungSource,
                selectedRungReason: block.selectedRungReason,
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
        selectedRungId: String? = nil,
        selectedRungSource: SkillTrainingRungSource? = nil,
        selectedRungReason: String? = nil,
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
                    id: "\(id):\(skillId):block",
                    kind: .skill,
                    title: skillTitle,
                    skillId: skillId,
                    selectedRungId: selectedRungId,
                    selectedRungSource: selectedRungSource,
                    selectedRungReason: selectedRungReason,
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
                                    rpe: set.rpe,
                                    qualityFlags: set.effectiveQualityFlags,
                                    notes: set.notes
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
            notes: exercise.notes,
            suggestedWeightKg: exercise.suggestedWeightKg
        )
    }

    private static func uniqueMuscleGroups(_ groups: [MuscleGroup]) -> [MuscleGroup] {
        var result: [MuscleGroup] = []
        for group in groups where !result.contains(group) {
            result.append(group)
        }
        return result
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
