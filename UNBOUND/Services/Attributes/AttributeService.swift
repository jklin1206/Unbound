// UNBOUND/Services/Attributes/AttributeService.swift
import Foundation

// MARK: - AttributeServiceProtocol

@MainActor
protocol AttributeServiceProtocol: AnyObject {
    /// Returns the cached profile for the user.
    func profile(userId: String) -> AttributeProfile

    /// Snapshot the profile projected forward to `date` (applies drift).
    /// Pure — does not persist. Used by every read site.
    func snapshot(userId: String, asOf date: Date) -> AttributeProfile

    /// Apply a finished workout to the user's profile. Decay-forward first,
    /// then add deltas. Persists. Emits rank-up notifications.
    @discardableResult
    func ingest(session: WorkoutLog, userId: String) async -> AttributeProfile

    /// Apply canonical workout-derived attribute XP from a completed performance
    /// log. This is the migration path defined in PROGRESSION.md: movement work
    /// fans into permanent attribute XP through each movement's vector.
    @discardableResult
    func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        at date: Date,
        noveltyMultiplier: Double,
        sourceId: String?
    ) async -> AttributeAPIngestResult

    /// Apply direct permanent attribute XP for non-movement rewards such as
    /// recovery check-ins and rest-day completion.
    @discardableResult
    func applyXPDeltas(
        _ xpDeltas: [AttributeKey: Double],
        userId: String,
        at date: Date,
        sourceId: String?
    ) async -> AttributeAPIngestResult

    /// Apply onboarding seed. Each selected key starts at L0 (xp = 0).
    func applySeed(_ seeded: Set<AttributeKey>, userId: String)

    /// Pin the current profile to a scan id, for later Δ comparison.
    func snapshotForScan(scanId: String, userId: String) async

    /// Returns historical pinned snapshots for the user, oldest first.
    func scanHistory(userId: String) -> [AttributeProfile]

    /// Replay existing workout logs through ingest to backfill the profile.
    /// Called once on first launch when no profile exists in the store.
    func backfillFromExistingLogs(userId: String) async

    /// Apply a flat boost to a single axis (trial capstone payoff).
    /// Clamps to 100. Posts `.attributeRankUp` if a rank tier is crossed.
    func applyBoost(axis: AttributeKey, amount: Double, userId: String)
}

extension AttributeServiceProtocol {
    @discardableResult
    func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        at date: Date,
        noveltyMultiplier: Double
    ) async -> AttributeAPIngestResult {
        await ingest(
            movementAPGains: gains,
            userId: userId,
            at: date,
            noveltyMultiplier: noveltyMultiplier,
            sourceId: nil
        )
    }

    @discardableResult
    func applyXPDeltas(
        _ xpDeltas: [AttributeKey: Double],
        userId: String,
        at date: Date
    ) async -> AttributeAPIngestResult {
        await applyXPDeltas(xpDeltas, userId: userId, at: date, sourceId: nil)
    }
}

// MARK: - AttributeService (real)

@MainActor
final class AttributeService: AttributeServiceProtocol {
    static let shared = AttributeService(
        catalog: AttributeCatalog.shared,
        store: AttributeProfileStore.shared,
        database: DatabaseService.shared
    )

    private let catalog: AttributeCatalogProtocol
    private let store: AttributeProfileStoreProtocol
    private let database: any DatabaseServiceProtocol
    private let buildClassStore: BuildClassStore
    private let logger = LoggingService.shared

    init(
        catalog: AttributeCatalogProtocol,
        store: AttributeProfileStoreProtocol,
        database: any DatabaseServiceProtocol = DatabaseService.shared,
        buildClassStore: BuildClassStore = .shared
    ) {
        self.catalog = catalog
        self.store = store
        self.database = database
        self.buildClassStore = buildClassStore
    }

    /// Single persist choke point: every profile save also advances the
    /// class hold, since ingest is the only time the hex moves.
    private func persist(_ profile: AttributeProfile, at date: Date) {
        store.save(profile)
        buildClassStore.observe(profile.buildIdentity, userId: profile.userId, at: date)
    }

    /// Fresh crown-band crossings earn the axis's class-name title (Titan,
    /// Monk, …), announced. Already-unlocked titles no-op inside unlockTitle.
    private func grantAxisTitles(for events: [AttributeRankUpEvent], userId: String) {
        for event in events where event.toTitle >= TitleGrants.axisTitleBar {
            WeeklyVowsService.shared.unlockTitle(.axis(event.axis), userId: userId)
        }
    }

    func profile(userId: String) -> AttributeProfile {
        store.load(userId: userId) ?? .empty(userId: userId, at: .now)
    }

