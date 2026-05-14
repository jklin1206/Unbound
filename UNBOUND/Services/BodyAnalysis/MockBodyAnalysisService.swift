import UIKit

final class MockBodyAnalysisService: BodyAnalysisServiceProtocol, @unchecked Sendable {
    func analyze(scanSession: ScanSession, photos: [ScanAngle: UIImage], userProfile: UserProfile) async throws -> BodyAnalysis {
        try await Task.sleep(for: .seconds(2))

        return BodyAnalysis(
            id: UUID().uuidString,
            scanId: scanSession.id,
            userId: scanSession.userId,
            createdAt: Date(),
            overallScore: 67,
            muscleAssessments: MuscleGroup.allCases.prefix(6).map { group in
                MuscleGroupAssessment(
                    muscleGroup: group,
                    currentScore: Int.random(in: 40...80),
                    targetScore: Int.random(in: 70...95),
                    gap: Int.random(in: 10...30),
                    assessment: "Developing",
                    recommendation: "Increase volume and progressive overload"
                )
            },
            proportions: ProportionData(
                shoulderToWaistRatio: 1.45,
                chestToWaistRatio: 1.2,
                armToForearmRatio: 1.6,
                upperToLowerBodyBalance: 0.55,
                leftRightSymmetry: 0.92,
                overallProportionScore: 65
            ),
            estimatedBodyFatPercentage: nil,
            estimatedMuscleMassCategory: .average,
            focusAreas: [
                FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "Build lateral deltoid width to widen shoulder line", suggestedFocus: "3x per week, lateral raise focus"),
                FocusArea(muscleGroup: .lats, priority: 2, rationale: "Wider lats create the V silhouette", suggestedFocus: "2x per week, pull-up progressions"),
                FocusArea(muscleGroup: .core, priority: 3, rationale: "Tight waist enhances V-taper illusion", suggestedFocus: "Daily ab work, vacuum practice")
            ],
            summary: "You have a solid foundation with good overall symmetry. Your upper body shows promising development, but the V-taper ratio needs work — primarily through wider shoulders and a more defined waist.",
            strengths: ["Good baseline symmetry", "Chest development ahead of curve"],
            weaknesses: ["Shoulder width below target", "Lat spread needs development"]
        )
    }
}
