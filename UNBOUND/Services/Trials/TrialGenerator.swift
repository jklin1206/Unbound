// UNBOUND/Services/Trials/TrialGenerator.swift
import Foundation

/// Pure card generator. Inputs: user's AttributeProfile, recent log
/// history, week-start Date, ISO week number. Output: 3 WeeklyVowCards.
///
/// Deterministic given identical inputs. Low Binding = recovery-safe low-day
/// work. Limit Binding = after-workout finisher. Apex Binding cycles per
/// weekNumber.
@MainActor
enum WeeklyVowGenerator {

    static func cards(
        profile: AttributeProfile,
        history: [WorkoutLog],
        weekStart: Date,
        weekNumber: Int
    ) -> [WeeklyVowCard] {
        let emberAxis = profile.weakest
        let overdriveAxis = profile.dominant

        return [
            makeEmberCard(axis: emberAxis, weekNumber: weekNumber),
            makeOverdriveCard(axis: overdriveAxis, weekNumber: weekNumber, history: history),
            makeApexCard(weekNumber: weekNumber, history: history)
        ]
    }

    private static func makeEmberCard(
        axis: AttributeKey,
        weekNumber: Int
    ) -> WeeklyVowCard {
        WeeklyVowCard(
            id: "weekly-vow-W\(weekNumber)-ember",
            kind: .ember,
            theme: .axis(axis),
            displayName: lowBindingName(for: axis),
            blurb: "Accept a low-day Binding Vow: protect recovery, sharpen \(axis.displayName.lowercased()), and keep the week alive without forcing a PR.",
            capstone: WeeklyVowProof(
                displayName: "Low-Day Proof",
                description: "Complete 8-12 minutes of easy \(axis.displayName.lowercased()) work at RPE 3-5.",
                evaluation: .liveTimer(seconds: 8 * 60, exerciseName: "\(axis.displayName.lowercased()) reset")
            ),
            prescription: WeeklyVowPrescription(
                placement: .recoveryDay,
                minMinutes: 8,
                maxMinutes: 12,
                minRPE: 3,
                maxRPE: 5
            )
        )
    }

    private static func makeOverdriveCard(
        axis: AttributeKey,
        weekNumber: Int,
        history: [WorkoutLog]
    ) -> WeeklyVowCard {
        var capstone = CapstoneCatalog.perAxis[axis]!
        // Dynamic scaling for the .power proof: bake the user's recent
        // best x 1.05 in kg.
        if axis == .power, case .autoFromLog = capstone.evaluation {
            let target = scaledWeightTarget(history: history, fallbackExerciseName: "bench press")
            capstone = WeeklyVowProof(
                displayName: capstone.displayName,
                description: "After a workout, hit \(Int(target.weightKg))kg or higher on \(target.displayName).",
                evaluation: .autoFromLog(
                    .exerciseWeightKg(target.weightKg, exerciseName: target.exerciseName)
                )
            )
        }

        return WeeklyVowCard(
            id: "weekly-vow-W\(weekNumber)-overdrive",
            kind: .overdrive,
            theme: .axis(axis),
            displayName: limitBindingName(for: axis),
            blurb: "Accept a redline Binding Vow after training: pay a short finisher cost and push your \(axis.displayName.lowercased()) output.",
            capstone: capstone,
            prescription: WeeklyVowPrescription(
                placement: .afterWorkout,
                minMinutes: 6,
                maxMinutes: 12,
                minRPE: 7,
                maxRPE: 8
            )
        )
    }

    private static func makeApexCard(weekNumber: Int, history: [WorkoutLog]) -> WeeklyVowCard {
        var capstone = PrestigeCapstoneCatalog.capstone(for: weekNumber)
        // Dynamic scaling for the 1-rep PR Apex proof.
        if capstone.displayName == "1-Rep PR Attempt" {
            let target = scaledWeightTarget(history: history, fallbackExerciseName: "deadlift")
            capstone = WeeklyVowProof(
                displayName: capstone.displayName,
                description: "Hit a 1-rep PR of \(Int(target.weightKg))kg or higher on \(target.displayName).",
                evaluation: .autoFromLog(
                    .exerciseWeightKg(target.weightKg, exerciseName: target.exerciseName)
                )
            )
        }
        return WeeklyVowCard(
            id: "weekly-vow-W\(weekNumber)-apex",
            kind: .apex,
            theme: .wildcard,
            displayName: apexBindingName(for: capstone),
            blurb: "Accept a weekend Binding Vow: one focused proof, no clutter, seal it clean.",
            capstone: capstone,
            prescription: WeeklyVowPrescription(
                placement: .dedicatedSession,
                minMinutes: 20,
                maxMinutes: 45,
                minRPE: 8,
                maxRPE: 9
            )
        )
    }