    func snapshot(userId: String, asOf date: Date) -> AttributeProfile {
        AttributeDrift.project(profile(userId: userId), to: date)
    }

    @discardableResult
    func ingest(session: WorkoutLog, userId: String) async -> AttributeProfile {
        let finishedAt = session.completedAt ?? .now
        // Decay-forward first, then apply deltas. New gains build on decayed current.
        var profile = AttributeDrift.project(profile(userId: userId), to: finishedAt)
        let beforeShape = profile.buildIdentity.shape
        let deltas = AttributeIngest.deltas(for: session, catalog: catalog)
        let crossings = AttributeIngest.applyDeltas(&profile, deltas: deltas, at: finishedAt)
        profile.computedAt = finishedAt
        persist(profile, at: finishedAt)
        for event in crossings {
            NotificationCenter.default.post(name: .attributeRankUp, object: event)
        }
        grantAxisTitles(for: crossings, userId: userId)
        // First-resolved badge: fires once when buildIdentity escapes
        // .balancedAthlete. Subsequent shape transitions are silent.
        let afterShape = profile.buildIdentity.shape
        if beforeShape == .balancedAthlete && afterShape != .balancedAthlete {
            _ = await BadgeService.shared.evaluate(
                trigger: .firstBuildIdentityResolved(profile.buildIdentity)
            )
        }
        return profile
    }

    @discardableResult
    func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        at date: Date,
        noveltyMultiplier: Double = 1.0,
        sourceId: String? = nil
    ) async -> AttributeAPIngestResult {
        guard !gains.isEmpty else { return AttributeAPIngestResult() }

        var profile = AttributeDrift.project(profile(userId: userId), to: date)
        let beforeShape = profile.buildIdentity.shape
        let xpDeltas = AttributeIngest.xpDeltas(
            for: gains,
            catalog: catalog,
            noveltyMultiplier: noveltyMultiplier
        )
        guard !xpDeltas.isEmpty else { return AttributeAPIngestResult() }
        if profile.hasProcessed(sourceId) {
            if let sourceId, let receipt = profile.processedSourceReceipts[sourceId] {
                return receipt.result
            }
            return reconstructedAttributeResult(profileAfter: profile, xpDeltas: xpDeltas, at: date)
        }

        let profileBefore = profile
        let applied = AttributeIngest.applyXPDeltas(&profile, xpDeltas: xpDeltas, at: date)
        profile.computedAt = date
        profile.markProcessed(
            sourceId,
            receipt: AttributeSourceReceipt(
                rewards: applied.rewards,
                rankUpEventCount: applied.rankUpEvents.count,
                profileBefore: AttributeProfileSnapshot(profileBefore),
                profileAfter: AttributeProfileSnapshot(profile)
            )
        )
        persist(profile, at: date)

        for event in applied.rankUpEvents {
            NotificationCenter.default.post(name: .attributeRankUp, object: event)
        }
        grantAxisTitles(for: applied.rankUpEvents, userId: userId)

        let afterShape = profile.buildIdentity.shape
        if beforeShape == .balancedAthlete && afterShape != .balancedAthlete {
            _ = await BadgeService.shared.evaluate(
                trigger: .firstBuildIdentityResolved(profile.buildIdentity)
            )
        }

        return AttributeAPIngestResult(
            rewards: applied.rewards,
            rankUpEvents: applied.rankUpEvents,
            profileBefore: profileBefore,
            profileAfter: profile
        )
    }

    @discardableResult
    func applyXPDeltas(
        _ xpDeltas: [AttributeKey: Double],
        userId: String,
        at date: Date,
        sourceId: String? = nil
    ) async -> AttributeAPIngestResult {
        guard !xpDeltas.isEmpty else { return AttributeAPIngestResult() }

        var profile = AttributeDrift.project(profile(userId: userId), to: date)
        let beforeShape = profile.buildIdentity.shape
        if profile.hasProcessed(sourceId) {
            if let sourceId, let receipt = profile.processedSourceReceipts[sourceId] {
                return receipt.result
            }
            return reconstructedAttributeResult(profileAfter: profile, xpDeltas: xpDeltas, at: date)
        }
        let profileBefore = profile
        let applied = AttributeIngest.applyXPDeltas(&profile, xpDeltas: xpDeltas, at: date)
        guard !applied.rewards.isEmpty else { return AttributeAPIngestResult() }

        profile.computedAt = date
        profile.markProcessed(
            sourceId,
            receipt: AttributeSourceReceipt(
                rewards: applied.rewards,
                rankUpEventCount: applied.rankUpEvents.count,
                profileBefore: AttributeProfileSnapshot(profileBefore),
                profileAfter: AttributeProfileSnapshot(profile)
            )
        )
        persist(profile, at: date)

        for event in applied.rankUpEvents {
            NotificationCenter.default.post(name: .attributeRankUp, object: event)
        }
        grantAxisTitles(for: applied.rankUpEvents, userId: userId)

        let afterShape = profile.buildIdentity.shape
        if beforeShape == .balancedAthlete && afterShape != .balancedAthlete {
            _ = await BadgeService.shared.evaluate(
                trigger: .firstBuildIdentityResolved(profile.buildIdentity)
            )
        }

        return AttributeAPIngestResult(
            rewards: applied.rewards,
            rankUpEvents: applied.rankUpEvents,
            profileBefore: profileBefore,
            profileAfter: profile
        )
    }

    func applySeed(_ seeded: Set<AttributeKey>, userId: String) {
        guard !seeded.isEmpty else { return }
        var profile = profile(userId: userId)
        let now = Date()
        // Everyone starts at L0 — xp = 0, a tiny sliver. Training is the only
        // way up.
        for key in seeded {
            profile.set(key, AttributeValue(xp: 0, lastContributionAt: now))
        }
        profile.computedAt = now
        persist(profile, at: now)
    }

    func snapshotForScan(scanId: String, userId: String) async {
        let snap = snapshot(userId: userId, asOf: .now)
        store.pin(snap, toScan: scanId)
    }

    func scanHistory(userId: String) -> [AttributeProfile] {
        store.history(userId: userId)
    }

    func backfillFromExistingLogs(userId: String) async {
        // Skip if a profile already exists for this user.
        guard store.load(userId: userId) == nil else { return }

        let logs: [WorkoutLog]
        do {
            logs = try await database.query(
                collection: "workoutLogs",
                field: "userId",
                isEqualTo: userId,
                orderBy: "startedAt",
                descending: false,
                limit: nil
            )
        } catch {
            logger.log("AttributeService.backfill: failed to fetch logs: \(error)", level: .warning)
            return
        }

        guard !logs.isEmpty else { return }

        for log in logs {
            await ingest(session: log, userId: userId)
        }
        logger.log("AttributeService.backfill: replayed \(logs.count) logs for user \(userId)", level: .info)
    }

    func applyBoost(axis: AttributeKey, amount: Double, userId: String) {
        let now = Date()
        var prof = profile(userId: userId)
        var value = prof.value(for: axis)
        let beforeTitle = value.rankTitle
        value.xp += max(0, amount)
        value.lastContributionAt = now
        prof.set(axis, value)
        prof.computedAt = now
        persist(prof, at: now)
        // Fire rank-up notification if the tier crossed.
        let afterTitle = value.rankTitle
        if afterTitle > beforeTitle {
            let crownBand: Set<RankTitle> = [.vessel, .ascendant, .unbound]
            let event = AttributeRankUpEvent(
                axis: axis,
                fromTitle: beforeTitle,
                toTitle: afterTitle,
                level: crownBand.contains(afterTitle) ? .aTier : .tier,
                timestamp: now
            )
            NotificationCenter.default.post(name: .attributeRankUp, object: event)
            grantAxisTitles(for: [event], userId: userId)
        }
    }
}

