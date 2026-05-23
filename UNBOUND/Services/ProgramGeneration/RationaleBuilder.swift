// UNBOUND/Services/ProgramGeneration/RationaleBuilder.swift
import Foundation

/// Builds the user-facing "Why this program" rationale from generator inputs.
/// Pure, deterministic — no AI, no copywriting magic, just honest summaries
/// of which inputs drove which generator decisions.
enum RationaleBuilder {

    static func build(
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        split: Split
    ) -> ProgramRationale {
        var decisions: [ProgramRationale.Decision] = []

        // 1. Frequency → split
        let daysCount = input.targetFrequency.numericCount
        let splitLabels = split.trainingDayTemplates.map(\.displayLabel).joined(separator: " / ")
        decisions.append(.init(
            inputSummary: "You train \(daysCount) days/week",
            decisionApplied: "Split: \(splitLabels)",
            iconSystemName: "calendar"
        ))

        // 2. Training-day schedule
        let orderedDays = Weekday.allCases.filter(input.trainingDays.contains).map(\.short)
        if !orderedDays.isEmpty {
            decisions.append(.init(
                inputSummary: "Training days: \(orderedDays.joined(separator: ", "))",
                decisionApplied: "Scheduled workouts on those weekdays; other days rest",
                iconSystemName: "calendar.day.timeline.left"
            ))
        }

        // 3. Equipment / style
        if input.trainingStyle == .bodyweight {
            decisions.append(.init(
                inputSummary: "Bodyweight only",
                decisionApplied: "Swapped all barbell and machine work for bodyweight equivalents",
                iconSystemName: "figure.strengthtraining.traditional"
            ))
        } else if input.equipment.count == 1, let only = input.equipment.first {
            decisions.append(.init(
                inputSummary: "Equipment: \(only.displayName)",
                decisionApplied: "Filtered exercises to what you can actually do",
                iconSystemName: "wrench.and.screwdriver"
            ))
        }

        // 4. Weak-point bias
        if !bias.isEmpty {
            let ordered = bias.sorted(by: { $0.value > $1.value }).map { $0.key.displayName }
            let listed = ordered.joined(separator: " + ")
            decisions.append(.init(
                inputSummary: "Scan flagged: \(listed)",
                decisionApplied: "Added accessory volume + favored exercises that hit those groups",
                iconSystemName: "sparkles"
            ))
        }

        // 5. Cut mode
        if input.cutModeActive {
            decisions.append(.init(
                inputSummary: "Cut mode is on",
                decisionApplied: "Calories in 15% deficit, lift progression paused — preserving what you've built",
                iconSystemName: "flame"
            ))
        }

        return ProgramRationale(
            headline: "Why this program",
            summaryCopy: "Deterministic plan built from your scan, equipment, and training days.",
            decisions: decisions
        )
    }
}
