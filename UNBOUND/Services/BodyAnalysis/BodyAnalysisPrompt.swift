import Foundation

enum BodyAnalysisPrompt {
    static func systemPrompt(
        archetype: Archetype,
        heightCm: Double?,
        weightKg: Double?,
        experience: TrainingExperience?,
        age: Int?,
        sex: BiologicalSex?
    ) -> String {
        let muscleGroups = MuscleGroup.allCases.map { $0.rawValue }.joined(separator: ", ")

        return """
        You are a body composition analyst specializing in physique assessment.
        You are analyzing 3 photos of a person (front, side, back) to assess
        their current physique relative to a target archetype.

        TARGET ARCHETYPE: \(archetype.displayName)
        - Primary metric: \(archetype.primaryMetric)
        - Priority muscle groups: \(archetype.priorityMuscleGroups.map(\.displayName).joined(separator: ", "))
        - Reference builds: \(archetype.animeReferences.joined(separator: ", "))

        USER CONTEXT:
        - Height: \(heightCm.map { "\(Int($0))cm" } ?? "Not provided")
        - Weight: \(weightKg.map { "\(Int($0))kg" } ?? "Not provided")
        - Training experience: \(experience?.rawValue ?? "Not provided")
        - Age: \(age.map { "\($0)" } ?? "Not provided")
        - Sex: \(sex?.rawValue ?? "Not provided")

        ASSESSMENT INSTRUCTIONS:
        1. Score each muscle group 0-100 relative to the TARGET archetype's ideal.
           Use the following muscle group identifiers exactly: \(muscleGroups).
        2. Calculate proportion ratios from visible landmarks.
        3. Estimate body composition category from visual cues. Use exactly one of:
           low, belowAverage, average, aboveAverage, high.
        4. Identify TOP 3 focus areas for maximum progress toward the archetype,
           with priority 1 being highest.
        5. Be honest but motivating. Acknowledge strengths. Frame weaknesses as opportunities.

        CRITICAL RULES:
        - Never comment on attractiveness or make judgments beyond physique.
        - If photos are unclear, note which assessments have lower confidence.
        - All scores are relative to the CHOSEN ARCHETYPE, not absolute.
        - A score of 50 means average progress toward the archetype goal.
        - A score of 100 means the muscle group matches the archetype ideal.
        - Return ONLY valid JSON matching the provided response schema.
        """
    }

    static let userPrompt = "Analyze these 3 body photos (front, side, back) against the target archetype and return the full assessment as JSON."

    // Gemini responseSchema (OpenAPI 3.0 subset). Kept as a JSON string so it
    // reads like the real schema; parsed once at call time.
    static let responseSchemaJSON: String = """
    {
      "type": "OBJECT",
      "properties": {
        "overallScore": { "type": "INTEGER", "description": "0-100 score toward target archetype" },
        "muscleAssessments": {
          "type": "ARRAY",
          "items": {
            "type": "OBJECT",
            "properties": {
              "muscleGroup": { "type": "STRING", "enum": ["chest","back","shoulders","arms","forearms","legs","glutes","core","traps","neck","lats","calves"] },
              "currentScore": { "type": "INTEGER" },
              "targetScore": { "type": "INTEGER" },
              "gap": { "type": "INTEGER" },
              "assessment": { "type": "STRING" },
              "recommendation": { "type": "STRING" }
            },
            "required": ["muscleGroup","currentScore","targetScore","gap","assessment","recommendation"]
          }
        },
        "proportions": {
          "type": "OBJECT",
          "properties": {
            "shoulderToWaistRatio": { "type": "NUMBER" },
            "chestToWaistRatio": { "type": "NUMBER" },
            "armToForearmRatio": { "type": "NUMBER" },
            "upperToLowerBodyBalance": { "type": "NUMBER" },
            "leftRightSymmetry": { "type": "NUMBER" },
            "overallProportionScore": { "type": "INTEGER" }
          },
          "required": ["overallProportionScore"]
        },
        "estimatedBodyFatPercentage": { "type": "NUMBER" },
        "estimatedMuscleMassCategory": { "type": "STRING", "enum": ["low","belowAverage","average","aboveAverage","high"] },
        "focusAreas": {
          "type": "ARRAY",
          "items": {
            "type": "OBJECT",
            "properties": {
              "muscleGroup": { "type": "STRING", "enum": ["chest","back","shoulders","arms","forearms","legs","glutes","core","traps","neck","lats","calves"] },
              "priority": { "type": "INTEGER" },
              "rationale": { "type": "STRING" },
              "suggestedFocus": { "type": "STRING" }
            },
            "required": ["muscleGroup","priority","rationale","suggestedFocus"]
          }
        },
        "summary": { "type": "STRING" },
        "strengths": { "type": "ARRAY", "items": { "type": "STRING" } },
        "weaknesses": { "type": "ARRAY", "items": { "type": "STRING" } }
      },
      "required": ["overallScore","muscleAssessments","proportions","estimatedMuscleMassCategory","focusAreas","summary","strengths","weaknesses"]
    }
    """
}

// LLM-returned shape. Service wraps it with id/scanId/userId/createdAt/targetArchetype
// before returning a BodyAnalysis.
struct BodyAnalysisLLMOutput: Decodable {
    let overallScore: Int
    let muscleAssessments: [MuscleGroupAssessment]
    let proportions: ProportionData
    let estimatedBodyFatPercentage: Double?
    let estimatedMuscleMassCategory: MuscleMassCategory
    let focusAreas: [FocusArea]
    let summary: String
    let strengths: [String]
    let weaknesses: [String]
}
