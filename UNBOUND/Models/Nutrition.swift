import Foundation

struct NutritionPlan: Codable {
    var dailyCalories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var mealCount: Int
    var meals: [MealTemplate]
    var hydrationLiters: Double
    var supplements: [String]
    var notes: String
    var sourceSummary: String? = nil
    var usesEstimatedProfileDefaults: Bool? = nil
    var restDayCalories: Int
    var restDayProteinGrams: Int
    var restDayCarbsGrams: Int
    var restDayFatGrams: Int
}

extension NutritionPlan {
    var usesNutritionDefaults: Bool {
        usesEstimatedProfileDefaults == true
    }

    var confidenceLabel: String {
        usesNutritionDefaults ? "Estimate" : "Profile based"
    }

    var confidenceDetail: String {
        if let sourceSummary,
           !sourceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sourceSummary
        }
        return "Based on your profile stats, weekly training frequency, and current goal."
    }
}

struct NutritionDayTarget: Equatable, Hashable, Sendable {
    var calories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var isRestDay: Bool

    var modeLabel: String {
        isRestDay ? "Recovery day" : "Training day"
    }

    var guidanceLine: String {
        if isRestDay {
            return "Keep protein steady. Pull fuel back gently; recovery still needs food."
        }
        return "Fuel the work. Protein protects progress while carbs support the session."
    }
}

struct DayNutrition: Codable, Hashable {
    var calories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
}

struct MealTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var timing: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var examples: [String]
}

extension NutritionPlan {
    func target(for day: ProgramDay?) -> NutritionDayTarget {
        target(isRestDay: day?.isRestDay == true, override: day?.nutritionOverride)
    }

    func target(isRestDay: Bool, override: DayNutrition? = nil) -> NutritionDayTarget {
        if let override {
            return NutritionDayTarget(
                calories: override.calories,
                proteinGrams: override.proteinGrams,
                carbsGrams: override.carbsGrams,
                fatGrams: override.fatGrams,
                isRestDay: isRestDay
            )
        }

        return NutritionDayTarget(
            calories: isRestDay ? restDayCalories : dailyCalories,
            proteinGrams: isRestDay ? restDayProteinGrams : proteinGrams,
            carbsGrams: isRestDay ? restDayCarbsGrams : carbsGrams,
            fatGrams: isRestDay ? restDayFatGrams : fatGrams,
            isRestDay: isRestDay
        )
    }
}
