import Foundation

enum WeeklyVowTrainingBuilder {
    static func draft(for vow: WeeklyVow, date: Date) -> TrainingSessionDraft {
        let card = vow.chosenCard
        let prescriptions = prescriptions(for: card)
        let block = TrainingBlock(
            kind: blockKind(for: card),
            title: blockTitle(for: card),
            subtitle: blockSubtitle(for: card),
            skillId: skillId(for: card),
            prescriptions: prescriptions,
            notes: card.capstone.description
        )

        return TrainingSessionDraft(
            id: "weekly-vow-draft-\(vow.id)",
            userId: vow.userId,
            source: .vow,
            title: "Binding Vow - \(card.displayName)",
            date: date,
            estimatedMinutes: estimatedMinutes(for: card, prescriptions: prescriptions),
            programId: WeeklyVowTrainingRoute.programId(for: vow),
            dayNumber: 0,
            blocks: [block]
        )
    }

    static func prescriptions(for card: WeeklyVowCard) -> [TrainingBlockPrescription] {
        if case .autoFromLog(let criterion) = card.capstone.evaluation {
            return prescriptions(for: criterion, card: card)
        }

        switch card.theme {
        case .axis(let axis):
            return axisPrescriptions(axis: axis, card: card)
        case .wildcard:
            return apexCircuit(card: card)
        }
    }

    private static func prescriptions(
        for criterion: TierCriterion,
        card: WeeklyVowCard
    ) -> [TrainingBlockPrescription] {
        switch criterion {
        case .reps(let count, let exerciseName):
            let primary = makePrescription(
                exerciseName: exerciseName,
                sets: sets(for: card, fallback: 3),
                target: .reps(max(1, count)),
                restSeconds: restSeconds(for: card, fallback: 120),
                rpe: rpe(for: card),
                notes: "Log clean reps that satisfy the proof."
            )
            guard card.kind == .apex else { return [primary] }
            return Array(([primary] + apexSupport(for: exerciseName, card: card)).prefix(4))

        case .seconds(let seconds):
            return [
                makePrescription(
                    exerciseName: "Plank",
                    sets: sets(for: card, fallback: 3),
                    target: .holdSeconds(max(10, seconds)),
                    restSeconds: restSeconds(for: card, fallback: 75),
                    rpe: rpe(for: card),
                    notes: "Hold strict form for the proof duration."
                )
            ]

        case .exerciseSeconds(let seconds, let exerciseName):
            return [
                makePrescription(
                    exerciseName: displayExerciseName(exerciseName),
                    sets: sets(for: card, fallback: 3),
                    target: .holdSeconds(max(10, seconds)),
                    restSeconds: restSeconds(for: card, fallback: 75),
                    rpe: rpe(for: card),
                    notes: "Hold this movement strictly for the proof duration."
                )
            ]

        case .weightKg(let target):
            return [
                makePrescription(
                    exerciseName: "Bench Press",
                    sets: sets(for: card, fallback: 4),
                    target: .reps(1),
                    restSeconds: restSeconds(for: card, fallback: 180),
                    rpe: rpe(for: card),
                    notes: "Build toward \(Int(target.rounded()))kg or higher."
                )
            ]

        case .exerciseWeightKg(let target, let exerciseName):
            let primary = makePrescription(
                exerciseName: exerciseName,
                sets: sets(for: card, fallback: 4),
                target: .reps(1),
                restSeconds: restSeconds(for: card, fallback: 180),
                rpe: rpe(for: card),
                notes: "Build toward \(Int(target.rounded()))kg or higher on this lift."
            )
            guard card.kind == .apex else { return [primary] }
            return Array(([primary] + apexSupport(for: exerciseName, card: card)).prefix(4))

        case .bodyweightRatio(let target):
            return [
                makePrescription(
                    exerciseName: "weighted pullup",
                    sets: sets(for: card, fallback: 4),
                    target: .reps(1),
                    restSeconds: restSeconds(for: card, fallback: 180),
                    rpe: rpe(for: card),
                    notes: "Log load for a \(String(format: "%.2f", target))x bodyweight proof."
                )
            ]

        case .exerciseBodyweightRatio(let target, let exerciseName):
            return [
                makePrescription(
                    exerciseName: exerciseName,
                    sets: sets(for: card, fallback: 4),
                    target: .reps(1),
                    restSeconds: restSeconds(for: card, fallback: 180),
                    rpe: rpe(for: card),
                    notes: "Log load for a \(String(format: "%.2f", target))x bodyweight proof."
                )
            ]

        case .variant(let name):
            let primary = makePrescription(
                exerciseName: displayExerciseName(name),
                sets: sets(for: card, fallback: 3),
                target: .amrap,
                restSeconds: restSeconds(for: card, fallback: 120),
                rpe: rpe(for: card),
                notes: "Log the named movement variant for this proof."
            )
            guard card.kind == .apex else { return [primary] }
            return Array(([primary] + apexSupport(for: name, card: card)).prefix(4))

        case .compound(let criteria):
            let compound = criteria.flatMap { prescriptions(for: $0, card: card) }
            let limited = Array(compound.prefix(4))
            return limited.isEmpty ? apexCircuit(card: card) : limited
        }
    }

