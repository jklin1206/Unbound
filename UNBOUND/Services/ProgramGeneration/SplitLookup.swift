// UNBOUND/Services/ProgramGeneration/SplitLookup.swift
import Foundation

/// The ordered sequence of training-day templates that make up one week of a
/// training plan. Rest days are NOT included — they're scheduled separately
/// based on which weekdays the user picked.
struct Split: Equatable {
    let trainingDayTemplates: [DayTemplate]
}

/// Deterministic (buildIdentity, frequency) → Split. No AI, no dynamic branching
/// beyond the lookup. BuildIdentity decides whether to use the calisthenic
/// branch (control-primary / .specialist with control) or the weights branch (everyone else).
///
/// Calisthenic branch gated on `.primary == .control` (precision / bodyweight mastery).
enum SplitLookup {
    static func split(buildIdentity: BuildIdentity, frequency: TargetFrequency) -> Split {
        // Control-primary specialist = calisthenic branch — move your own bodyweight
        // like a weapon.
        let isCalisthenic = (buildIdentity.primary == .control && buildIdentity.shape == .specialist)
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
            return [.push, .pull, .legs, .upper, .lower]
        case (false, .six):
            return [.push, .pull, .legs, .push, .pull, .legs]
        }
    }
}
