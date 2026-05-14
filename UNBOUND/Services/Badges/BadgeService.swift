import Foundation

// MARK: - BadgeServiceProtocol

@MainActor
protocol BadgeServiceProtocol: AnyObject {
    /// All badges in the catalog, each populated with its unlockedAt date
    /// if the user has earned it. Ordered per `BadgeCatalog.all`.
    func allBadges(userId: String) -> [Badge]

    /// Unlocked-only subset.
    func unlockedBadges(userId: String) -> [Badge]

    /// Evaluate a trigger. Returns any NEW unlocks (already-unlocked badges
    /// are ignored). Persists + fires `.badgeUnlocked` per new unlock.
    @discardableResult
    func evaluate(trigger: BadgeTrigger) async -> [Badge]

    /// Bind the service to a userId so evaluate() can resolve context
    /// against the right user. Called from UnboundHomeView on appear.
    func bind(userId: String)
}

// MARK: - BadgeService

@MainActor
final class BadgeService: BadgeServiceProtocol {
    static let shared = BadgeService()

    private let logger = LoggingService.shared
    private let defaults = UserDefaults.standard
    private let database = DatabaseService.shared
    private let workoutLogService: WorkoutLogServiceProtocol = WorkoutLogService.shared
    private let keyPrefix = "unbound.badges."

    private var boundUserId: String?

    private init() {}

    func bind(userId: String) {
        boundUserId = userId
    }

    func allBadges(userId: String) -> [Badge] {
        let unlocked = loadUnlocked(userId: userId)
        return BadgeCatalog.all.map { catalog in
            var b = catalog
            if let date = unlocked[catalog.id] { b.unlockedAt = date }
            return b
        }
    }

    func unlockedBadges(userId: String) -> [Badge] {
        allBadges(userId: userId).filter(\.isUnlocked)
    }

    @discardableResult
    func evaluate(trigger: BadgeTrigger) async -> [Badge] {
        guard let userId = userIdFor(trigger) else { return [] }

        var unlocked = loadUnlocked(userId: userId)
        var newlyUnlocked: [Badge] = []

        let candidates = await evaluateCandidates(trigger: trigger, userId: userId)
        for id in candidates where unlocked[id] == nil {
            unlocked[id] = Date()
            if var catalog = BadgeCatalog.byId[id] {
                catalog.unlockedAt = unlocked[id]
                newlyUnlocked.append(catalog)
            }
        }

        if !newlyUnlocked.isEmpty {
            persistUnlocked(unlocked, userId: userId)
            for badge in newlyUnlocked {
                let event = BadgeUnlockEvent(badge: badge)
                NotificationCenter.default.post(
                    name: .badgeUnlocked,
                    object: nil,
                    userInfo: ["event": event]
                )
                logger.log("Badge unlocked: \(badge.id) (\(badge.rarity.rawValue))", level: .info)
            }
        }
        return newlyUnlocked
    }

    // MARK: Candidate evaluation
    //
    // Returns the badge IDs the trigger *could* unlock. The caller filters
    // out already-unlocked ones.

    private func evaluateCandidates(trigger: BadgeTrigger, userId: String) async -> [String] {
        switch trigger {
        case .sessionLogged(let log):
            return await evaluateSessionLogged(log: log, userId: userId)

        case .rankAdvanced(let advance):
            return evaluateRankAdvance(advance: advance)

        case .streakUpdated(let streak):
            return evaluateStreak(streak)

        case .scanComplete:
            return await evaluateScanComplete(userId: userId)

        case .calibrationComplete:
            return ["calibration_complete"]

        case .archetypeChosen:
            return ["archetype_chosen"]

        case .setCompleted(let exerciseKey, let reps):
            return evaluateSetCompleted(exerciseKey: exerciseKey, reps: reps)

        case .photoCaptured:
            return await evaluatePhotoCaptured(userId: userId)

        case .scanCompleted:
            return await evaluateBiWeeklyScan(userId: userId)
        }
    }

    // MARK: Photo / bi-weekly scan evaluators
    //
    // Photo ritual cadence badges. `first_photo` on the first capture ever.
    // `monthly_arc` when the user hits ≥4 captures in a rolling 30-day
    // window. `biweekly_scan` when two scans are within 14 days of each
    // other.

    private func evaluatePhotoCaptured(userId: String) async -> [String] {
        let photos = await fetchProgressPhotos(userId: userId)
        var result: [String] = ["first_photo"]

        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let recent = photos.filter { $0.capturedAt >= cutoff }
        if recent.count >= 4 {
            result.append("monthly_arc")
        }
        if photos.count >= 10 {
            result.append("proof_10")
        }
        if photos.count >= 25 {
            result.append("proof_25")
        }
        return result
    }

