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
    var restDayCalories: Int
    var restDayProteinGrams: Int
    var restDayCarbsGrams: Int
    var restDayFatGrams: Int
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