private func reconstructedAttributeResult(
    profileAfter: AttributeProfile,
    xpDeltas: [AttributeKey: Double],
    at date: Date
) -> AttributeAPIngestResult {
    var rewards: [AttributeProgressionReward] = []
    var rankUpEvents: [AttributeRankUpEvent] = []

    for key in AttributeKey.allCases {
        guard let xpGained = xpDeltas[key], xpGained > 0 else { continue }
        let currentValue = profileAfter.value(for: key)
        let previousXP = max(0, currentValue.xp - xpGained)
        let previousLevel = AttributeLevelCurve.level(forXP: previousXP)
        let currentLevel = currentValue.level
        let previousTier = AttributeLevelCurve.rankTitle(forLevel: previousLevel)
        let currentTier = currentValue.rankTitle
        rewards.append(
            AttributeProgressionReward(
                key: key,
                xpGained: xpGained,
                previousXP: previousXP,
                currentXP: currentValue.xp,
                previousLevel: previousLevel,
                currentLevel: currentLevel,
                previousTier: previousTier,
                currentTier: currentTier
            )
        )
        if currentTier > previousTier {
            let crownBand: Set<RankTitle> = [.vessel, .ascendant, .unbound]
            rankUpEvents.append(
                AttributeRankUpEvent(
                    axis: key,
                    fromTitle: previousTier,
                    toTitle: currentTier,
                    level: crownBand.contains(currentTier) ? .aTier : .tier,
                    timestamp: date
                )
            )
        }
    }

    return AttributeAPIngestResult(
        rewards: rewards,
        rankUpEvents: rankUpEvents,
        profileBefore: nil,
        profileAfter: profileAfter
    )
}

