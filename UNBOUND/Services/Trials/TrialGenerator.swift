// UNBOUND/Services/Trials/TrialGenerator.swift
import Foundation

/// Pure card generator. Inputs: user's AttributeProfile, recent log
/// history, week-start Date, ISO week number. Output: 3 WeeklyVowCards.
///
/// Deterministic given identical inputs. Ember = recovery-safe low-day work.
/// Overdrive = after-workout finisher. Apex cycles per weekNumber.
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
            displayName: "Ember · \(axis.displayName) Reset",
            blurb: "Keep the streak warm with recovery-safe work for your \(axis.displayName.lowercased()) axis.",
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
            let target = scaledWeightTarget(history: history)
            capstone = WeeklyVowProof(
                displayName: capstone.displayName,
                description: "After a workout, hit a working set of \(Int(target))kg or higher on a Power-axis exercise.",
                evaluation: .autoFromLog(.weightKg(target))
            )
        }

        return WeeklyVowCard(
            id: "weekly-vow-W\(weekNumber)-overdrive",
            kind: .overdrive,
            theme: .axis(axis),
            displayName: "Overdrive · \(axis.displayName) Finisher",
            blurb: "Attach a sharp finisher after training and push your \(axis.displayName.lowercased()) output.",
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
            let target = scaledWeightTarget(history: history)
            capstone = WeeklyVowProof(
                displayName: capstone.displayName,
                description: "Hit a 1-rep PR of \(Int(target))kg or higher on bench, squat, deadlift, or overhead press.",
                evaluation: .autoFromLog(.weightKg(target))
            )
        }
        return WeeklyVowCard(
            id: "weekly-vow-W\(weekNumber)-apex",
            kind: .apex,
            theme: .wildcard,
            displayName: "Apex · \(capstone.displayName)",
            blurb: "Set aside a focused weekend session and chase a bigger proof.",
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

    // MARK: dynamic scaling

    /// Compute a weight target = user's recent best across all logged
    /// non-warmup sets × 1.05, rounded to nearest 5kg. Falls back to 40kg
    /// for new users.
    private static func scaledWeightTarget(history: [WorkoutLog]) -> Double {
        let bestWeight = history
            .flatMap { $0.exerciseEntries }
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { $0.weightKg }
            .max() ?? 0

        let baseline: Double = 40
        let raw = max(bestWeight, baseline) * 1.05
        return (raw / 5.0).rounded() * 5.0
    }
}

typealias TrialGenerator = WeeklyVowGenerator
