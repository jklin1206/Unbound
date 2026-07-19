import Foundation

// MARK: - ArcRecapBuilder
//
// Assembles the end-of-Arc recap from the stores that already exist:
// - Level climb from dated training_completion_records (each embeds the true
//   running XP total at that moment) + the live overall_level_progress doc.
// - Attribute hex before/after from the snapshot pinned on ProgramBlock at
//   arc creation (fallback: the earliest attribute source receipt inside the
//   window; blocks predating snapshotting simply hide the delta).
// - Highlights from the block window's performanceLogs: biggest load climbs,
//   biggest rep climbs, rank gates passed, best streak. Top few only.

@MainActor
enum ArcRecapBuilder {
    static let maxHighlights = 4
    /// A load climb must be at least one plate pair to be notable.
    static let minNotableLoadDeltaKg = 2.5
    static let minNotableRepDelta = 3
    static let minNotableStreak = 5

    static func build(
        userId: String,
        program: TrainingProgram,
        database: DatabaseServiceProtocol
    ) async -> ArcRecapSummary? {
        let block = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let windowStart = block?.startedAt ?? program.createdAt
        let windowEnd = Date()
        guard windowEnd > windowStart else { return nil }

        let records = await completionRecords(userId: userId, database: database)
        let windowRecords = records.filter { $0.completedAt > windowStart && $0.completedAt <= windowEnd }
        let logs = await performanceLogs(userId: userId, database: database)
            .filter { $0.completedAt > windowStart && $0.completedAt <= windowEnd }

        // Start XP anchored to this Arc's window: a record dated at/before the
        // window carries the true running total at start; otherwise the first
        // in-window record's previousXP is the state just before it ran.
        let xpAtStartEvidence = records.last(where: { $0.completedAt <= windowStart })?
            .replay?.overallLevelReward?.currentXP
            ?? windowRecords.first?.replay?.overallLevelReward?.previousXP
        let xpNow = await currentTotalXP(userId: userId, database: database)
            ?? windowRecords.last?.replay?.overallLevelReward?.currentXP
            ?? xpAtStartEvidence
            ?? 0
        // With no in-window XP evidence, anchor start to xpNow so the delta is
        // 0 - xpNow is a lifetime total, never bill the whole history as gained
        // this Arc.
        let xpAtStart = xpAtStartEvidence ?? xpNow

        let profile = AttributeService.shared.profile(userId: userId)
        let hexAfter = profile.hexChartValues
        let before = beforeProfile(block: block, profile: profile, windowStart: windowStart)
        let deltas = before.map { snapshot in
            Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
                (key, profile.value(for: key).level - snapshot.profile.value(for: key).level)
            })
        }
        let beforePhoto = await beforePhoto(
            userId: userId,
            windowStart: windowStart,
            database: database
        )

        return ArcRecapSummary(
            id: block?.id ?? program.id,
            userId: userId,
            programId: program.id,
            blockNumber: block?.blockNumber ?? 1,
            windowStart: windowStart,
            windowEnd: windowEnd,
            beforePhotoPath: beforePhoto?.storageUrl,
            beforePhotoDate: beforePhoto?.capturedAt,
            trainedSessions: logs.count,
            totalVolumeKg: totalVolume(in: logs),
            xpGained: max(0, xpNow - xpAtStart),
            attributeHexBefore: before?.profile.hexChartValues,
            attributeHexAfter: hexAfter,
            attributeLevelDeltas: deltas,
            highlights: highlights(
                userId: userId,
                logs: logs,
                windowRecords: windowRecords,
                windowStart: windowStart,
                windowEnd: windowEnd
            )
        )
    }

    /// BEFORE pane source: the newest photo at/before block start (the one
    /// taken at the last recap), else the earliest inside the block when it
    /// is old enough to show real change.
    private static func beforePhoto(
        userId: String,
        windowStart: Date,
        database: DatabaseServiceProtocol
    ) async -> ProgressPhoto? {
        let photos: [ProgressPhoto] = (try? await database.query(
            collection: "progressPhotos",
            field: "userId",
            isEqualTo: userId,
            orderBy: "capturedAt",
            descending: false,
            limit: nil
        )) ?? []
        let sorted = photos.sorted { $0.capturedAt < $1.capturedAt }
        if let priorArc = sorted.last(where: { $0.capturedAt <= windowStart }) {
            return priorArc
        }
        return sorted.first(where: {
            $0.capturedAt > windowStart
                && Date().timeIntervalSince($0.capturedAt) > 7 * 86_400
        })
    }

    // MARK: - Level / volume inputs

    private static func completionRecords(
        userId: String,
        database: DatabaseServiceProtocol
    ) async -> [TrainingCompletionRecord] {
        let records: [TrainingCompletionRecord] = (try? await database.query(
            collection: "training_completion_records",
            field: "userId",
            isEqualTo: userId,
            orderBy: "completedAt",
            descending: false,
            limit: nil
        )) ?? []
        return records.sorted { $0.completedAt < $1.completedAt }
    }

    private static func performanceLogs(
        userId: String,
        database: DatabaseServiceProtocol
    ) async -> [PerformanceLog] {
        (try? await database.query(
            collection: "performanceLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "completedAt",
            descending: false,
            limit: nil
        )) ?? []
    }

    private static func currentTotalXP(
        userId: String,
        database: DatabaseServiceProtocol
    ) async -> Double? {
        let progress: OverallLevelProgress? = try? await database.read(
            collection: "overall_level_progress",
            documentId: userId
        )
        return progress?.totalXP
    }

    private static func totalVolume(in logs: [PerformanceLog]) -> Double {
        var total: Double = 0
        for log in logs {
            for block in log.blocks {
                for exercise in block.exercises {
                    for set in exercise.sets {
                        guard !set.isWarmup, let weight = set.weightKg, let reps = set.reps else {
                            continue
                        }
                        total += weight * Double(reps)
                    }
                }
            }
        }
        return total
    }

    // MARK: - Attribute before-state

    private static func beforeProfile(
        block: ProgramBlock?,
        profile: AttributeProfile,
        windowStart: Date
    ) -> AttributeProfileSnapshot? {
        if let pinned = block?.startAttributes {
            return pinned
        }
        // Fallback for blocks created before arc-start snapshotting: the first
        // ingest AFTER the window opened carries the state just before it ran.
        return profile.processedSourceReceipts.values
            .filter { $0.profileBefore.computedAt >= windowStart }
            .min { $0.profileBefore.computedAt < $1.profileBefore.computedAt }?
            .profileBefore
    }

    // MARK: - Highlights

    private static func highlights(
        userId: String,
        logs: [PerformanceLog],
        windowRecords: [TrainingCompletionRecord],
        windowStart: Date,
        windowEnd: Date
    ) -> [ArcRecapHighlight] {
        var ranked: [(priority: Double, highlight: ArcRecapHighlight)] = []

        for attempt in OverallRankTrialStore.shared.load(userId: userId).attempts
        where attempt.passed {
            guard attempt.completedAt > windowStart, attempt.completedAt <= windowEnd else { continue }
            ranked.append((
                priority: .infinity,
                highlight: ArcRecapHighlight(
                    id: "trial-\(attempt.id)",
                    kind: .trialPassed,
                    title: "\(attempt.targetRank.displayName) gate cleared",
                    detail: "Rank confirmed"
                )
            ))
        }

        ranked.append(contentsOf: movementClimbs(in: logs))

        let bestStreak = windowRecords.compactMap { $0.replay?.streakCount }.max() ?? 0
        if bestStreak >= minNotableStreak {
            ranked.append((
                priority: Double(bestStreak),
                highlight: ArcRecapHighlight(
                    id: "streak",
                    kind: .streak,
                    title: "Longest streak",
                    detail: "\(bestStreak) days"
                )
            ))
        }

        return ranked
            .sorted { $0.priority > $1.priority }
            .prefix(maxHighlights)
            .map(\.highlight)
    }

    /// First-vs-last best working set per movement across the window. Only
    /// climbs worth talking about survive (one plate pair / three reps).
    private static func movementClimbs(
        in logs: [PerformanceLog]
    ) -> [(priority: Double, highlight: ArcRecapHighlight)] {
        struct BestSet {
            var weightKg: Double
            var reps: Int
        }
        var first: [String: BestSet] = [:]
        var last: [String: BestSet] = [:]
        var displayNames: [String: String] = [:]

        for log in logs {
            for block in log.blocks {
                for exercise in block.exercises where !exercise.skipped {
                    let workingSets = exercise.sets.filter { !$0.isWarmup }
                    guard let best = workingSets.max(by: { lhs, rhs in
                        if (lhs.weightKg ?? 0) != (rhs.weightKg ?? 0) {
                            return (lhs.weightKg ?? 0) < (rhs.weightKg ?? 0)
                        }
                        return (lhs.reps ?? 0) < (rhs.reps ?? 0)
                    }) else { continue }

                    let key = MovementCatalog.normalized(exercise.name)
                    let bestSet = BestSet(weightKg: best.weightKg ?? 0, reps: best.reps ?? 0)
                    if first[key] == nil { first[key] = bestSet }
                    last[key] = bestSet
                    displayNames[key] = exercise.name
                }
            }
        }

        var climbs: [(priority: Double, highlight: ArcRecapHighlight)] = []
        for (key, start) in first {
            guard let end = last[key], let name = displayNames[key] else { continue }
            if start.weightKg > 0, end.weightKg - start.weightKg >= minNotableLoadDeltaKg {
                let delta = end.weightKg - start.weightKg
                climbs.append((
                    priority: delta / max(start.weightKg, 1),
                    highlight: ArcRecapHighlight(
                        id: "load-\(key)",
                        kind: .loadUp,
                        title: name,
                        detail: "+\(WeightPlatePolicy.formatLoggedWeightWithUnit(delta, separator: " "))"
                    )
                ))
            } else if start.weightKg == 0, end.weightKg == 0,
                      end.reps - start.reps >= minNotableRepDelta {
                climbs.append((
                    priority: Double(end.reps - start.reps) / Double(max(start.reps, 1)),
                    highlight: ArcRecapHighlight(
                        id: "reps-\(key)",
                        kind: .repUp,
                        title: name,
                        detail: "\(start.reps) → \(end.reps) reps"
                    )
                ))
            }
        }
        return climbs
    }
}
