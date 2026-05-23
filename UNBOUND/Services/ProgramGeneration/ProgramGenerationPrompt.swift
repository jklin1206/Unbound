import Foundation

// Prompt, JSON schema, and LLM-output DTO for Claude-backed program generation.
//
// Strategy: LLM produces a 7-day weekly template (varies by targetFrequency —
// e.g. 4 training days + 3 rest days). Post-processing in ProgramBuilder
// repeats the template across the 12-week program and assigns stable IDs.

enum ProgramGenerationPrompt {

    struct Inputs {
        /// BuildIdentity derived from AttributeService.
        let buildIdentity: BuildIdentity
        let targetFrequency: Int          // days/week actually wanted
        let equipment: [String]
        let experience: String
        let sessionLengthMinutes: Int
        let exerciseStyles: [String]
        let targetAreas: [String]
        let goals: [String]
        let obstacles: [String]
        let sleepQuality: Int
        let stressLevel: Int
        let commitment: Int
        let displayHandle: String
        let age: Int?
        let gender: String?
        let heightCm: Double?
        let weightKg: Double?
        // Optional — only present when generating post-scan
        let analysisSummary: String?
        let focusAreas: [String]
        let weaknesses: [String]
        let strengths: [String]
    }

    static func systemPrompt(_ inputs: Inputs) -> String {
        let handle = inputs.displayHandle.isEmpty ? "the user" : inputs.displayHandle
        var lines: [String] = []
        lines.append("You are a world-class strength coach and program designer.")
        lines.append("Design a personalized 7-day training template for \(handle).")
        lines.append("")
        // Map BuildIdentity template key to human-readable program intent for the LLM.
        lines.append("BUILD IDENTITY: \(inputs.buildIdentity.displayName)")
        lines.append("- Primary axis: \(inputs.buildIdentity.primary?.displayName ?? "Balanced")")
        lines.append("- Template key: \(inputs.buildIdentity.programTemplateKey)")
        lines.append("- Tagline: \(inputs.buildIdentity.tagline)")
        if let primary = inputs.buildIdentity.primary {
            lines.append("- Emphasis lifts: \(primary.emphasisLifts.joined(separator: ", "))")
            lines.append("- Training focus: \(primary.trainsCopy)")
        }
        lines.append("")
        lines.append("USER PROFILE")
        if let age = inputs.age { lines.append("- Age: \(age)") }
        if let gender = inputs.gender { lines.append("- Gender: \(gender)") }
        if let h = inputs.heightCm { lines.append("- Height: \(Int(h))cm") }
        if let w = inputs.weightKg { lines.append("- Weight: \(Int(w))kg") }
        lines.append("- Training experience: \(inputs.experience)")
        lines.append("- Current commitment level (1-10): \(inputs.commitment)")
        lines.append("- Sleep quality (1-10): \(inputs.sleepQuality)")
        lines.append("- Stress level (1-10): \(inputs.stressLevel)")
        lines.append("")
        lines.append("PROGRAM CONSTRAINTS")
        lines.append("- Target training days per week: \(inputs.targetFrequency)")
        lines.append("- Session length: \(inputs.sessionLengthMinutes) minutes")
        lines.append("- Available equipment: \(inputs.equipment.joined(separator: ", "))")
        if !inputs.exerciseStyles.isEmpty {
            lines.append("- Preferred styles: \(inputs.exerciseStyles.joined(separator: ", "))")
        }
        if !inputs.targetAreas.isEmpty {
            lines.append("- Target areas: \(inputs.targetAreas.joined(separator: ", "))")
        }
        if !inputs.goals.isEmpty {
            lines.append("- Goals: \(inputs.goals.joined(separator: ", "))")
        }
        if !inputs.obstacles.isEmpty {
            lines.append("- Obstacles to account for: \(inputs.obstacles.joined(separator: ", "))")
        }
        if let summary = inputs.analysisSummary {
            lines.append("")
            lines.append("BODY SCAN ANALYSIS")
            lines.append("- Summary: \(summary)")
            if !inputs.focusAreas.isEmpty { lines.append("- Focus areas: \(inputs.focusAreas.joined(separator: ", "))") }
            if !inputs.weaknesses.isEmpty { lines.append("- Weaknesses: \(inputs.weaknesses.joined(separator: ", "))") }
            if !inputs.strengths.isEmpty { lines.append("- Strengths: \(inputs.strengths.joined(separator: ", "))") }
        }
        lines.append("")
        lines.append("DESIGN RULES")
        lines.append("- Produce exactly 7 week-day entries (dayOfWeek 1 Monday → 7 Sunday).")
        lines.append("- Exactly \(inputs.targetFrequency) training days and \(7 - inputs.targetFrequency) rest days.")
        lines.append("- Training days must fit the session length; main exercises should be selectable given equipment.")
        lines.append("- Use muscleGroup enum values exactly: chest, back, shoulders, arms, forearms, legs, glutes, core, traps, neck, lats, calves.")
        lines.append("- Rest days: set isRestDay=true, workout=null, include light recovery (walk, mobility).")
        lines.append("- Programming: progressive overload-friendly rep ranges. RPE 6-9. Main lifts first, accessories after.")
        lines.append("- Obstacles and weaknesses should DIRECTLY shape exercise choice — name the obstacle in rationale decisions.")
        lines.append("")
        lines.append("RATIONALE")
        lines.append("Produce 4-6 decisions that each cite a specific user input and explain the program choice that followed from it.")
        lines.append("Use SF Symbol names for iconSystemName (e.g. figure.strengthtraining.traditional, flame, bolt.fill, moon.fill).")
        lines.append("")
        lines.append("OUTPUT")
        lines.append("Return ONLY valid JSON via the submit_program tool. Match the schema exactly.")
        return lines.joined(separator: "\n")
    }