    private static func axisPrescriptions(
        axis: AttributeKey,
        card: WeeklyVowCard
    ) -> [TrainingBlockPrescription] {
        let easy = card.kind == .ember
        switch axis {
        case .power:
            return easy
                ? [
                    makePrescription(exerciseName: "Pushup", sets: 2, target: .repsRange(6, 10), restSeconds: 60, rpe: rpe(for: card), notes: "Easy pressing volume; leave plenty in reserve."),
                    makePrescription(exerciseName: "Plank", sets: 2, target: .holdSeconds(25), restSeconds: 45, rpe: rpe(for: card), notes: "Brace and keep the shoulders packed.")
                ]
                : [
                    makePrescription(exerciseName: "Bench Press", sets: 3, target: .repsRange(3, 5), restSeconds: 150, rpe: rpe(for: card), notes: "Crisp reps; stop before form slows."),
                    makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Heavy walk, tall posture, no rushing.")
                ]
        case .vitality:
            return easy
                ? [
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(600), restSeconds: 0, rpe: rpe(for: card), notes: "Keep it nasal-breathing easy; this is recovery, not conditioning."),
                    makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: rpe(for: card), notes: "Easy range only; leave fresher than you started.")
                ]
                : [
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(720), restSeconds: 0, rpe: rpe(for: card), notes: "Steady recovery pace before any harder work."),
                    makePrescription(exerciseName: "World's Greatest Stretch", sets: 2, target: .timedSeconds(60), restSeconds: 15, rpe: rpe(for: card), notes: "Move slowly and keep the session restorative.")
                ]
        case .control:
            return [
                makePrescription(exerciseName: easy ? "Plank" : "L-Sit (Tucked)", sets: easy ? 2 : 3, target: .holdSeconds(easy ? 30 : 20), restSeconds: easy ? 45 : 75, rpe: rpe(for: card), notes: "No position drift; stop before shape breaks."),
                makePrescription(exerciseName: "Hollow Hold", sets: easy ? 2 : 3, target: .holdSeconds(easy ? 20 : 30), restSeconds: easy ? 45 : 60, rpe: rpe(for: card), notes: "Ribs down, low back quiet.")
            ]
        case .endurance:
            return easy
                ? [
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(8 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Easy nasal pace."),
                    makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(40), restSeconds: 15, rpe: rpe(for: card), notes: "Open the stride without forcing range.")
                ]
                : [
                    makePrescription(exerciseName: "Run", sets: 1, target: .timedSeconds(10 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Sustained effort without sprinting."),
                    makePrescription(exerciseName: "Farmer Carry", sets: 2, target: .distanceMeters(40), restSeconds: 75, rpe: rpe(for: card), notes: "Finish with steady loaded breathing.")
                ]
        case .mobility:
            return [
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: easy ? 2 : 3, target: .timedSeconds(easy ? 45 : 60), restSeconds: 15, rpe: rpe(for: card), notes: "Stay in pain-free range."),
                makePrescription(exerciseName: "Thoracic Rotation", sets: easy ? 2 : 3, target: .timedSeconds(easy ? 45 : 60), restSeconds: 15, rpe: rpe(for: card), notes: "Slow reps, full breath."),
                makePrescription(exerciseName: easy ? "Hamstring Fold" : "Frog Stretch", sets: easy ? 1 : 2, target: .timedSeconds(easy ? 45 : 60), restSeconds: 15, rpe: rpe(for: card), notes: "Long exhale into the end range.")
            ]
        case .explosiveness:
            return easy
                ? [
                    makePrescription(exerciseName: "Jump Squat", sets: 3, target: .reps(4), restSeconds: 75, rpe: rpe(for: card), notes: "Low volume, every rep sharp."),
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(3 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Flush out between power exposures.")
                ]
                : [
                    makePrescription(exerciseName: "Jump Squat", sets: 4, target: .reps(3), restSeconds: 105, rpe: rpe(for: card), notes: "Reset completely between sets."),
                    makePrescription(exerciseName: "Kettlebell Swing", sets: 3, target: .repsRange(8, 10), restSeconds: 90, rpe: rpe(for: card), notes: "Hips snap, arms stay quiet.")
                ]
        }
    }

    private static func apexCircuit(card: WeeklyVowCard) -> [TrainingBlockPrescription] {
        switch card.capstone.displayName {
        case "Iron Gauntlet":
            return [
                makePrescription(exerciseName: "Bench Press", sets: 4, target: .repsRange(3, 5), restSeconds: 150, rpe: rpe(for: card), notes: "Heavy, clean reps; leave no grindy misses."),
                makePrescription(exerciseName: "Goblet Squat", sets: 4, target: .repsRange(8, 10), restSeconds: 90, rpe: rpe(for: card), notes: "Deep range, upright torso, steady tempo."),
                makePrescription(exerciseName: "Farmer Carry", sets: 4, target: .distanceMeters(40), restSeconds: 90, rpe: rpe(for: card), notes: "Heavy brace under fatigue."),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(45), restSeconds: 45, rpe: rpe(for: card), notes: "Finish with a quiet trunk.")
            ]
        case "Engine Breaker":
            return [
                makePrescription(exerciseName: "Run", sets: 1, target: .timedSeconds(15 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Hard steady effort; do not turn it into a sprint."),
                makePrescription(exerciseName: "Kettlebell Swing", sets: 4, target: .repsRange(12, 15), restSeconds: 75, rpe: rpe(for: card), notes: "Snap the hips and keep breathing controlled."),
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(40), restSeconds: 90, rpe: rpe(for: card), notes: "Loaded breathing after the engine work."),
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Cooldown and restore stride length.")
            ]
        case "Pull Crucible":
            return [
                makePrescription(exerciseName: "Pullup", sets: 5, target: .repsRange(3, 8), restSeconds: 120, rpe: rpe(for: card), notes: "Strict reps; stop each set before shape breaks."),
                makePrescription(exerciseName: "Inverted Row", sets: 4, target: .repsRange(8, 12), restSeconds: 75, rpe: rpe(for: card), notes: "Chest to handle/bar every rep."),
                makePrescription(exerciseName: "Hollow Hold", sets: 4, target: .holdSeconds(30), restSeconds: 45, rpe: rpe(for: card), notes: "Ribs down, pelvis tucked."),
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Grip finish. Walk tall.")
            ]
        case "Static Furnace":
            return [
                makePrescription(exerciseName: "L-Sit (Tucked)", sets: 5, target: .holdSeconds(15), restSeconds: 75, rpe: rpe(for: card), notes: "Accumulate clean holds with locked shoulders."),
                makePrescription(exerciseName: "Hollow Hold", sets: 4, target: .holdSeconds(35), restSeconds: 60, rpe: rpe(for: card), notes: "No rib flare, no low-back arch."),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(60), restSeconds: 60, rpe: rpe(for: card), notes: "Hard brace, quiet hips."),
                makePrescription(exerciseName: "Thoracic Rotation", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Bring the system down with clean rotation.")
            ]
        case "Impact Ladder":
            return [
                makePrescription(exerciseName: "Jump Squat", sets: 6, target: .reps(3), restSeconds: 105, rpe: rpe(for: card), notes: "Max intent; reset fully each set."),
                makePrescription(exerciseName: "Kettlebell Swing", sets: 5, target: .repsRange(8, 10), restSeconds: 90, rpe: rpe(for: card), notes: "Powerful hip snap, no soft reps."),
                makePrescription(exerciseName: "Walking Lunge", sets: 4, target: .repsRange(10, 12), restSeconds: 75, rpe: rpe(for: card), notes: "Own the landing positions under fatigue."),
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Rigid trunk to close.")
            ]
        case "Volume Blackout":
            return [
                makePrescription(exerciseName: "Pushup", sets: 5, target: .repsRange(10, 15), restSeconds: 45, rpe: rpe(for: card), notes: "Short rests. Every rep locked out."),
                makePrescription(exerciseName: "Inverted Row", sets: 5, target: .repsRange(8, 12), restSeconds: 45, rpe: rpe(for: card), notes: "Pull with the back, no hip drive."),
                makePrescription(exerciseName: "Goblet Squat", sets: 5, target: .repsRange(10, 15), restSeconds: 45, rpe: rpe(for: card), notes: "Stay tall and keep the pace honest."),
                makePrescription(exerciseName: "Plank", sets: 4, target: .holdSeconds(45), restSeconds: 45, rpe: rpe(for: card), notes: "Finish braced. No sagging.")
            ]
        default:
            return [
                makePrescription(exerciseName: "Pushup", sets: 3, target: .repsRange(8, 12), restSeconds: 45, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Inverted Row", sets: 3, target: .repsRange(6, 10), restSeconds: 45, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Goblet Squat", sets: 3, target: .repsRange(8, 12), restSeconds: 45, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(40), restSeconds: 45, rpe: rpe(for: card))
            ]
        }
    }

    private static func apexSupport(
        for proofExerciseName: String,
        card: WeeklyVowCard
    ) -> [TrainingBlockPrescription] {
        switch MovementCatalog.normalized(proofExerciseName) {
        case let name where name.contains("pullup") || name.contains("pull up"):
            return [
                makePrescription(exerciseName: "Inverted Row", sets: 3, target: .repsRange(8, 12), restSeconds: 60, rpe: rpe(for: card), notes: "Build pulling volume without burning the proof set."),
                makePrescription(exerciseName: "Hollow Hold", sets: 3, target: .holdSeconds(25), restSeconds: 45, rpe: rpe(for: card), notes: "Keep the trunk locked for strict reps.")
            ]
        case let name where name.contains("muscle up"):
            return [
                makePrescription(exerciseName: "Pull-Up", sets: 3, target: .repsRange(3, 5), restSeconds: 105, rpe: rpe(for: card), notes: "Strict pull height, no kip."),
                makePrescription(exerciseName: "Dip", sets: 3, target: .repsRange(4, 6), restSeconds: 90, rpe: rpe(for: card), notes: "Own the press-out position."),
                makePrescription(exerciseName: "Hollow Hold", sets: 2, target: .holdSeconds(30), restSeconds: 45, rpe: rpe(for: card), notes: "Keep the body line quiet.")
            ]
        case let name where name.contains("bench") || name.contains("squat") || name.contains("deadlift") || name.contains("press"):
            return [
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Heavy brace after the top set."),
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Bring the system back down.")
            ]
        case let name where name.contains("run"):
            return [
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Cooldown and restore stride length."),
                makePrescription(exerciseName: "Thoracic Rotation", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Easy breathing, no forcing.")
            ]
        default:
            return [
                makePrescription(exerciseName: "Goblet Squat", sets: 3, target: .repsRange(8, 12), restSeconds: 60, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(35), restSeconds: 45, rpe: rpe(for: card))
            ]
        }
    }

    private static func makePrescription(
        exerciseName: String,
        sets: Int,
        target: TrainingTarget,
        restSeconds: Int,
        rpe: Int?,
        notes: String? = nil
    ) -> TrainingBlockPrescription {
        let definition = catalogDefinition(named: exerciseName)
        return TrainingBlockPrescription(
            exerciseName: definition?.displayName ?? exerciseName,
            movementId: definition?.id,
            rankStandardMovementId: definition?.rankStandardMovementId,
            sets: max(1, sets),
            target: target,
            restSeconds: max(0, restSeconds),
            muscleGroups: definition?.muscleGroups ?? [],
            rpe: rpe,
            notes: notes
        )
    }

    private static func catalogDefinition(named exerciseName: String) -> MovementDefinition? {
        let normalized = MovementCatalog.normalized(exerciseName)
        let candidates = [
            catalogFallbackName(for: normalized),
            exerciseName
        ].compactMap { $0 }

        for candidate in candidates {
            let resolved = MovementResolver.resolve(candidate)
            guard let definition = MovementCatalog.definition(for: resolved.movementId),
                  !definition.id.hasPrefix("unresolved.")
            else { continue }
            return definition
        }

        return nil
    }

    private static func catalogFallbackName(for normalizedName: String) -> String? {
        // Keep Vow proof intent trainable when legacy proof names have no
        // first-class catalog row yet.
        switch normalizedName {
        case "box jump", "jumping squat":
            return "jump squat"
        case "weighted pull up":
            return "weighted pullup"
        case "strict muscle up":
            return "muscle-up"
        case "run 5k", "5k run", "5k sub 25":
            return "run"
        case "deep squat", "deep squat hold":
            return "bodyweight squat"
        case "mobility flow":
            return "hip flexor stretch"
        default:
            return nil
        }
    }

    private static func estimatedMinutes(
        for card: WeeklyVowCard,
        prescriptions: [TrainingBlockPrescription]
    ) -> Int {
        if let prescription = card.prescription {
            return max(5, (prescription.minMinutes + prescription.maxMinutes) / 2)
        }

        let seconds = prescriptions.reduce(0) { total, prescription in
            total + max(1, prescription.sets) * (45 + prescription.restSeconds)
        }
        return max(10, Int(ceil(Double(seconds) / 60.0)))
    }

    private static func blockKind(for card: WeeklyVowCard) -> TrainingBlockKind {
        if case .axis(.control) = card.theme {
            return .skill
        }
        return .custom
    }

    private static func skillId(for card: WeeklyVowCard) -> String? {
        if case .axis(.control) = card.theme {
            return "cl.hollow-body-30"
        }
        return nil
    }

    private static func blockTitle(for card: WeeklyVowCard) -> String {
        switch card.kind {
        case .ember:
            return "Recovery Vow Work"
        case .overdrive:
            return "Finisher Vow Work"
        case .apex:
            return "Limit Vow Circuit"
        }
    }

    private static func blockSubtitle(for card: WeeklyVowCard) -> String? {
        guard let prescription = card.prescription else { return card.capstone.displayName }
        return "\(prescription.summary) · \(card.capstone.displayName)"
    }

    private static func rpe(for card: WeeklyVowCard) -> Int? {
        guard let prescription = card.prescription else { return nil }
        return max(1, min(10, (prescription.minRPE + prescription.maxRPE) / 2))
    }

    private static func restSeconds(for card: WeeklyVowCard, fallback: Int) -> Int {
        switch card.kind {
        case .ember:
            return min(fallback, 75)
        case .overdrive:
            return fallback
        case .apex:
            return max(fallback, 90)
        }
    }

    private static func sets(for card: WeeklyVowCard, fallback: Int) -> Int {
        switch card.kind {
        case .ember:
            return min(fallback, 2)
        case .overdrive:
            return fallback
        case .apex:
            return max(fallback, 4)
        }
    }

    private static func displayExerciseName(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