    // MARK: binding vow naming

    private static func lowBindingName(for axis: AttributeKey) -> String {
        switch axis {
        case .power: return "Iron Rule Vow"
        case .agility: return "Quiet Step Vow"
        case .control: return "Still Heart Vow"
        case .endurance: return "Last Breath Vow"
        case .mobility: return "Open Gate Vow"
        case .explosiveness: return "First Spark Vow"
        }
    }

    private static func limitBindingName(for axis: AttributeKey) -> String {
        switch axis {
        case .power: return "Limit Break Vow"
        case .agility: return "Flash Step Vow"
        case .control: return "Hollow Core Vow"
        case .endurance: return "Redline Vow"
        case .mobility: return "Flow State Vow"
        case .explosiveness: return "One Strike Vow"
        }
    }

    private static func apexBindingName(for capstone: WeeklyVowProof) -> String {
        switch capstone.displayName {
        case "Max Pull-Up AMRAP": return "No Retreat Vow"
        case "Broad Jump Distance": return "Heaven Step Vow"
        case "1-Rep PR Attempt": return "Final Set Vow"
        case "Strict Muscle-Up": return "Ascension Vow"
        case "L-Sit Hold": return "Stillness Vow"
        case "5K Sub-25": return "Blood Pace Vow"
        default: return "Final Proof Vow"
        }
    }

    // MARK: dynamic scaling

    private struct WeightTarget {
        let exerciseName: String
        let displayName: String
        let weightKg: Double
    }

    /// Compute a lift-specific target = recent best on the selected
    /// strength movement × 1.05, rounded to nearest 5kg. This keeps the
    /// proof and the generated workout pointed at the same movement instead
    /// of letting an unrelated heavy log satisfy a vow.
    private static func scaledWeightTarget(
        history: [WorkoutLog],
        fallbackExerciseName: String
    ) -> WeightTarget {
        let candidates = history
            .flatMap { $0.exerciseEntries }
            .compactMap(weightCandidate)

        if let best = candidates.max(by: { $0.weightKg < $1.weightKg }) {
            return WeightTarget(
                exerciseName: best.exerciseName,
                displayName: best.displayName,
                weightKg: roundedTarget(from: best.weightKg)
            )
        }

        let fallbackDefinition = MovementCatalog.canonicalExercise(named: fallbackExerciseName)
        return WeightTarget(
            exerciseName: fallbackDefinition?.canonicalExerciseName ?? fallbackExerciseName,
            displayName: fallbackDefinition?.displayName ?? fallbackExerciseName.capitalized,
            weightKg: roundedTarget(from: 40)
        )
    }

    private static func weightCandidate(from entry: ExerciseLogEntry) -> WeightTarget? {
        guard let bestWeight = entry.sets
            .filter({ !$0.isWarmup })
            .compactMap(\.weightKg)
            .max()
        else { return nil }

        let resolved = MovementResolver.resolve(entry.exerciseName)
        guard let definition = MovementCatalog.definition(for: resolved.movementId),
              !definition.id.hasPrefix("unresolved."),
              (definition.attributeWeights[.power] ?? 0) >= 0.20
        else { return nil }

        return WeightTarget(
            exerciseName: definition.canonicalExerciseName ?? entry.exerciseName,
            displayName: definition.displayName,
            weightKg: bestWeight
        )
    }

    private static func roundedTarget(from bestWeight: Double) -> Double {
        let raw = max(bestWeight, 40) * 1.05
        return (raw / 5.0).rounded() * 5.0
    }
}

typealias TrialGenerator = WeeklyVowGenerator