    static let userPrompt = "Design the 7-day training template now. Be specific and personalized — every choice should trace back to the user's inputs."

    static let toolName = "submit_program"
    static let toolDescription = "Submit the generated 7-day training program, nutrition plan, recovery plan, and rationale."

    static let schemaJSON: String = """
    {
      "type": "object",
      "properties": {
        "name": { "type": "string" },
        "description": { "type": "string" },
        "difficultyLevel": { "type": "string", "enum": ["beginner","intermediate","advanced"] },
        "requiredEquipment": { "type": "array", "items": { "type": "string" } },
        "estimatedDailyMinutes": { "type": "integer" },
        "weekTemplate": {
          "type": "array",
          "description": "Exactly 7 entries, one per day Monday→Sunday",
          "items": {
            "type": "object",
            "properties": {
              "dayOfWeek": { "type": "integer", "description": "1=Monday, 7=Sunday" },
              "label": { "type": "string" },
              "isRestDay": { "type": "boolean" },
              "workout": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "targetMuscleGroups": { "type": "array", "items": { "type": "string", "enum": ["chest","back","shoulders","arms","forearms","legs","glutes","core","traps","neck","lats","calves"] } },
                  "warmup": { "type": "array", "items": { "$ref": "#/$defs/exercise" } },
                  "mainExercises": { "type": "array", "items": { "$ref": "#/$defs/exercise" } },
                  "cooldown": { "type": "array", "items": { "$ref": "#/$defs/exercise" } },
                  "estimatedMinutes": { "type": "integer" },
                  "notes": { "type": "string" }
                },
                "required": ["name","targetMuscleGroups","warmup","mainExercises","cooldown","estimatedMinutes"]
              }
            },
            "required": ["dayOfWeek","label","isRestDay"]
          }
        },
        "nutritionPlan": {
          "type": "object",
          "properties": {
            "dailyCalories": { "type": "integer" },
            "proteinGrams": { "type": "integer" },
            "carbsGrams": { "type": "integer" },
            "fatGrams": { "type": "integer" },
            "mealCount": { "type": "integer" },
            "meals": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "timing": { "type": "string" },
                  "calories": { "type": "integer" },
                  "protein": { "type": "integer" },
                  "carbs": { "type": "integer" },
                  "fat": { "type": "integer" },
                  "examples": { "type": "array", "items": { "type": "string" } }
                },
                "required": ["name","timing","calories","protein","carbs","fat","examples"]
              }
            },
            "hydrationLiters": { "type": "number" },
            "supplements": { "type": "array", "items": { "type": "string" } },
            "notes": { "type": "string" },
            "restDayCalories": { "type": "integer" },
            "restDayProteinGrams": { "type": "integer" },
            "restDayCarbsGrams": { "type": "integer" },
            "restDayFatGrams": { "type": "integer" }
          },
          "required": ["dailyCalories","proteinGrams","carbsGrams","fatGrams","mealCount","meals","hydrationLiters","supplements","notes","restDayCalories","restDayProteinGrams","restDayCarbsGrams","restDayFatGrams"]
        },
        "recoveryPlan": {
          "type": "object",
          "properties": {
            "sleepHoursTarget": { "type": "number" },
            "restDaysPerWeek": { "type": "integer" },
            "activities": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "description": { "type": "string" },
                  "durationMinutes": { "type": "integer" },
                  "frequency": { "type": "string" }
                },
                "required": ["name","description","durationMinutes","frequency"]
              }
            },
            "notes": { "type": "string" }
          },
          "required": ["sleepHoursTarget","restDaysPerWeek","activities","notes"]
        },
        "rationale": {
          "type": "object",
          "properties": {
            "headline": { "type": "string" },
            "summaryCopy": { "type": "string" },
            "decisions": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "inputSummary": { "type": "string" },
                  "decisionApplied": { "type": "string" },
                  "iconSystemName": { "type": "string" }
                },
                "required": ["inputSummary","decisionApplied","iconSystemName"]
              }
            }
          },
          "required": ["headline","summaryCopy","decisions"]
        }
      },
      "required": ["name","description","difficultyLevel","requiredEquipment","estimatedDailyMinutes","weekTemplate","nutritionPlan","recoveryPlan","rationale"],
      "$defs": {
        "exercise": {
          "type": "object",
          "properties": {
            "name": { "type": "string" },
            "muscleGroups": { "type": "array", "items": { "type": "string", "enum": ["chest","back","shoulders","arms","forearms","legs","glutes","core","traps","neck","lats","calves"] } },
            "sets": { "type": "integer" },
            "reps": { "type": "string" },
            "restSeconds": { "type": "integer" },
            "rpe": { "type": "integer" },
            "notes": { "type": "string" },
            "substitution": { "type": "string" }
          },
          "required": ["name","muscleGroups","sets","reps","restSeconds"]
        }
      }
    }
    """
}

