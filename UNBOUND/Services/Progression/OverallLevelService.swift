import Foundation

final class OverallLevelService {
    static let shared = OverallLevelService()

    #if DEBUG
    static func makeForTesting() -> OverallLevelService { OverallLevelService() }
    #endif

    private init() {}

    /// Last-known persisted progress per user, kept in memory so the reward
    /// preview can baseline the overall-level bar correctly (instead of from 0)
    /// when the async progression path times out.
    private var cachedProgress: [String: OverallLevelProgress] = [:]

    /// Synchronous read of the user's last-known total XP, or nil if unseen
    /// this launch. Used only by `previewProgression`.
    func cachedTotalXP(userId: String) -> Double? { cachedProgress[userId]?.totalXP }

    @discardableResult
    func ingest(
        rawAP: Double,
        noveltyMultiplier: Double,
        sourceLogId: String,
        userId: String,
        at date: Date,
        gains: [MovementAPGain] = [],
        rankUpEvents: Int = 0,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> OverallLevelReward {
        do {
            return try await ingest(
                rawAP: rawAP,
                noveltyMultiplier: noveltyMultiplier,
                sourceLogId: sourceLogId,
                userId: userId,
                at: date,
                gains: gains,
                rankUpEvents: rankUpEvents,
                database: database,
                persistenceMode: .bestEffort
            )
        } catch {
            LoggingService.shared.log(
                "Overall level best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": sourceLogId]
            )
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: noveltyMultiplier,
                previousXP: 0,
                currentXP: 0,
                previousLevel: 0,
                currentLevel: 0,
                previousProgressToNextLevel: 0,
                currentProgressToNextLevel: 0
            )
        }
    }

    @discardableResult
    func ingestStrict(
        rawAP: Double,
        noveltyMultiplier: Double,
        sourceLogId: String,
        userId: String,
        at date: Date,
        gains: [MovementAPGain] = [],
        rankUpEvents: Int = 0,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> OverallLevelReward {
        try await ingest(
            rawAP: rawAP,
            noveltyMultiplier: noveltyMultiplier,
            sourceLogId: sourceLogId,
            userId: userId,
            at: date,
            gains: gains,
            rankUpEvents: rankUpEvents,
            database: database,
            persistenceMode: .strict
        )
    }

    @discardableResult
    func grantFlatXPStrict(
        amount: Int,
        sourceId: String,
        userId: String,
        at date: Date,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> OverallLevelReward {
        try await grantFlatXP(
            amount: amount,
            sourceId: sourceId,
            userId: userId,
            at: date,
            database: database,
            persistenceMode: .strict
        )
    }

    /// Dock XP for a broken vow — the stake comes straight off the bar, clamped
    /// so it never drops you below the current level (the bar dips, you never
    /// de-level). Idempotent by sourceId. Best-effort: a failed write fails in
    /// the user's favour (no XP lost).
    @discardableResult
    func dockXP(
        amount: Int,
        sourceId: String,
        userId: String,
        at date: Date,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> OverallLevelReward {
        do {
            return try await dockXP(
                amount: amount,
                sourceId: sourceId,
                userId: userId,
                at: date,
                database: database,
                persistenceMode: .bestEffort
            )
        } catch {
            LoggingService.shared.log(
                "Overall level XP dock failed: \(error)",
                level: .warning,
                context: ["sourceId": sourceId]
            )
            return OverallLevelReward(
                xpGained: 0, noveltyMultiplier: 1.0,
                previousXP: 0, currentXP: 0,
                previousLevel: 0, currentLevel: 0,
                previousProgressToNextLevel: 0, currentProgressToNextLevel: 0
            )
        }
    }

    private func ingest(
        rawAP: Double,
        noveltyMultiplier: Double,
        sourceLogId: String,
        userId: String,
        at date: Date,
        gains: [MovementAPGain],
        rankUpEvents: Int,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> OverallLevelReward {
        var progress = await loadProgress(userId: userId, database: database)
        let previousXP = progress.totalXP
        let previousLevel = progress.level
        let previousProgress = progress.progressToNextLevel

        // Velocity layer: when the per-movement gains are supplied, weight LV by
        // each movement's skill + compound factors instead of crediting flat
        // volume. Falls back to the scalar `rawAP` for callers that don't pass
        // gains (previews, legacy paths).
        let effectiveAP = gains.isEmpty
            ? rawAP
            : VelocityWeighting.weightedAP(gains: gains)
        let bolus = VelocityWeighting.rankUpBolus(rankUpEvents: rankUpEvents)

        if progress.processedSourceLogIds.contains(sourceLogId) {
            if persistenceMode == .strict {
                return progress.processedSourceRewards[sourceLogId]
                    ?? duplicateReward(
                        from: progress,
                        noveltyMultiplier: noveltyMultiplier
                    )
            }
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: noveltyMultiplier,
                previousXP: previousXP,
                currentXP: previousXP,
                previousLevel: previousLevel,
                currentLevel: previousLevel,
                previousProgressToNextLevel: previousProgress,
                currentProgressToNextLevel: previousProgress
            )
        }

        guard effectiveAP > 0 || bolus > 0 else {
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: noveltyMultiplier,
                previousXP: previousXP,
                currentXP: previousXP,
                previousLevel: previousLevel,
                currentLevel: previousLevel,
                previousProgressToNextLevel: previousProgress,
                currentProgressToNextLevel: previousProgress
            )
        }

        // Comeback bonus only applies to a returning user (a prior session
        // exists); a first-ever session is always neutral.
        let comeback: Double = {
            guard !progress.processedSourceLogIds.isEmpty else { return 1.0 }
            let days = max(0, date.timeIntervalSince(progress.updatedAt)) / 86_400
            return VelocityWeighting.comebackMultiplier(daysSinceLastSession: days)
        }()

        let xpGained = RewardLedgerQuantizer.wholePoints(
            from: effectiveAP * max(1.0, noveltyMultiplier) * comeback
        ) + bolus
        progress.apply(xpGained: xpGained, sourceLogId: sourceLogId, at: date)

        let reward = OverallLevelReward(
            xpGained: xpGained,
            noveltyMultiplier: noveltyMultiplier,
            previousXP: previousXP,
            currentXP: progress.totalXP,
            previousLevel: previousLevel,
            currentLevel: progress.level,
            previousProgressToNextLevel: previousProgress,
            currentProgressToNextLevel: progress.progressToNextLevel
        )
        progress.processedSourceRewards[sourceLogId] = reward
        try await persistOverallProgress(
            progress,
            database: database,
            persistenceMode: persistenceMode
        )
        cachedProgress[userId] = progress

        NotificationCenter.default.post(
            name: .overallLevelProgressUpdated,
            object: reward,
            userInfo: ["progress": progress]
        )

        return reward
    }

    private func grantFlatXP(
        amount: Int,
        sourceId: String,
        userId: String,
        at date: Date,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> OverallLevelReward {
        var progress = await loadProgress(userId: userId, database: database)
        let previousXP = progress.totalXP
        let previousLevel = progress.level
        let previousProgress = progress.progressToNextLevel

        if progress.processedSourceLogIds.contains(sourceId) {
            if persistenceMode == .strict {
                return progress.processedSourceRewards[sourceId]
                    ?? duplicateReward(from: progress, noveltyMultiplier: 1.0)
            }
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: 1.0,
                previousXP: previousXP,
                currentXP: previousXP,
                previousLevel: previousLevel,
                currentLevel: previousLevel,
                previousProgressToNextLevel: previousProgress,
                currentProgressToNextLevel: previousProgress
            )
        }

        let xpGained = RewardLedgerQuantizer.wholePoints(from: Double(amount))
        guard xpGained > 0 else {
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: 1.0,
                previousXP: previousXP,
                currentXP: previousXP,
                previousLevel: previousLevel,
                currentLevel: previousLevel,
                previousProgressToNextLevel: previousProgress,
                currentProgressToNextLevel: previousProgress
            )
        }

        progress.apply(xpGained: xpGained, sourceLogId: sourceId, at: date)
        let reward = OverallLevelReward(
            xpGained: xpGained,
            noveltyMultiplier: 1.0,
            previousXP: previousXP,
            currentXP: progress.totalXP,
            previousLevel: previousLevel,
            currentLevel: progress.level,
            previousProgressToNextLevel: previousProgress,
            currentProgressToNextLevel: progress.progressToNextLevel
        )
        progress.processedSourceRewards[sourceId] = reward
        try await persistOverallProgress(
            progress,
            database: database,
            persistenceMode: persistenceMode
        )
        cachedProgress[userId] = progress

        NotificationCenter.default.post(
            name: .overallLevelProgressUpdated,
            object: reward,
            userInfo: ["progress": progress]
        )

        return reward
    }

    private func dockXP(
        amount: Int,
        sourceId: String,
        userId: String,
        at date: Date,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> OverallLevelReward {
        var progress = await loadProgress(userId: userId, database: database)
        let previousXP = progress.totalXP
        let previousLevel = progress.level
        let previousProgress = progress.progressToNextLevel

        let removed = progress.applyDock(amount: Double(amount), sourceLogId: sourceId, at: date)
        let reward = OverallLevelReward(
            xpGained: -removed,
            noveltyMultiplier: 1.0,
            previousXP: previousXP,
            currentXP: progress.totalXP,
            previousLevel: previousLevel,
            currentLevel: progress.level,
            previousProgressToNextLevel: previousProgress,
            currentProgressToNextLevel: progress.progressToNextLevel
        )
        // Nothing removed (already processed, or already at the level floor) —
        // no write needed.
        guard removed > 0 else { return reward }

        progress.processedSourceRewards[sourceId] = reward
        try await persistOverallProgress(
            progress,
            database: database,
            persistenceMode: persistenceMode
        )
        cachedProgress[userId] = progress

        NotificationCenter.default.post(
            name: .overallLevelProgressUpdated,
            object: reward,
            userInfo: ["progress": progress]
        )

        return reward
    }

    private func duplicateReward(
        from progress: OverallLevelProgress,
        noveltyMultiplier: Double
    ) -> OverallLevelReward {
        let xpGained = max(0, progress.lastGainedXP)
        let previousXP = max(0, progress.totalXP - xpGained)
        return OverallLevelReward(
            xpGained: xpGained,
            noveltyMultiplier: noveltyMultiplier,
            previousXP: previousXP,
            currentXP: progress.totalXP,
            previousLevel: OverallLevelCurve.level(forXP: previousXP),
            currentLevel: progress.level,
            previousProgressToNextLevel: OverallLevelCurve.progressFraction(forXP: previousXP),
            currentProgressToNextLevel: progress.progressToNextLevel
        )
    }

    private func persistOverallProgress(
        _ progress: OverallLevelProgress,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws {
        switch persistenceMode {
        case .strict:
            try await database.create(
                progress,
                collection: "overall_level_progress",
                documentId: progress.id
            )
        case .bestEffort:
            do {
                try await database.create(
                    progress,
                    collection: "overall_level_progress",
                    documentId: progress.id
                )
            } catch {
                LoggingService.shared.log(
                    "Overall level progress write failed: \(error)",
                    level: .warning,
                    context: ["documentId": progress.id]
                )
            }
        }
    }

    private func loadProgress(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> OverallLevelProgress {
        if let existing: OverallLevelProgress = try? await database.read(
            collection: "overall_level_progress",
            documentId: userId
        ) {
            cachedProgress[userId] = existing
            return existing
        }

        let fresh = OverallLevelProgress(userId: userId)
        cachedProgress[userId] = fresh
        return fresh
    }
}
