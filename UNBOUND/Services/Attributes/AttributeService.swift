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

    /// Apply onboarding seed. Each selected key gets peak=current=15.
    func applySeed(_ seeded: Set<AttributeKey>, userId: String)

    /// Pin the current profile to a scan id, for later Δ comparison.
    func snapshotForScan(scanId: String, userId: String) async

    /// Returns historical pinned snapshots for the user, oldest first.
    func scanHistory(userId: String) -> [AttributeProfile]

    /// Replay existing workout logs through ingest to backfill the profile.
    /// Called once on first launch when no profile exists in the store.
    func backfillFromExistingLogs(userId: String) async
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
    private let logger = LoggingService.shared

    init(catalog: AttributeCatalogProtocol, store: AttributeProfileStoreProtocol, database: any DatabaseServiceProtocol = DatabaseService.shared) {
        self.catalog = catalog
        self.store = store
        self.database = database
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
        store.save(profile)
        for event in crossings {
            NotificationCenter.default.post(name: .attributeRankUp, object: event)
        }
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

    func applySeed(_ seeded: Set<AttributeKey>, userId: String) {
        guard !seeded.isEmpty else { return }
        var profile = profile(userId: userId)
        let now = Date()
        for key in seeded {
            profile.set(key, AttributeValue(peak: 15, current: 15, lastContributionAt: now))
        }
        profile.computedAt = now
        store.save(profile)
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
}
