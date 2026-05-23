import Foundation

/// Pure-function macro targets derived from bodyweight, stats, training
/// frequency, and cut mode. No storage, no dependencies.
struct MacroTargets: Codable, Equatable {
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
}

enum MacroCalculator {

    /// Mifflin-St Jeor BMR × frequency-based activity factor × (0.85 if cut).
    ///
    /// Protein: 1.8 g/kg (2.2 g/kg in cut mode).
    /// Fat: 25% of calories.
    /// Carbs: whatever calories remain, clamped at 0.
    static func macros(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        frequency: TargetFrequency,
        cutMode: Bool
    ) -> MacroTargets {
        let bmr: Double
        switch sex {
        case .male:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }

        let activity: Double
        switch frequency {
        case .three: activity = 1.45
        case .four:  activity = 1.55
        case .five:  activity = 1.65
        case .six:   activity = 1.75
        }

        let tdee = bmr * activity
        let adjusted = cutMode ? tdee * 0.85 : tdee

        let proteinGPerKg = cutMode ? 2.2 : 1.8
        let proteinG = Int(round(weightKg * proteinGPerKg))
        let proteinCals = proteinG * 4

        let fatCals = Int(round(adjusted * 0.25))
        let fatG = fatCals / 9

        let remainingCals = Int(round(adjusted)) - proteinCals - fatCals
        let carbsG = max(0, remainingCals / 4)

        return MacroTargets(
            calories: Int(round(adjusted)),
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}