    private func evaluateBiWeeklyScan(userId: String) async -> [String] {
        let photos = await fetchProgressPhotos(userId: userId)
        var result: [String] = ["first_scan"]

        let scans = photos.filter { $0.source == .scan }.sorted { $0.capturedAt > $1.capturedAt }
        if scans.count >= 2 {
            let delta = scans[0].capturedAt.timeIntervalSince(scans[1].capturedAt)
            if delta <= 14 * 24 * 3600 {
                result.append("biweekly_scan")
            }
        }
        if scans.count >= 5 {
            result.append("scan_archive_5")
        }
        if scans.count >= 10 {
            result.append("scan_archive_10")
        }

        // Monthly arc also counts scans.
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let recent = photos.filter { $0.capturedAt >= cutoff }
        if recent.count >= 4 {
            result.append("monthly_arc")
        }
        if photos.count >= 10 {
            result.append("proof_10")
        }
        if photos.count >= 25 {
            result.append("proof_25")
        }
        return result
    }

    private func fetchProgressPhotos(userId: String) async -> [ProgressPhoto] {
        do {
            let photos: [ProgressPhoto] = try await database.query(
                collection: "progressPhotos",
                field: "userId",
                isEqualTo: userId,
                orderBy: "capturedAt",
                descending: true,
                limit: 120
            )
            return photos
        } catch {
            return []
        }
    }

    private func evaluateSessionLogged(log: WorkoutLog, userId: String) async -> [String] {
        var result: [String] = ["first_session"]

        let xp = SessionXPService.shared.record(userId: userId)
        let total = xp.totalSessions + 1 // post-increment count; XP service increments first
        if total >= 10 { result.append("sessions_10") }
        if total >= 25 { result.append("sessions_25") }
        if total >= 50 { result.append("sessions_50") }
        if total >= 100 { result.append("sessions_100") }
        if total >= 250 { result.append("sessions_250") }
        if total >= 500 { result.append("sessions_500") }

        if log.exerciseEntries.contains(where: { !$0.skipped }) &&
            log.exerciseEntries.allSatisfy({ !$0.skipped }) {
            result.append("clean_sweep")
        }
        if (log.durationMinutes ?? 0) >= 60 {
            result.append("hour_glass")
        }

        // Streak checks bounce through XP service record.
        let streak = xp.currentStreak
        result += evaluateStreak(streak)

        // Per-exercise checks (muscle-up, HSPU) from this log's entries.
        for entry in log.exerciseEntries where !entry.skipped {
            let key = entry.exerciseName.lowercased()
            let completedAnySet = entry.sets.contains(where: { !$0.isWarmup && $0.reps > 0 })
            guard completedAnySet else { continue }
            if key.contains("muscle-up") || key.contains("muscle up") {
                result.append("first_muscle_up")
            }
            if key.contains("handstand pushup") || key.contains("handstand push-up") || key.contains("hspu") {
                result.append("first_handstand_pushup")
            }
            if key.contains("pull-up") || key.contains("pullup") || key.contains("chin-up") || key.contains("chin up") {
                result.append("first_pullup")
            }
            if key.contains("dip") {
                result.append("first_dip")
            }
            if key.contains("pistol squat") {
                result.append("first_pistol_squat")
            }
            if (key.contains("push-up") || key.contains("pushup")) &&
                entry.sets.contains(where: { !$0.isWarmup && $0.reps >= 50 }) {
                result.append("pushup_50_set")
            }
        }

        // Bodyweight-multiple badges: literal math against recent logs.
        // Skips gracefully when bodyweight unknown.
        result += await evaluateBodyweightMultiples(userId: userId, currentLog: log)

        return result
    }

    /// Literal (weight / bodyweight) check for squat 2×, bench 1.5×, deadlift 3×.
    /// Scans the current log plus recent history so crossings that don't
    /// happen to coincide with a letter rank-up still unlock.
    private func evaluateBodyweightMultiples(userId: String, currentLog: WorkoutLog) async -> [String] {
        guard let bodyweightKg = await fetchBodyweightKg(userId: userId), bodyweightKg > 0 else {
            return []
        }

        var logs: [WorkoutLog] = [currentLog]
        if let recent = try? await workoutLogService.fetchRecentLogs(userId: userId, limit: 25) {
            logs.append(contentsOf: recent.filter { $0.id != currentLog.id })
        }

        var hitSquat = false
        var hitBench = false
        var hitDeadlift = false

        for log in logs {
            for entry in log.exerciseEntries where !entry.skipped {
                let key = entry.exerciseName.lowercased()
                let isSquat    = key.contains("squat")    && !key.contains("split") && !key.contains("goblet")
                let isBench    = key.contains("bench")    && !key.contains("dumbbell")
                let isDeadlift = key.contains("deadlift")
                guard isSquat || isBench || isDeadlift else { continue }

                for set in entry.sets where !set.isWarmup && set.reps > 0 {
                    guard let w = set.weightKg, w > 0 else { continue }
                    let ratio = w / bodyweightKg
                    if isSquat, ratio >= 2.0    { hitSquat = true }
                    if isBench, ratio >= 1.5    { hitBench = true }
                    if isDeadlift, ratio >= 3.0 { hitDeadlift = true }
                }
            }
        }

        var result: [String] = []
        if hitSquat    { result.append("bw_squat_2x") }
        if hitBench    { result.append("bw_bench_1_5x") }
        if hitDeadlift { result.append("bw_deadlift_3x") }
        return result
    }

