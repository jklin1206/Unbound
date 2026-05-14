import Foundation

// MARK: - OnboardingBodyRatingService
//
// Single static call — sends the onboarding front photo to Gemini and
// gets back per-body-part scores (shoulders, chest, arms, core, legs,
// overall) + one coach line.
//
// Stricter calibration than the recurring scan: most untrained people
// should score 3-6. A 7 is genuinely impressive. 8+ is rare. No inflation.

enum OnboardingBodyRatingService {

    private static let gemini = GeminiClient.shared

    static func rate(jpeg: Data) async throws -> OnboardingBodyRatings {
        let schema: JSONValue
        do {
            schema = try JSONValue.fromJSONString(schemaJSON)
        } catch {
            throw NSError(domain: "OnboardingBodyRating", code: -1)
        }

        let result: RawOutput = try await gemini.generateStructured(
            RawOutput.self,
            systemInstruction: systemPrompt,
            userText: "Score this physique. Return JSON only.",
            jpegImages: [jpeg],
            responseSchema: schema,
            maxOutputTokens: 256,
            temperature: 0.1
        )

        return OnboardingBodyRatings(
            shoulders: clamp(result.shoulders),
            chest:     clamp(result.chest),
            arms:      clamp(result.arms),
            core:      clamp(result.core),
            legs:      clamp(result.legs),
            overall:   clamp(result.overall),
            coachLine: result.coachLine
        )
    }

    private static func clamp(_ n: Int) -> Int { max(1, min(10, n)) }

    // MARK: - Prompt

    private static let systemPrompt = """
    You are a strict physique judge for a fitness app. Score 6 body parts from the photo.

    ANCHOR POINTS — memorize these before scoring anything:
    - 5 = a completely average, untrained person. Random person at a mall. Not impressive.
    - 3 = someone who clearly never trains. Soft, no muscle visible, high body fat.
    - 7 = someone you would actually notice at a gym. Real muscle, real definition. Rare.
    - 9 = competition-ready physique. Immediately striking to anyone. Very rare.

    MOST PHOTOS YOU RECEIVE WILL SCORE 3-5. That is correct and expected.

    HARD RULES — no exceptions:
    1. No visible abs at all = core ≤ 3. Not 4, not 5. Three or below.
    2. Arms with no visible muscle separation or peak = arms ≤ 3.
    3. Shoulders with no visible deltoid capping = shoulders ≤ 4.
    4. If you cannot clearly point to visible muscle development, the score is ≤ 4.
    5. Clothing or out-of-frame body part = score 4 (unknown, not good or bad).
    6. BAGGY CLOTHES RULE: If 3 or more body parts score 4 because they are covered, overall MUST be ≤ 4. You cannot give a high overall to someone you cannot actually see. Covered ≠ impressive.
    7. overall follows the weakest areas — one soft body part drags the whole score down.
    8. Score ONLY what you can see. Never infer or imagine what might be under clothing.
    9. coachLine = ONE brutal honest sentence, ≤12 words, weakest VISIBLE point only.
    10. Before writing any score above 6, ask: would a stranger actually notice this physique? If no, lower it.

    BODY PARTS:
    - shoulders: width, roundness, visible deltoid capping
    - chest: thickness, pec shape, fullness from front
    - arms: bicep/tricep size visible from front (no separation = ≤ 3)
    - core: midsection tightness, waist, ab visibility (not visible = ≤ 3)
    - legs: quad sweep, leg development (score 4 if pants or out of frame)
    - overall: holistic first-impression — pulled down by weakest parts
    """

    // MARK: - Schema

    private static let schemaJSON = """
    {
      "type": "object",
      "properties": {
        "shoulders": { "type": "integer" },
        "chest":     { "type": "integer" },
        "arms":      { "type": "integer" },
        "core":      { "type": "integer" },
        "legs":      { "type": "integer" },
        "overall":   { "type": "integer" },
        "coachLine": { "type": "string" }
      },
      "required": ["shoulders", "chest", "arms", "core", "legs", "overall", "coachLine"]
    }
    """

    // MARK: - Raw decodable

    private struct RawOutput: Decodable {
        let shoulders: Int
        let chest: Int
        let arms: Int
        let core: Int
        let legs: Int
        let overall: Int
        let coachLine: String
    }
}
