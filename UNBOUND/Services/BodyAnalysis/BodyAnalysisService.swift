import Foundation
import UIKit

final class BodyAnalysisService: BodyAnalysisServiceProtocol, @unchecked Sendable {
    static let shared = BodyAnalysisService()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared
    private let gemini = GeminiClient.shared

    private init() {}

    func analyze(scanSession: ScanSession, photos: [ScanAngle: UIImage], userProfile: UserProfile) async throws -> BodyAnalysis {
        // 1. Compress photos in a fixed order matching the prompt (front → side → back).
        var compressed: [Data] = []
        for angle in [ScanAngle.front, .side, .back] {
            guard let image = photos[angle] else {
                throw AppError.analysisProcessingFailed(message: "Missing \(angle.rawValue) photo")
            }
            guard let data = ImageCompressor.compress(image: image) else {
                throw AppError.analysisProcessingFailed(message: "Failed to compress \(angle.rawValue) photo")
            }
            compressed.append(data)
        }

        try? await database.update(
            ["status": ScanStatus.analyzing.rawValue],
            collection: "scans",
            documentId: scanSession.id
        )

        // 2. Build prompt + schema.
        let systemPrompt = BodyAnalysisPrompt.systemPrompt(
            archetype: scanSession.targetArchetype,
            heightCm: scanSession.heightCm ?? userProfile.heightCm,
            weightKg: scanSession.weightKg ?? userProfile.weightKg,
            experience: scanSession.trainingExperience,
            age: userProfile.age,
            sex: userProfile.biologicalSex
        )
        let responseSchema: JSONValue
        do {
            responseSchema = try JSONValue.fromJSONString(BodyAnalysisPrompt.responseSchemaJSON)
        } catch {
            throw AppError.analysisProcessingFailed(message: "Invalid response schema: \(error.localizedDescription)")
        }

        // 3. Call Gemini.
        let llmOutput: BodyAnalysisLLMOutput
        do {
            llmOutput = try await gemini.generateStructured(
                BodyAnalysisLLMOutput.self,
                systemInstruction: systemPrompt,
                userText: BodyAnalysisPrompt.userPrompt,
                jpegImages: compressed,
                responseSchema: responseSchema
            )
        } catch {
            logger.log("Gemini body analysis failed", level: .error, context: ["error": error.localizedDescription])
            try? await database.update(
                ["status": ScanStatus.failed.rawValue],
                collection: "scans",
                documentId: scanSession.id
            )
            throw AppError.analysisProcessingFailed(message: error.localizedDescription)
        }

        // 4. Wrap LLM output with metadata. Match-% is intentionally not
        // surfaced — the scan logs progress toward the user's chosen archetype,
        // it does not score them against it.
        let analysis = BodyAnalysis(
            id: UUID().uuidString,
            scanId: scanSession.id,
            userId: scanSession.userId,
            createdAt: Date(),
            targetArchetype: scanSession.targetArchetype,
            overallScore: llmOutput.overallScore,
            muscleAssessments: llmOutput.muscleAssessments,
            proportions: llmOutput.proportions,
            estimatedBodyFatPercentage: llmOutput.estimatedBodyFatPercentage,
            estimatedMuscleMassCategory: llmOutput.estimatedMuscleMassCategory,
            focusAreas: llmOutput.focusAreas,
            summary: llmOutput.summary,
            strengths: llmOutput.strengths,
            weaknesses: llmOutput.weaknesses
        )

        try? await database.create(analysis, collection: "analyses", documentId: analysis.id)
        try? await database.update(
            ["analysisId": analysis.id, "status": ScanStatus.analyzed.rawValue],
            collection: "scans",
            documentId: scanSession.id
        )

        let userId = scanSession.userId
        await MainActor.run {
            BadgeService.shared.bind(userId: userId)
        }
        _ = await BadgeService.shared.evaluate(trigger: .scanComplete)

        logger.log("Body analysis complete", level: .info, context: [
            "scanId": scanSession.id,
            "score": analysis.overallScore,
            "archetype": scanSession.targetArchetype.rawValue
        ])
        return analysis
    }

    // MARK: - Recurring bi-weekly scan
    //
    // Narrow qualitative read, per `project_unbound_scan_philosophy`:
    // - Gemini gets photo + previous photo (if within 60 days) + 14-day
    //   training context + biometrics.
    // - Gemini returns 2-3 sentence narrative + one focus-area + confidence.
    // - Never numeric deltas, never deloads, never program changes.

    func analyzeScan(context: ScanContext, userId: String, photoId: String) async throws -> BodyScanAnalysis {
        let systemPrompt = BodyScanPrompt.systemPrompt
        let userPrompt = BodyScanPrompt.userPrompt(from: context)

        let schema: JSONValue
        do {
            schema = try JSONValue.fromJSONString(BodyScanPrompt.responseSchemaJSON)
        } catch {
            logger.log("Scan schema parse failed: \(error)", level: .error)
            throw BodyAnalysisError.unavailable
        }

        var images: [Data] = [context.currentScanJPEG]
        if let prev = context.previousScanJPEG {
            images.append(prev)
        }

        let llm: BodyScanLLMOutput
        do {
            llm = try await gemini.generateStructured(
                BodyScanLLMOutput.self,
                systemInstruction: systemPrompt,
                userText: userPrompt,
                jpegImages: images,
                responseSchema: schema,
                maxOutputTokens: 512,
                temperature: 0.35
            )
        } catch {
            logger.log("Bi-weekly scan Gemini call failed: \(error)", level: .warning)
            throw BodyAnalysisError.unavailable
        }

        let confidence: BodyScanAnalysis.Confidence = {
            switch llm.confidence.lowercased() {
            case "high":   return .high
            case "low":    return .low
            default:       return .medium
            }
        }()

        let scores = llm.scores.map {
            AestheticScores(
                leanness:    clamp($0.leanness),
                muscleMass:  clamp($0.muscleMass),
                definition:  clamp($0.definition),
                proportions: clamp($0.proportions),
                symmetry:    clamp($0.symmetry),
                overall:     clamp($0.overall)
            )
        }

        let analysis = BodyScanAnalysis(
            userId: userId,
            photoId: photoId,
            scores: scores,
            narrative: llm.narrative,
            focusArea: llm.focusArea,
            confidence: confidence,
            observations: llm.observations
        )

        try? await database.create(analysis, collection: "body_scan_analyses", documentId: analysis.id)

        logger.log("Bi-weekly scan analysis complete", level: .info, context: [
            "userId": userId,
            "photoId": photoId,
            "confidence": llm.confidence,
            "focusArea": llm.focusArea ?? "nil"
        ])
        return analysis
    }
}