    private func fetchBodyweightKg(userId: String) async -> Double? {
        let profile: UserProfile? = try? await database.read(
            collection: "users",
            documentId: userId
        )
        return profile?.weightKg
    }

    private func evaluateRankAdvance(advance: RankAdvance) -> [String] {
        var result: [String] = ["first_rank_up"]
        let ordinal = advance.toRank.ordinal
        if ordinal >= SubRank.ordinalForLetter("C") { result.append("rank_c_any") }
        if ordinal >= SubRank.ordinalForLetter("B") { result.append("rank_b_any") }
        if ordinal >= SubRank.ordinalForLetter("A") { result.append("rank_a_any") }
        if ordinal >= SubRank.ordinalForLetter("S") { result.append("rank_s_any") }
        // BW-multiple milestones are evaluated literally against working-set
        // weight in `.sessionLogged` (see evaluateBodyweightMultiples).
        // Letter-rank approximation is intentionally omitted here.
        return result
    }

    private func evaluateStreak(_ streak: Int) -> [String] {
        var result: [String] = []
        if streak >= 3 { result.append("streak_3") }
        if streak >= 7 { result.append("streak_7") }
        if streak >= 14 { result.append("streak_14") }
        if streak >= 30 { result.append("streak_30") }
        if streak >= 60 { result.append("streak_60") }
        if streak >= 100 { result.append("streak_100") }
        return result
    }

    private func evaluateScanComplete(userId: String) async -> [String] {
        var result: [String] = ["first_scan"]
        let scanCount = (defaults.integer(forKey: "unbound.totalScans.\(userId)"))
        let nextCount = scanCount + 1
        defaults.set(nextCount, forKey: "unbound.totalScans.\(userId)")
        if nextCount >= 3 {
            result.append("scan_streak_3")
        }
        if nextCount >= 5 {
            result.append("scan_archive_5")
        }
        if nextCount >= 10 {
            result.append("scan_archive_10")
        }
        return result
    }

    private func evaluateSetCompleted(exerciseKey: String, reps: Int) -> [String] {
        guard reps > 0 else { return [] }
        let key = exerciseKey.lowercased()
        var result: [String] = []
        if key.contains("muscle-up") || key.contains("muscle up") {
            result.append("first_muscle_up")
        }
        if key.contains("handstand pushup") || key.contains("handstand push-up") || key.contains("hspu") {
            result.append("first_handstand_pushup")
        }
        if key.contains("pull-up") || key.contains("pullup") || key.contains("chin-up") || key.contains("chin up") {
            result.append("first_pullup")
        }
        if key.contains("dip") {
            result.append("first_dip")
        }
        if key.contains("pistol squat") {
            result.append("first_pistol_squat")
        }
        if (key.contains("push-up") || key.contains("pushup")), reps >= 50 {
            result.append("pushup_50_set")
        }
        return result
    }

    // MARK: Persistence

    private func key(for userId: String) -> String { keyPrefix + userId }

    private func loadUnlocked(userId: String) -> [String: Date] {
        guard let data = defaults.data(forKey: key(for: userId)) else { return [:] }
        return (try? JSONDecoder.unbound.decode([String: Date].self, from: data)) ?? [:]
    }

    private func persistUnlocked(_ map: [String: Date], userId: String) {
        guard let data = try? JSONEncoder.unbound.encode(map) else { return }
        defaults.set(data, forKey: key(for: userId))
    }

    private func userIdFor(_ trigger: BadgeTrigger) -> String? {
        switch trigger {
        case .sessionLogged(let log): return log.userId
        case .rankAdvanced(let advance): return advance.userId
        default: return boundUserId
        }
    }
}

// MARK: - MockBadgeService

@MainActor
final class MockBadgeService: BadgeServiceProtocol {
    var unlocked: [String: Date] = [:]

    func bind(userId: String) {}

    func allBadges(userId: String) -> [Badge] {
        BadgeCatalog.all.map { b in
            var copy = b
            copy.unlockedAt = unlocked[b.id]
            return copy
        }
    }

    func unlockedBadges(userId: String) -> [Badge] {
        allBadges(userId: userId).filter(\.isUnlocked)
    }

    @discardableResult
    func evaluate(trigger: BadgeTrigger) async -> [Badge] { [] }
}
