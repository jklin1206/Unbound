import Foundation

final class BodyMapProgressService {
    static let shared = BodyMapProgressService()

    private static let recentHalfLifeSeconds: TimeInterval = 14 * 24 * 60 * 60
    private static let recentFullSaturationLoad: Double = 500
    private static let lifetimeFullSaturationLoad: Double = 5_000
    private static let maxLifetimeBaseline: Double = 0.2

    private init() {}

    /// Last-known body-map profile per user, kept in memory so the reward
    /// preview can compute the real region-novelty multiplier (instead of a flat
    /// 1.0) when the async progression path times out.
    private var cachedProfiles: [String: BodyMapProfile] = [:]

    /// Synchronous novelty multiplier from the user's last-known profile, for
    /// `previewProgression`. Returns the neutral 1.0 if unseen this launch.
    func previewNoveltyMultiplier(for regions: [BodyRegion], userId: String, at date: Date) -> Double {
        guard let profile = cachedProfiles[userId] else { return 1.0 }
        return noveltyMultiplier(for: regions, profile: profile, at: date)
    }

    func profile(
        userId: String,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> BodyMapProfile {
        await loadProfile(userId: userId, database: database)
    }

    @discardableResult
    func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        at date: Date,
        trainingLoads: [BodyRegionTrainingLoad] = [],
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> BodyMapIngestResult {
        do {
            return try await ingest(
                movementAPGains: gains,
                userId: userId,
                sourceLogId: sourceLogId,
                at: date,
                trainingLoads: trainingLoads,
                database: database,
                persistenceMode: .bestEffort
            )
        } catch {
            LoggingService.shared.log(
                "Body-map best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": sourceLogId]
            )
            return BodyMapIngestResult()
        }
    }

