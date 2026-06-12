import Foundation

extension ActiveWorkoutSession {
    func assembleWorkoutLog(userId: String, completedAt: Date = Date()) -> WorkoutLog {
        let elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
        let adjustedStartedAt = completedAt.addingTimeInterval(-elapsedSeconds)
        let entries = exercises.map { ex in
            ExerciseLogEntry(
                id: UUID().uuidString,
                exerciseName: ex.name,
                movementId: ex.movementId,
                rankStandardMovementId: ex.rankStandardMovementId,
                plannedSets: ex.plannedSets,
                plannedReps: ex.plannedReps,
                sets: ex.sets.enumerated().compactMap { (i, set) in
                    guard set.logged else { return nil }
                    return SetLog(
                        id: set.id,
                        setNumber: i + 1,
                        weightKg: set.weightKg,
                        reps: set.reps ?? set.holdSeconds ?? set.durationSeconds ?? 0,
                        rpe: set.rpe,
                        isWarmup: set.isWarmup,
                        durationSeconds: ex.metricKind == .holdSeconds ? set.holdSeconds : (
                            ex.metricKind == .durationSeconds ? set.durationSeconds : nil
                        ),
                        qualityFlags: set.qualityFlags.isEmpty ? nil : set.qualityFlags
                    )
                },
                skipped: ex.skipped,
                notes: ex.notes.isEmpty ? nil : ex.notes
            )
        }
        return WorkoutLog(
            id: id,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            plannedWorkoutName: plannedWorkoutName,
            startedAt: adjustedStartedAt,
            completedAt: completedAt,
            exerciseEntries: entries,
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: max(0, Int(elapsedSeconds / 60)),
            localStartHour: Calendar.current.component(.hour, from: adjustedStartedAt)
        )
    }

    func assemblePerformanceLog(userId: String, completedAt: Date = Date()) -> PerformanceLog {
        let elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
        let adjustedStartedAt = completedAt.addingTimeInterval(-elapsedSeconds)
        return PerformanceLog(
            id: id,
            userId: userId,
            source: source,
            title: plannedWorkoutName,
            startedAt: adjustedStartedAt,
            completedAt: completedAt,
            programId: programId.isEmpty ? nil : programId,
            dayNumber: dayNumber,
            blocks: performanceBlocks()
        )
    }

    func performanceBlocks() -> [PerformanceBlock] {
        var orderedKeys: [String] = []
        var grouped: [String: [ActiveExercise]] = [:]

        for exercise in exercises {
            let key = exercise.blockId ?? "\(exercise.blockKind.rawValue):\(exercise.skillId ?? "")"
            if grouped[key] == nil { orderedKeys.append(key) }
            grouped[key, default: []].append(exercise)
        }

        return orderedKeys.compactMap { key in
            guard let group = grouped[key], let first = group.first else { return nil }
            let title = first.blockKind == .skill
                ? (SkillGraph.shared.node(id: first.skillId ?? "")?.title ?? first.name)
                : (first.blockTitle ?? plannedWorkoutName)
            return PerformanceBlock(
                kind: first.blockKind,
                title: title,
                skillId: first.skillId,
                selectedRungId: first.selectedRungId,
                selectedRungSource: first.selectedRungSource,
                selectedRungReason: first.selectedRungReason,
                routineId: first.routineId,
                cardioType: first.cardioType,
                exercises: group.map { exercise in
                    PerformanceExercise(
                        id: exercise.id,
                        name: exercise.name,
                        movementId: exercise.movementId,
                        rankStandardMovementId: exercise.rankStandardMovementId,
                        plannedSets: exercise.plannedSets,
                        plannedTarget: exercise.plannedReps,
                        sets: exercise.sets.enumerated().compactMap { index, set in
                            guard set.logged else { return nil }
                            return PerformanceSet(
                                id: set.id,
                                setNumber: index + 1,
                                reps: exercise.metricKind == .reps ? set.reps : nil,
                                weightKg: set.weightKg,
                                holdSeconds: exercise.metricKind == .holdSeconds ? set.holdSeconds : nil,
                                durationSeconds: exercise.metricKind == .durationSeconds ? set.durationSeconds : nil,
                                distanceMeters: exercise.metricKind == .distanceMeters ? set.distanceMeters : nil,
                                calories: exercise.metricKind == .calories ? set.calories : nil,
                                rpe: set.rpe,
                                isWarmup: set.isWarmup,
                                qualityFlags: set.qualityFlags.isEmpty ? [.clean] : set.qualityFlags
                            )
                        },
                        skipped: exercise.skipped,
                        notes: exercise.notes.isEmpty ? nil : exercise.notes
                    )
                },
                durationSeconds: durationSeconds(for: group)
            )
        }
    }

