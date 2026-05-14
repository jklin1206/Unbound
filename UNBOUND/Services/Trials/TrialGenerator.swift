// UNBOUND/Services/Trials/TrialGenerator.swift
import Foundation

/// Pure card generator. Inputs: user's AttributeProfile, recent log
/// history, week-start Date, ISO week number. Output: 3 TrialCards.
///
/// Deterministic given identical inputs. Aligned = profile.dominant.
/// Growth = profile.weakest. Prestige cycles per weekNumber.
@MainActor
enum TrialGenerator {

    static func cards(
        profile: AttributeProfile,
        history: [WorkoutLog],
        weekStart: Date,
        weekNumber: Int
    ) -> [TrialCard] {
        let alignedAxis = profile.dominant
        let growthAxis = profile.weakest

        return [
            makeAlignedCard(axis: alignedAxis, weekNumber: weekNumber, history: history),
            makeGrowthCard(axis: growthAxis, weekNumber: weekNumber),
            makePrestigeCard(weekNumber: weekNumber, history: history)
        ]
    }

    private static func makeAlignedCard(
        axis: AttributeKey,
        weekNumber: Int,
        history: [WorkoutLog]
    ) -> TrialCard {
        var capstone = CapstoneCatalog.perAxis[axis]!
        // Dynamic scaling for the .power capstone — bake the user's recent
        // best × 1.05 in kg.
        if axis == .power, case .autoFromLog = capstone.evaluation {
            let target = scaledWeightTarget(history: history)
            capstone = TrialCapstone(
                displayName: capstone.displayName,
                description: "Hit a working set of \(Int(target))kg or higher this weekend on a Power-axis exercise.",
                evaluation: .autoFromLog(.weightKg(target))
            )
        }
        let bronzeTitle = TitleCatalog.displayName(for: TitleID(path: .axis(axis), tier: .bronze))
        return TrialCard(
            id: "trial-W\(weekNumber)-aligned",
            kind: .aligned,
            theme: .axis(axis),
            displayName: alignedDisplayName(for: axis),
            blurb: "Lean into your \(axis.rawValue). This week's training will count toward the \(bronzeTitle) path.",
            capstone: capstone
        )
    }

    private static func makeGrowthCard(axis: AttributeKey, weekNumber: Int) -> TrialCard {
        let capstone = CapstoneCatalog.perAxis[axis]!
        return TrialCard(
            id: "trial-W\(weekNumber)-growth",
            kind: .growth,
            theme: .axis(axis),
            displayName: growthDisplayName(for: axis),
            blurb: "Push your \(axis.rawValue) — your weakest axis right now. Time to round it out.",
            capstone: capstone
        )
    }

    private static func makePrestigeCard(weekNumber: Int, history: [WorkoutLog]) -> TrialCard {
        var capstone = PrestigeCapstoneCatalog.capstone(for: weekNumber)
        // Dynamic scaling for the 1-rep PR prestige capstone.
        if capstone.displayName == "1-Rep PR Attempt" {
            let target = scaledWeightTarget(history: history)
            capstone = TrialCapstone(
                displayName: capstone.displayName,
                description: "Hit a 1-rep PR of \(Int(target))kg or higher on bench, squat, deadlift, or overhead press.",
                evaluation: .autoFromLog(.weightKg(target))
            )
        }
        return TrialCard(
            id: "trial-W\(weekNumber)-prestige",
            kind: .prestige,
            theme: .wildcard,
            displayName: "Prestige · \(capstone.displayName)",
            blurb: "A stretch challenge. Reach for it.",
            capstone: capstone
        )
    }

    // MARK: display-name authoring

    private static func alignedDisplayName(for axis: AttributeKey) -> String {
        switch axis {
        case .power:          return "Power Focus"
        case .agility:        return "Agility Focus"
        case .control:        return "Control Focus"
        case .endurance:      return "Endurance Focus"
        case .mobility:       return "Mobility Focus"
        case .explosiveness:  return "Explosiveness Focus"
        }
    }

    private static func growthDisplayName(for axis: AttributeKey) -> String {
        switch axis {
        case .power:          return "Power Push"
        case .agility:        return "Agility Push"
        case .control:        return "Control Push"
        case .endurance:      return "Endurance Push"
        case .mobility:       return "Mobility Push"
        case .explosiveness:  return "Explosiveness Push"
        }
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
