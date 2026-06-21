import Foundation
import Combine

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

    private func performanceBlocks() -> [PerformanceBlock] {
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

    private func durationSeconds(for exercises: [ActiveExercise]) -> Int? {
        let durations = exercises.compactMap { exercise -> Int? in
            guard let startedAt = exercise.startedAt, let completedAt = exercise.completedAt else { return nil }
            return max(0, Int(completedAt.timeIntervalSince(startedAt).rounded()))
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }
}
