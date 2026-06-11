import Foundation

extension DeterministicProgramGenerator {
    static func personalizedHydrationLiters(weightKg: Double) -> Double {
        let raw = weightKg * 35 / 1_000
        let clamped = min(max(raw, 1.8), 4.5)
        return (clamped * 10).rounded() / 10
    }

    static func nutritionSourceSummary(missingFields: [String]) -> String {
        guard !missingFields.isEmpty else {
            return "Based on your profile stats, weekly training frequency, and current goal."
        }
        return "Using default \(missingFields.joined(separator: ", ")) until your profile is completed."
    }

    static func nutritionNotes(missingFields: [String]) -> String {
        if missingFields.isEmpty {
            return "Starting estimate from your profile stats and weekly training frequency. Adjust after two weeks of weigh-ins, performance, and hunger signals."
        }
        return "Temporary estimate. Complete your \(missingFields.joined(separator: ", ")) to tighten calories and macros before treating them as targets."
    }

    // MARK: — Day scheduling

    static func scheduleDays(
        split: Split,
        trainingDays: Set<Weekday>,
        blockStartDate: Date,
        durationDays: Int,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
    ) throws -> [ProgramDay] {
        let cal = Calendar(identifier: .gregorian)
        let templates = split.trainingDayTemplates
        var cursor = 0
        var result: [ProgramDay] = []

        for i in 0..<durationDays {
            guard let date = cal.date(byAdding: .day, value: i, to: blockStartDate),
                  let weekday = Weekday(from: date, calendar: cal) else {
                throw GeneratorError.unexpected("bad date math at offset \(i)")
            }
            let dayNumber = i + 1

            if trainingDays.contains(weekday) && !templates.isEmpty {
                let template = templates[cursor % templates.count]
                let sessionIndex = cursor
                cursor += 1
                let workout: Workout
                let label: String
                if input.calibration.requiresLearningWeek {
                    workout = buildCalibrationWorkout(sessionIndex: sessionIndex, input: input, bias: bias)
                    label = workout.name
                } else {
                    let blockType = blockType(forDayNumber: dayNumber, input: input)
                    workout = buildWorkout(
                        for: template,
                        input: input,
                        bias: bias,
                        blockType: blockType,
                        sessionIndex: sessionIndex
                    )
                    label = labelFor(template: template, bias: bias)
                }
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: label,
                    isRestDay: false,
                    workout: workout,
                    sessionRole: sessionRole(for: template, workout: workout),
                    nutritionOverride: nil,
                    recoveryActivities: []
                ))
            } else {
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: input.calibration.requiresLearningWeek ? "Calibration Rest" : "Rest",
                    isRestDay: true,
                    workout: nil,
                    sessionRole: .rest,
                    nutritionOverride: nil,
                    recoveryActivities: restDayActivities()
                ))
            }
        }
        return result
    }

    // MARK: — Workout building

}