// MARK: - DTO

struct ProgramLLMOutput: Decodable {
    let name: String
    let description: String
    let difficultyLevel: String
    let requiredEquipment: [String]
    let estimatedDailyMinutes: Int
    let weekTemplate: [WeekDayOutput]
    let nutritionPlan: NutritionPlanOutput
    let recoveryPlan: RecoveryPlanOutput
    let rationale: RationaleOutput
}

struct WeekDayOutput: Decodable {
    let dayOfWeek: Int
    let label: String
    let isRestDay: Bool
    let workout: WorkoutOutput?
}

struct WorkoutOutput: Decodable {
    let name: String
    let targetMuscleGroups: [String]
    let warmup: [ExerciseOutput]
    let mainExercises: [ExerciseOutput]
    let cooldown: [ExerciseOutput]
    let estimatedMinutes: Int
    let notes: String?
}

struct ExerciseOutput: Decodable {
    let name: String
    let muscleGroups: [String]
    let sets: Int
    let reps: String
    let restSeconds: Int
    let rpe: Int?
    let notes: String?
    let substitution: String?
}

struct NutritionPlanOutput: Decodable {
    let dailyCalories: Int
    let proteinGrams: Int
    let carbsGrams: Int
    let fatGrams: Int
    let mealCount: Int
    let meals: [MealOutput]
    let hydrationLiters: Double
    let supplements: [String]
    let notes: String
    let restDayCalories: Int
    let restDayProteinGrams: Int
    let restDayCarbsGrams: Int
    let restDayFatGrams: Int
}

struct MealOutput: Decodable {
    let name: String
    let timing: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let examples: [String]
}

struct RecoveryPlanOutput: Decodable {
    let sleepHoursTarget: Double
    let restDaysPerWeek: Int
    let activities: [RecoveryActivityOutput]
    let notes: String
}

struct RecoveryActivityOutput: Decodable {
    let name: String
    let description: String
    let durationMinutes: Int
    let frequency: String
}

struct RationaleOutput: Decodable {
    let headline: String
    let summaryCopy: String
    let decisions: [DecisionOutput]
}

struct DecisionOutput: Decodable {
    let inputSummary: String
    let decisionApplied: String
    let iconSystemName: String
}