// MARK: - Mock extension

extension MockBodyAnalysisService {
    func analyzeScan(context: ScanContext, userId: String, photoId: String) async throws -> BodyScanAnalysis {
        BodyScanAnalysis(
            userId: userId,
            photoId: photoId,
            scores: AestheticScores(
                leanness: 8, muscleMass: 7, definition: 8,
                proportions: 9, symmetry: 8, overall: 8
            ),
            narrative: "V-taper is real — shoulder-to-waist ratio is the standout, silhouette reads clean. Definition is there but lats are the ceiling right now. Lock the back in and this build jumps a level.",
            focusArea: "back",
            confidence: .high,
            observations: ["shoulder definition clearer", "lat width lagging vs chest"]
        )
    }
}

// MARK: - Gemini LLM IO (recurring scan)

private struct BodyScanLLMScores: Decodable {
    let leanness: Int
    let muscleMass: Int
    let definition: Int
    let proportions: Int
    let symmetry: Int
    let overall: Int
}

private struct BodyScanLLMOutput: Decodable {
    let scores: BodyScanLLMScores?
    let narrative: String
    let focusArea: String?
    let confidence: String
    let observations: [String]
}

private enum BodyScanPrompt {
    static let systemPrompt: String = """
    You are UNBOUND's physique judge. Score the photo honestly across six
    aesthetic dimensions, then write 2-3 sentences of coach commentary.

    SCORING CALIBRATION (1–10 integers):
    - 9–10  Elite, competition-ready, immediately striking
    - 7–8   Advanced, clearly above average, visible gains
    - 5–6   Solid, noticeable development, intermediate stage
    - 3–4   Early stage, limited visible development
    - 1–2   Beginner, very early, little visible muscle/conditioning

    SCORING RULES:
    1. SCORE WHAT YOU SEE. A visibly shredded physique earns high leanness.
       A soft build earns a low score. Do not inflate to be kind.
    2. If photo angle or quality makes a dimension unassessable, return 5.
    3. Scores are independent — a big physique can score low on leanness.
    4. No partial credit for effort, potential, or training context.

    NARRATIVE RULES:
    1. 2–3 sentences, UNBOUND coach voice — direct, no fluff.
    2. Lead with the dominant visible characteristic (strength or weakness).
    3. One honest callout on the single thing that would move the needle most.
    4. NO invented numbers, body-fat %, cm, or medical claims.
    5. If confidence is "low", say the photo made it hard to judge cleanly.

    CONFIDENCE:
    - "high"   Body clearly visible, front-facing, usable lighting
    - "medium" Partial view, heavy clothing, or moderate lighting issues
    - "low"    Photo quality prevents reliable assessment

    OUTPUT: strict JSON. Never fabricate.
    """

    static func userPrompt(from ctx: ScanContext) -> String {
        var lines: [String] = []
        lines.append("ARCHETYPE TARGET: \(ctx.archetype)")

        var bio: [String] = []
        if let h = ctx.heightCm { bio.append("\(Int(h))cm") }
        if let w = ctx.bodyweightKg { bio.append("\(Int(w))kg") }
        if let a = ctx.age { bio.append("age \(a)") }
        if let s = ctx.biologicalSex { bio.append(s) }
        if !bio.isEmpty { lines.append("BIOMETRICS: " + bio.joined(separator: " / ")) }

        lines.append("SESSIONS LAST 14 DAYS: \(ctx.sessionCount)")

        if let days = ctx.daysSinceLastScan {
            lines.append("DAYS SINCE LAST SCAN: \(days)")
            lines.append("Photo 1 is current; photo 2 is the previous scan.")
        } else {
            lines.append("FIRST SCAN — no prior photo to compare.")
        }

        lines.append("")
        lines.append("Score the current photo. Output the JSON only.")
        return lines.joined(separator: "\n")
    }

    static let responseSchemaJSON: String = """
    {
      "type": "object",
      "properties": {
        "scores": {
          "type": "object",
          "properties": {
            "leanness":    { "type": "integer" },
            "muscleMass":  { "type": "integer" },
            "definition":  { "type": "integer" },
            "proportions": { "type": "integer" },
            "symmetry":    { "type": "integer" },
            "overall":     { "type": "integer" }
          },
          "required": ["leanness", "muscleMass", "definition", "proportions", "symmetry", "overall"]
        },
        "narrative":    { "type": "string" },
        "focusArea":    { "type": "string", "nullable": true },
        "confidence":   { "type": "string", "enum": ["high", "medium", "low"] },
        "observations": { "type": "array", "items": { "type": "string" } }
      },
      "required": ["scores", "narrative", "confidence", "observations"]
    }
    """
}

private func clamp(_ n: Int) -> Int { max(1, min(10, n)) }
