import Foundation

@MainActor
final class SkillTrainingReviewStore {
    static let shared = SkillTrainingReviewStore()

    private var latestByUserSkill: [String: SkillTrainingAgentReview] = [:]

    private init() {}

    func cachedLatestReview(skillId: String, userId: String) -> SkillTrainingAgentReview? {
        latestByUserSkill[latestKey(userId: userId, skillId: skillId)]
    }

    func latestReview(
        skillId: String,
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> SkillTrainingAgentReview? {
        let key = latestKey(userId: userId, skillId: skillId)
        if let cached = latestByUserSkill[key] {
            return cached
        }
        guard let review: SkillTrainingAgentReview = try? await database.read(
            collection: Self.latestCollection,
            documentId: key
        ) else {
            return nil
        }
        latestByUserSkill[key] = review
        return review
    }

    func record(
        _ review: SkillTrainingAgentReview,
        database: any DatabaseServiceProtocol
    ) async throws {
        if let existing: SkillTrainingAgentReview = try? await database.read(
            collection: Self.reviewCollection,
            documentId: review.id
        ) {
            latestByUserSkill[latestKey(userId: existing.userId, skillId: existing.skillId)] = existing
            return
        }

        try await database.create(
            review,
            collection: Self.reviewCollection,
            documentId: review.id
        )
        try await database.create(
            review,
            collection: Self.latestCollection,
            documentId: latestKey(userId: review.userId, skillId: review.skillId)
        )
        latestByUserSkill[latestKey(userId: review.userId, skillId: review.skillId)] = review
    }

    private func latestKey(userId: String, skillId: String) -> String {
        "\(userId):\(skillId)"
    }

    private static let reviewCollection = "skillTrainingAgentReviews"
    private static let latestCollection = "skillTrainingLatestAgentReviews"
}
