import Foundation

// MARK: - BodyTierLoader
//
// Pulls the user's most recent BodyAnalysis and converts its per-muscle
// assessments into MuscleGroupTierState records via MuscleGroupTierCalculator.
// Lightweight read-only helper — the writer path lives in
// BodyAnalysisService (creates the analysis record on scan completion).

enum BodyTierLoader {

    /// Fetches the user's latest analysis and builds tier states for every
    /// muscle group it covers. Returns [] if the user has no analyses yet
    /// (pre-first-scan state).
    static func loadLatest(userId: String) async -> [MuscleGroupTierState] {
        let analyses: [BodyAnalysis]
        do {
            analyses = try await DatabaseService.shared.query(
                collection: "analyses",
                field: "userId",
                isEqualTo: userId,
                orderBy: "createdAt",
                descending: true,
                limit: 1
            )
        } catch {
            return []
        }
        guard let latest = analyses.first else { return [] }
        return MuscleGroupTierCalculator.compute(
            userId: userId,
            assessments: latest.muscleAssessments
        )
    }
}
