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

        // 2. Compute BuildIdentity for prompt flavoring + analytics.
        //    AttributeService is @MainActor; hop there for the read, then
        //    carry the plain String back into this nonisolated context.
        let userId = scanSession.userId
        let buildIdentityLabel: String = await MainActor.run {
            AttributeService.shared
                .snapshot(userId: userId, asOf: .now)
                .buildIdentity.displayName
        }

        // 3. Build prompt + schema.
        let systemPrompt = BodyAnalysisPrompt.systemPrompt(
            buildIdentityLabel: buildIdentityLabel,
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

        // 4. Call Gemini.
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
        // surfaced — the scan logs progress, not a score against a fixed target.
        let analysis = BodyAnalysis(
            id: UUID().uuidString,
            scanId: scanSession.id,
            userId: scanSession.userId,
            createdAt: Date(),
            buildIdentitySnapshot: buildIdentityLabel,
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

        await MainActor.run {
            BadgeService.shared.bind(userId: userId)
        }
        _ = await BadgeService.shared.evaluate(trigger: .scanComplete)

        logger.log("Body analysis complete", level: .info, context: [
            "scanId": scanSession.id,
            "score": analysis.overallScore,
            "buildIdentity": buildIdentityLabel
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

        let analysis = BodyScanAnalysis(
            userId: userId,
            photoId: photoId,
            scores: nil,
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
            scores: nil,
            narrative: "V-taper locking in — shoulder cap sharper vs last scan. Lats are the silhouette holdback. Back deserves the spotlight this block.",
            focusArea: "back",
            confidence: .high,
            observations: ["shoulder definition clearer", "lat width lagging vs chest"]
        )
    }
}

// MARK: - Gemini LLM IO (recurring scan)

private struct BodyScanLLMOutput: Decodable {
    let narrative: String
    let focusArea: String?
    let confidence: String
    let observations: [String]
}

private enum BodyScanPrompt {
    static let systemPrompt: String = """
    You are UNBOUND's body-read coach. Given a progress photo and the user's
    training data, write 2-3 honest sentences and name one focus area.

    RULES (non-negotiable):
    1. TRAINING DATA BEATS PHOTO. If a muscle group is getting high volume
       and looks "weak" in the photo, do NOT recommend more of the same.
       Trust the logs.
    2. NO INVENTED NUMBERS. No percentages, cm, inches, body-fat %.
       Qualitative only.
    3. NO SETBACKS. Anything worse than last scan gets reframed as a focus
       area for next block. Never "regressed", "lost", "declined".
    4. NO MEDICAL CLAIMS. No health, injury, metabolism, or diet.
    5. CONSERVATIVE. If lighting/pose makes a claim uncertain, say so or
       omit. Never guess to fill space.
    6. VOICE: UNBOUND coach — direct, anime-inflected mentor. Three
       sentences maximum.
    7. STAY IN LANE. Your job is visible body read + ONE focus area.
       Do NOT recommend deloads, exercise swaps, volume changes, or any
       program intervention. Other systems handle that.

    OUTPUT: strict JSON matching the response schema. If confidence is
    "low", narrative must say so. Never fabricate.
    """

    static func userPrompt(from ctx: ScanContext) -> String {
        var lines: [String] = []
        lines.append("BUILD: \(ctx.archetype)")

        var bio: [String] = []
        if let h = ctx.heightCm { bio.append("\(Int(h))cm") }
        if let w = ctx.bodyweightKg { bio.append("\(Int(w))kg") }
        if let a = ctx.age { bio.append("age \(a)") }
        if let s = ctx.biologicalSex { bio.append(s) }
        if !bio.isEmpty { lines.append("BIOMETRICS: " + bio.joined(separator: " / ")) }

        lines.append("SESSIONS LAST 14 DAYS: \(ctx.sessionCount)")
        if !ctx.setsByMuscleGroup.isEmpty {
            let sorted = ctx.setsByMuscleGroup.sorted { $0.value > $1.value }
            let volLine = sorted.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            lines.append("VOLUME BY MUSCLE (sets): " + volLine)
        }
        if !ctx.stalledExercises.isEmpty {
            lines.append("STALLED: " + ctx.stalledExercises.joined(separator: ", "))
        }
        if !ctx.focusAreas.isEmpty {
            lines.append("USER FOCUS AREAS: " + ctx.focusAreas.joined(separator: ", "))
        }

        if let days = ctx.daysSinceLastScan {
            lines.append("DAYS SINCE LAST SCAN: \(days)")
            lines.append("Photo 1 is current; photo 2 is previous scan. Compare honestly.")
        } else {
            lines.append("FIRST RECURRING SCAN — no prior photo to compare.")
        }

        lines.append("")
        lines.append("Output the JSON only.")
        return lines.joined(separator: "\n")
    }

    static let responseSchemaJSON: String = """
    {
      "type": "object",
      "properties": {
        "narrative":    { "type": "string" },
        "focusArea":    { "type": "string", "nullable": true },
        "confidence":   { "type": "string", "enum": ["high", "medium", "low"] },
        "observations": { "type": "array", "items": { "type": "string" } }
      },
      "required": ["narrative", "confidence", "observations"]
    }
    """
}