// MARK: - MockAttributeService

@MainActor
final class MockAttributeService: AttributeServiceProtocol {
    var profileByUser: [String: AttributeProfile] = [:]
    var historyByUser: [String: [AttributeProfile]] = [:]
    var ingested: [WorkoutLog] = []
    var seededFor: [String: Set<AttributeKey>] = [:]

    func profile(userId: String) -> AttributeProfile {
        profileByUser[userId] ?? .empty(userId: userId, at: .now)
    }
    func snapshot(userId: String, asOf date: Date) -> AttributeProfile {
        AttributeDrift.project(profile(userId: userId), to: date)
    }
    @discardableResult
    func ingest(session: WorkoutLog, userId: String) async -> AttributeProfile {
        ingested.append(session)
        return profile(userId: userId)
    }
    @discardableResult
    func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        at date: Date,
        noveltyMultiplier: Double = 1.0,
        sourceId: String? = nil
    ) async -> AttributeAPIngestResult {
        guard !gains.isEmpty else { return AttributeAPIngestResult() }
        var prof = profileByUser[userId] ?? .empty(userId: userId, at: date)
        let xpDeltas = AttributeIngest.xpDeltas(
            for: gains,
            catalog: AttributeCatalog.shared,
            noveltyMultiplier: noveltyMultiplier
        )
        if prof.hasProcessed(sourceId) {
            if let sourceId, let receipt = prof.processedSourceReceipts[sourceId] {
                return receipt.result
            }
            return reconstructedAttributeResult(profileAfter: prof, xpDeltas: xpDeltas, at: date)
        }
        let profileBefore = prof
        let applied = AttributeIngest.applyXPDeltas(&prof, xpDeltas: xpDeltas, at: date)
        prof.computedAt = date
        prof.markProcessed(
            sourceId,
            receipt: AttributeSourceReceipt(
                rewards: applied.rewards,
                rankUpEventCount: applied.rankUpEvents.count,
                profileBefore: AttributeProfileSnapshot(profileBefore),
                profileAfter: AttributeProfileSnapshot(prof)
            )
        )
        profileByUser[userId] = prof
        return AttributeAPIngestResult(
            rewards: applied.rewards,
            rankUpEvents: applied.rankUpEvents,
            profileBefore: profileBefore,
            profileAfter: prof
        )
    }
    @discardableResult
    func applyXPDeltas(
        _ xpDeltas: [AttributeKey: Double],
        userId: String,
        at date: Date,
        sourceId: String? = nil
    ) async -> AttributeAPIngestResult {
        guard !xpDeltas.isEmpty else { return AttributeAPIngestResult() }
        var prof = profileByUser[userId] ?? .empty(userId: userId, at: date)
        if prof.hasProcessed(sourceId) {
            if let sourceId, let receipt = prof.processedSourceReceipts[sourceId] {
                return receipt.result
            }
            return reconstructedAttributeResult(profileAfter: prof, xpDeltas: xpDeltas, at: date)
        }
        let profileBefore = prof
        let applied = AttributeIngest.applyXPDeltas(&prof, xpDeltas: xpDeltas, at: date)
        prof.computedAt = date
        prof.markProcessed(
            sourceId,
            receipt: AttributeSourceReceipt(
                rewards: applied.rewards,
                rankUpEventCount: applied.rankUpEvents.count,
                profileBefore: AttributeProfileSnapshot(profileBefore),
                profileAfter: AttributeProfileSnapshot(prof)
            )
        )
        profileByUser[userId] = prof
        return AttributeAPIngestResult(
            rewards: applied.rewards,
            rankUpEvents: applied.rankUpEvents,
            profileBefore: profileBefore,
            profileAfter: prof
        )
    }
    func applySeed(_ seeded: Set<AttributeKey>, userId: String) {
        seededFor[userId] = seeded
    }
    func snapshotForScan(scanId: String, userId: String) async {
        let profile = self.profile(userId: userId)
        historyByUser[userId, default: []].append(profile)
    }
    func scanHistory(userId: String) -> [AttributeProfile] {
        historyByUser[userId] ?? []
    }
    func backfillFromExistingLogs(userId: String) async {}
    func applyBoost(axis: AttributeKey, amount: Double, userId: String) {
        var prof = profileByUser[userId] ?? .empty(userId: userId, at: .now)
        var value = prof.value(for: axis)
        value.xp += max(0, amount)
        value.lastContributionAt = Date()
        prof.set(axis, value)
        profileByUser[userId] = prof
    }
}