    func durationSeconds(for exercises: [ActiveExercise]) -> Int? {
        let durations = exercises.compactMap { exercise -> Int? in
            guard let startedAt = exercise.startedAt, let completedAt = exercise.completedAt else { return nil }
            return max(0, Int(completedAt.timeIntervalSince(startedAt).rounded()))
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }

    static func activeExercises(from draft: TrainingSessionDraft) -> [ActiveExercise] {
        draft.blocks.flatMap { block in
            block.prescriptions.map { prescription in
                let definition = movementDefinition(for: prescription)
                let exerciseMetricKind = prescription.target.metricKind(defaultingTo: definition?.defaultMetric)
                let setPlans = prescription.effectiveSetPlans
                return ActiveExercise(
                    id: prescription.id,
                    name: prescription.exerciseName,
                    plannedSets: setPlans.count,
                    plannedReps: prescription.setPlanSummaryText,
                    restSeconds: setPlans.first?.restSeconds ?? prescription.restSeconds,
                    muscleGroups: prescription.muscleGroups,
                    sets: setPlans.map { plan in
                        let metricKind = plan.target.metricKind(defaultingTo: definition?.defaultMetric)
                        return ActiveSet(
                            id: UUID().uuidString,
                            weightKg: nil,
                            reps: nil,
                            rpe: nil,
                            isWarmup: plan.isWarmup,
                            logged: false,
                            suggestedWeightKg: plan.suggestedWeightKg.map {
                                WeightPlatePolicy.snappedSuggestionKilograms($0)
                            },
                            suggestedReps: metricKind == .reps ? plan.target.metricLowerBound : nil,
                            suggestedHoldSeconds: metricKind == .holdSeconds ? plan.target.metricLowerBound : nil,
                            suggestedDurationSeconds: metricKind == .durationSeconds ? plan.target.metricLowerBound : nil,
                            suggestedDistanceMeters: metricKind == .distanceMeters ? plan.target.metricLowerBound : nil,
                            suggestedCalories: metricKind == .calories ? plan.target.metricLowerBound : nil,
                            suggestedRPE: plan.rpe,
                            suggestedRestSeconds: plan.restSeconds
                        )
                    },
                    skipped: false,
                    notes: draft.source == .overallRankTrial ? (prescription.notes ?? "") : "",
                    movementId: prescription.movementId,
                    rankStandardMovementId: prescription.rankStandardMovementId,
                    targetRPE: prescription.rpe,
                    formCues: prescription.notes,
                    substitution: nil,
                    blockKind: block.kind,
                    blockId: block.id,
                    blockTitle: block.title,
                    skillId: block.skillId,
                    selectedRungId: block.selectedRungId,
                    selectedRungSource: block.selectedRungSource,
                    selectedRungReason: block.selectedRungReason,
                    routineId: block.routineId,
                    cardioType: block.cardioType,
                    tracksHold: block.kind == .carry || exerciseMetricKind == .holdSeconds || exerciseMetricKind == .durationSeconds,
                    metricKind: exerciseMetricKind
                )
            }
        }
    }

    static func movementDefinition(for prescription: TrainingBlockPrescription) -> MovementDefinition? {
        if let movementId = prescription.movementId,
           let definition = MovementCatalog.definition(for: movementId) {
            return definition
        }
        let resolved = MovementResolver.resolve(prescription.exerciseName)
        return MovementCatalog.definition(for: resolved.movementId)
    }

    static func movementDefinition(for exerciseName: String) -> MovementDefinition? {
        let resolved = MovementResolver.resolve(exerciseName)
        return MovementCatalog.definition(for: resolved.movementId)
    }

    static func metricKind(
        for plannedReps: String,
        definitionDefault: TrainingMetricKind?
    ) -> TrainingMetricKind {
        let lowercased = plannedReps.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowercased.contains("cal") {
            return .calories
        }
        if lowercased.contains("meter")
            || lowercased.range(of: #"\d\s*m\b"#, options: .regularExpression) != nil {
            return .distanceMeters
        }
        if lowercased.contains("sec")
            || lowercased.contains("second")
            || lowercased.range(of: #"\d\s*s\b"#, options: .regularExpression) != nil {
            return definitionDefault == .durationSeconds ? .durationSeconds : .holdSeconds
        }
        return definitionDefault ?? .reps
    }

    static func defaultSetCount(for classification: ExerciseClassification) -> Int {
        switch classification {
        case .upperCompound, .lowerCompound, .bodyweightSkill:
            return 3
        case .accessory:
            return 2
        }
    }

    static func defaultRestSeconds(for classification: ExerciseClassification) -> Int {
        switch classification {
        case .upperCompound, .lowerCompound:
            return 120
        case .bodyweightSkill:
            return 90
        case .accessory:
            return 75
        }
    }

    static func muscleGroups(for pattern: MovementPattern) -> [MuscleGroup] {
        switch pattern {
        case .legsQuad, .legsPosterior, .calves:
            return [.legs, .glutes]
        case .pushHorizontal, .pushVertical, .arms:
            return [.chest, .shoulders, .arms]
        case .pullHorizontal, .pullVertical:
            return [.back, .arms]
        case .core:
            return [.core]
        }
    }
}
