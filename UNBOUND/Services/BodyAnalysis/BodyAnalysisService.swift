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
}
