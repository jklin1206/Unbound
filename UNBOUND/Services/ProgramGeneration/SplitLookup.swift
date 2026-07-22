// UNBOUND/Services/ProgramGeneration/SplitLookup.swift
import Foundation

/// The ordered, repeating cycle of training-day templates for a training plan.
/// The scheduler tiles the cycle across training days without resetting at
/// week boundaries, so it may be shorter than a week (e.g. a continuous PPL
/// cycle at 5 days/week). Rest days are NOT included — they're scheduled
/// separately based on which weekdays the user picked.
struct Split: Equatable {
    let trainingDayTemplates: [DayTemplate]
}

/// Deterministic (buildIdentity, frequency) → Split. No AI, no dynamic branching
/// beyond the lookup. BuildIdentity decides whether to use the calisthenic
/// branch (control-primary / .specialist with control) or the weights branch (everyone else).
///
/// Calisthenic branch gated on `.primary == .control` (precision / bodyweight mastery).
enum SplitLookup {
    static func split(
        buildIdentity: BuildIdentity,
        frequency: TargetFrequency,
        trainingStyle: TrainingStyle? = nil
    ) -> Split {
        // Control-primary specialist = calisthenic branch — move your own bodyweight
        // like a weapon.
        let isCalisthenic = trainingStyle == .bodyweight
            || (buildIdentity.primary == .control && buildIdentity.shape == .specialist)
            || buildIdentity.programTemplateKey == "control"
        return Split(trainingDayTemplates: templates(isCalisthenic: isCalisthenic, frequency: frequency))
    }

    private static func templates(isCalisthenic: Bool, frequency: TargetFrequency) -> [DayTemplate] {
        switch (isCalisthenic, frequency) {
        // Calisthenic branch (control-primary specialist)
        case (true, .three):
            return [.fullBody, .fullBody, .fullBody]
        case (true, .four):
            return [.upper, .lower, .upper, .lower]
        case (true, .five):
            return [.push, .pull, .legs, .skill, .weakPoint]
        case (true, .six):
            return [.push, .pull, .legs, .push, .pull, .skill]

        // Weights branch (power, endurance, balanced, etc.)
        case (false, .three):
            return [.upper, .lower, .fullBody]
        case (false, .four):
            return [.upper, .lower, .upper, .lower]
        case (false, .five):
            // Continuous PPL cycle: the scheduler tiles templates with
            // `cursor % count` and never resets at week boundaries, so a
            // 3-template cycle at 5 days/week runs P P L P P, then L P P L P…
            return [.push, .pull, .legs]
        case (false, .six):
            return [.push, .pull, .legs, .push, .pull, .legs]
        }
    }
}