    @discardableResult
    func ingestStrict(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        at date: Date,
        trainingLoads: [BodyRegionTrainingLoad] = [],
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> BodyMapIngestResult {
        try await ingest(
            movementAPGains: gains,
            userId: userId,
            sourceLogId: sourceLogId,
            at: date,
            trainingLoads: trainingLoads,
            database: database,
            persistenceMode: .strict
        )
    }

    private func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        at date: Date,
        trainingLoads: [BodyRegionTrainingLoad],
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> BodyMapIngestResult {
        guard !gains.isEmpty || !trainingLoads.isEmpty else { return BodyMapIngestResult() }

        var profile = await loadProfile(userId: userId, database: database)
        if profile.processedSourceLogIds.contains(sourceLogId) {
            if persistenceMode == .strict {
                if let receipt = await loadPersistedBodyMapReceipt(
                    sourceLogId: sourceLogId,
                    database: database
                ) {
                    return receipt.result
                }
                return duplicateResult(
                    from: profile,
                    gains: gains,
                    trainingLoads: trainingLoads,
                    at: date
                )
            }
            return BodyMapIngestResult(wasDuplicate: true)
        }

        let loadsByRegion = regionLoads(from: gains, trainingLoads: trainingLoads)
        let trainingLoadsByRegion = mergedTrainingLoads(trainingLoads)
        let novelty = noveltyMultiplier(for: Array(loadsByRegion.keys), profile: profile, at: date)
        var rewards: [BodyMapRegionReward] = []

        for (region, loadAdded) in loadsByRegion {
            var load = profile.load(for: region)
            let decayFactor = recentDecayFactor(for: load, at: date)
            load.recentLoad = load.recentLoad * decayFactor + loadAdded
            load.lifetimeLoad += loadAdded
            load.decayRecentRoleSets(by: decayFactor)
            if let trainingLoad = trainingLoadsByRegion[region] {
                load.addRecentRoleSets(trainingLoad)
            }
            load.lastTrainedAt = date
            profile.setLoad(load, for: region)
            rewards.append(
                BodyMapRegionReward(
                    region: region,
                    loadAdded: (loadAdded * 10).rounded() / 10,
                    recentLoad: (load.recentLoad * 10).rounded() / 10,
                    lifetimeLoad: (load.lifetimeLoad * 10).rounded() / 10,
                    lastTrainedAt: date
                )
            )
        }

        if !profile.processedSourceLogIds.contains(sourceLogId) {
            profile.processedSourceLogIds.append(sourceLogId)
        }
        if profile.processedSourceLogIds.count > 250 {
            profile.processedSourceLogIds.removeFirst(profile.processedSourceLogIds.count - 250)
        }
        profile.updatedAt = date

        let result = BodyMapIngestResult(
            noveltyMultiplier: novelty,
            regionRewards: rewards.sorted { $0.region.rawValue < $1.region.rawValue },
            wasDuplicate: false
        )

        if persistenceMode == .strict {
            try await database.create(
                BodyMapSourceReceipt(
                    sourceLogId: sourceLogId,
                    userId: userId,
                    noveltyMultiplier: result.noveltyMultiplier,
                    regionRewards: result.regionRewards
                ),
                collection: "body_map_source_receipts",
                documentId: sourceLogId
            )
        }

        try await persistBodyMapProfile(
            profile,
            database: database,
            persistenceMode: persistenceMode
        )
        cachedProfiles[userId] = profile

        if !rewards.isEmpty {
            NotificationCenter.default.post(
                name: .bodyMapProgressUpdated,
                object: result,
                userInfo: ["profile": profile]
            )
        }

        return result
    }

    private func loadPersistedBodyMapReceipt(
        sourceLogId: String,
        database: any DatabaseServiceProtocol
    ) async -> BodyMapSourceReceipt? {
        try? await database.read(
            collection: "body_map_source_receipts",
            documentId: sourceLogId
        )
    }

    private func persistBodyMapProfile(
        _ profile: BodyMapProfile,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws {
        switch persistenceMode {
        case .strict:
            try await database.create(
                profile,
                collection: "body_map_profiles",
                documentId: profile.id
            )
        case .bestEffort:
            do {
                try await database.create(
                    profile,
                    collection: "body_map_profiles",
                    documentId: profile.id
                )
            } catch {
                LoggingService.shared.log(
                    "Body-map profile write failed: \(error)",
                    level: .warning,
                    context: ["documentId": profile.id]
                )
            }
        }
    }

    private func duplicateResult(
        from profile: BodyMapProfile,
        gains: [MovementAPGain],
        trainingLoads: [BodyRegionTrainingLoad],
        at date: Date
    ) -> BodyMapIngestResult {
        let loadsByRegion = regionLoads(from: gains, trainingLoads: trainingLoads)
        guard !loadsByRegion.isEmpty else {
            return BodyMapIngestResult(wasDuplicate: true)
        }

        var approximatePrior = profile
        for (region, loadAdded) in loadsByRegion {
            var load = approximatePrior.load(for: region)
            load.recentLoad = max(0, load.recentLoad - loadAdded)
            load.lifetimeLoad = max(0, load.lifetimeLoad - loadAdded)
            approximatePrior.setLoad(load, for: region)
        }
        let novelty = noveltyMultiplier(
            for: Array(loadsByRegion.keys),
            profile: approximatePrior,
            at: date
        )

        let rewards = loadsByRegion.map { region, loadAdded in
            let load = profile.load(for: region)
            return BodyMapRegionReward(
                region: region,
                loadAdded: (loadAdded * 10).rounded() / 10,
                recentLoad: (load.recentLoad * 10).rounded() / 10,
                lifetimeLoad: (load.lifetimeLoad * 10).rounded() / 10,
                lastTrainedAt: load.lastTrainedAt ?? date
            )
        }
        .sorted { $0.region.rawValue < $1.region.rawValue }

        return BodyMapIngestResult(
            noveltyMultiplier: novelty,
            regionRewards: rewards,
            wasDuplicate: true
        )
    }

    private func loadProfile(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> BodyMapProfile {
        if let existing: BodyMapProfile = try? await database.read(
            collection: "body_map_profiles",
            documentId: userId
        ) {
            cachedProfiles[userId] = existing
            return existing
        }

        let fresh = BodyMapProfile(userId: userId)
        cachedProfiles[userId] = fresh
        return fresh
    }

    private func regionLoads(
        from gains: [MovementAPGain],
        trainingLoads: [BodyRegionTrainingLoad] = []
    ) -> [BodyRegion: Double] {
        let totalAP = gains.reduce(0) { $0 + max(0, $1.rawAP) }
        let apRegions = Set(gains.flatMap { bodyRegions(for: $0) })
        let roleWeightedLoads = mergedTrainingLoads(trainingLoads)
            .filter { region, load in
                apRegions.contains(region) && load.coachLoadScore > 0
            }
        let totalCoachLoad = roleWeightedLoads.values.reduce(0) { $0 + $1.coachLoadScore }
        if totalAP > 0, totalCoachLoad > 0 {
            return roleWeightedLoads.reduce(into: [:]) { result, entry in
                result[entry.key] = totalAP * (entry.value.coachLoadScore / totalCoachLoad)
            }
        }
        if totalAP == 0, !trainingLoads.isEmpty {
            return mergedTrainingLoads(trainingLoads).reduce(into: [:]) { result, entry in
                let load = entry.value.coachLoadScore * 10
                if load > 0 {
                    result[entry.key] = load
                }
            }
        }

        var loads: [BodyRegion: Double] = [:]

        for gain in gains where gain.rawAP > 0 {
            let regions = bodyRegions(for: gain)
            guard !regions.isEmpty else { continue }

            let loadShare = gain.rawAP / Double(regions.count)
            for region in regions {
                loads[region, default: 0] += loadShare
            }
        }

        return loads
    }

    private func mergedTrainingLoads(
        _ trainingLoads: [BodyRegionTrainingLoad]
    ) -> [BodyRegion: BodyRegionTrainingLoad] {
        trainingLoads.reduce(into: [:]) { result, load in
            var current = result[load.region] ?? BodyRegionTrainingLoad(region: load.region)
            current.merge(load)
            result[load.region] = current
        }
    }

    private func bodyRegions(for gain: MovementAPGain) -> [BodyRegion] {
        let exactRegions = MovementCatalog.definition(for: gain.movementId)?.bodyRegions ?? []
        let standardRegions = MovementCatalog.definition(for: gain.rankStandardMovementId)?.bodyRegions ?? []
        let regions = exactRegions.isEmpty ? standardRegions : exactRegions
        return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
    }

    private func noveltyMultiplier(
        for regions: [BodyRegion],
        profile: BodyMapProfile,
        at date: Date
    ) -> Double {
        guard !regions.isEmpty else { return 1.0 }

        let multipliers = regions.map { region in
            let saturation = saturationNormalized(for: profile.load(for: region), at: date)
            return 1.0 + (1.0 - saturation) * 0.5
        }
        let average = multipliers.reduce(0, +) / Double(multipliers.count)
        return (average * 1_000).rounded() / 1_000
    }

    private func saturationNormalized(for load: BodyRegionLoad, at date: Date) -> Double {
        let recent = decayedRecentLoad(for: load, at: date)
        let recentSaturation = recent / Self.recentFullSaturationLoad
        let lifetimeBaseline = min(Self.maxLifetimeBaseline, load.lifetimeLoad / Self.lifetimeFullSaturationLoad)
        return min(1.0, max(0.0, recentSaturation + lifetimeBaseline))
    }

    private func decayedRecentLoad(for load: BodyRegionLoad, at date: Date) -> Double {
        load.recentLoad * recentDecayFactor(for: load, at: date)
    }

    private func recentDecayFactor(for load: BodyRegionLoad, at date: Date) -> Double {
        guard let lastTrainedAt = load.lastTrainedAt else { return 1.0 }
        let elapsed = max(0, date.timeIntervalSince(lastTrainedAt))
        return pow(0.5, elapsed / Self.recentHalfLifeSeconds)
    }
}
