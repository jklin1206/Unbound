import Foundation

enum ArcGenerator {
    static func generateInitialArc(
        from calibrationProgram: TrainingProgram,
        startDate: Date = Date()
    ) -> TrainingProgram {
        var updated = calibrationProgram
        updated.durationDays = Arc.durationDays
        updated.days = expandToArcDays(from: calibrationProgram.days, programId: calibrationProgram.id)
        let arc = Arc(programId: calibrationProgram.id, startDate: startDate, state: .active)
        updated.arcs = [arc]
        updated.currentArcId = arc.id
        updated.rationale = ProgramRationale(
            headline: "Arc 1 ready",
            summaryCopy: "Calibration proof was converted into a 28-day Arc. The split shape is preserved and each day is tagged by session role.",
            decisions: [
                ProgramRationale.Decision(
                    inputSummary: "Calibration Week completed",
                    decisionApplied: "Started Arc 1 from the user's logged standards.",
                    iconSystemName: "calendar.badge.checkmark",
                    reasonCategory: .checkpointRecommendation,
                    revertible: false
                )
            ]
        )
        return updated
    }

    static func generateNextArc(
        from previousProgram: TrainingProgram,
        checkpoint: CheckpointOutcome?,
        startDate: Date? = nil
    ) -> TrainingProgram {
        var updated = previousProgram
        let sourceArc = previousProgram.currentArc
        let nextStart = startDate ?? sourceArc?.endDate ?? Calendar.current.date(
            byAdding: .day,
            value: previousProgram.durationDays,
            to: previousProgram.createdAt
        ) ?? previousProgram.createdAt

        let nextArc = Arc(
            programId: previousProgram.id,
            startDate: nextStart,
            state: .active,
            sourceArcID: sourceArc?.id
        )
        updated.arcs.append(nextArc)
        updated.currentArcId = nextArc.id
        updated.durationDays = Arc.durationDays
        updated.days = expandToArcDays(
            from: previousProgram.days,
            programId: previousProgram.id,
            loadBias: loadBias(for: checkpoint)
        )
        updated.rationale = rationale(for: checkpoint)
        return updated
    }

    /// Validated load-adjustment bias from a completed Checkpoint; 0 otherwise.
    private static func loadBias(for checkpoint: CheckpointOutcome?) -> Double {
        if case .completed(let signals) = checkpoint {
            return signals.loadAdjustmentBias ?? 0
        }
        return 0
    }

    private static func expandToArcDays(
        from sourceDays: [ProgramDay],
        programId: String,
        loadBias: Double = 0
    ) -> [ProgramDay] {
        guard !sourceDays.isEmpty else { return [] }
        return (1...Arc.durationDays).map { dayNumber in
            let source = sourceDays[(dayNumber - 1) % sourceDays.count]
            let workout = source.workout.map { LoadBiasApplier.apply(to: $0, bias: loadBias) }
            return ProgramDay(
                id: "\(programId)-arc-day-\(dayNumber)",
                dayNumber: dayNumber,
                label: source.label,
                isRestDay: source.isRestDay,
                workout: workout,
                sessionRole: source.isRestDay
                    ? .rest
                    : workout.map(SessionRoleTagger.role(for:)) ?? source.sessionRole,
                savedWorkoutId: source.savedWorkoutId,
                nutritionOverride: source.nutritionOverride,
                recoveryActivities: source.recoveryActivities
            )
        }
    }

    private static func rationale(for checkpoint: CheckpointOutcome?) -> ProgramRationale {
        guard let checkpoint else {
            return ProgramRationale(
                headline: "Next Arc continued",
                summaryCopy: "No Checkpoint was used, so the next Arc preserves the current structure and continues conservatively.",
                decisions: [
                    ProgramRationale.Decision(
                        category: .checkpointRecommendation,
                        inputSummary: "Checkpoint skipped",
                        iconSystemName: "arrow.forward.circle",
                        revertible: false
                    )
                ]
            )
        }

        switch checkpoint {
        case .skipped:
            return ProgramRationale(
                headline: "Next Arc continued",
                summaryCopy: "Checkpoint was skipped. Saved Workouts and custom structure were preserved.",
                decisions: [
                    ProgramRationale.Decision(
                        category: .checkpointRecommendation,
                        inputSummary: "Checkpoint skipped",
                        iconSystemName: "arrow.forward.circle",
                        revertible: false
                    )
                ]
            )
        case .completed(let signals):
            let category: ProgramRationale.ReasonCategory
            let bias = signals.loadAdjustmentBias ?? 0
            if bias < -0.05 {
                category = .loadLowered
            } else if bias > 0.05 {
                category = .loadRaised
            } else {
                category = .checkpointRecommendation
            }
            return ProgramRationale(
                headline: "Checkpoint applied",
                summaryCopy: signals.freeTextSummary ?? "Checkpoint signals were validated and converted into next-Arc guidance.",
                decisions: [
                    ProgramRationale.Decision(
                        category: category,
                        inputSummary: "Validated Checkpoint bias \(String(format: "%.2f", bias))",
                        iconSystemName: ProgramRationaleCopy.icon(for: category),
                        revertible: false
                    )
                ]
            )
        }
    }
}
