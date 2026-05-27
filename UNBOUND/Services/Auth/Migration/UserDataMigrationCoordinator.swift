import Foundation

struct UserDataMigrationSummary: Equatable, Sendable {
    var workoutLogs = UserDataMigrationCollectionSummary()
    var workingWeights = UserDataMigrationCollectionSummary()
    var skillProgress = UserDataMigrationCollectionSummary()

    var migratedLocally: Int {
        workoutLogs.localWrites + workingWeights.localWrites + skillProgress.localWrites
    }

    var remoteDeferred: Int {
        workoutLogs.remoteDeferred + workingWeights.remoteDeferred + skillProgress.remoteDeferred
    }
}

struct UserDataMigrationCollectionSummary: Equatable, Sendable {
    var scanned = 0
    var localWrites = 0
    var existingTargets = 0
    var queuedForSync = 0
    var remoteUpserts = 0
    var remoteDeferred = 0
    var remoteSkipped = 0
    var failures = 0
}

protocol UserDataMigrationLocalStoring: Sendable {
    func workoutLogs(userId: String) async throws -> [WorkoutLog]
    func workoutLog(id: String) async throws -> WorkoutLog?
    func writeWorkoutLog(_ log: WorkoutLog, enqueueForSync: Bool) async throws

    func workingWeights(userId: String) async throws -> [WorkingWeight]
    func workingWeight(id: String) async throws -> WorkingWeight?
    func writeWorkingWeight(_ weight: WorkingWeight) async throws

    func skillProgress(userId: String) async throws -> UserSkillProgress?
    func writeSkillProgress(_ progress: UserSkillProgress) async throws
}

protocol UserDataMigrationRemoteWriting: Sendable {
    func canWrite(as userId: String) async -> Bool
    func upsertWorkingWeight(_ weight: WorkingWeight) async throws
    func upsertSkillProgress(_ progress: UserSkillProgress) async throws
}

struct UserDataMigrationCoordinator: Sendable {
    private let local: any UserDataMigrationLocalStoring
    private let remote: any UserDataMigrationRemoteWriting
    private let logger: LoggingService

    init(
        local: any UserDataMigrationLocalStoring = ProductionUserDataMigrationLocalStore(),
        remote: any UserDataMigrationRemoteWriting = SupabaseUserDataMigrationRemoteStore(),
        logger: LoggingService = .shared
    ) {
        self.local = local
        self.remote = remote
        self.logger = logger
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> UserDataMigrationSummary {
        guard legacyUserId != supabaseUserId else {
            logger.log("Skipped local data migration because source and destination user ids match", level: .info)
            return UserDataMigrationSummary()
        }

        let remoteReady = await remote.canWrite(as: supabaseUserId)
        if !remoteReady {
            logger.log(
                "Supabase session unavailable for direct migration writes; local writes and queued sync will be deferred",
                level: .warning,
                context: ["to": supabaseUserId]
            )
        }

        let workoutLogs = await migrateWorkoutLogs(
            legacyUserId: legacyUserId,
            supabaseUserId: supabaseUserId
        )
        let workingWeights = await migrateWorkingWeights(
            legacyUserId: legacyUserId,
            supabaseUserId: supabaseUserId,
            remoteReady: remoteReady
        )
        let skillProgress = await migrateSkillProgress(
            legacyUserId: legacyUserId,
            supabaseUserId: supabaseUserId,
            remoteReady: remoteReady
        )

        return UserDataMigrationSummary(
            workoutLogs: workoutLogs,
            workingWeights: workingWeights,
            skillProgress: skillProgress
        )
    }

    private func migrateWorkoutLogs(
        legacyUserId: String,
        supabaseUserId: String
    ) async -> UserDataMigrationCollectionSummary {
        var summary = UserDataMigrationCollectionSummary()

        do {
            let legacyLogs = try await local.workoutLogs(userId: legacyUserId)
            summary.scanned = legacyLogs.count

            for legacy in legacyLogs {
                if try await existingWorkoutLog(id: legacy.id, supabaseUserId: supabaseUserId) != nil {
                    summary.existingTargets += 1
                } else {
                    let target = legacy.rekeyed(to: supabaseUserId)
                    let canSync = target.isSupabaseMigrationCompatible
                    try await local.writeWorkoutLog(target, enqueueForSync: canSync)
                    summary.localWrites += 1
                    if canSync {
                        summary.queuedForSync += 1
                    } else {
                        summary.remoteSkipped += 1
                        logger.log(
                            "Workout log migrated locally but skipped Supabase sync because ids are not UUID-compatible",
                            level: .warning,
                            context: ["logId": target.id, "programId": target.programId]
                        )
                    }
                }
            }
        } catch {
            summary.failures += 1
            logger.log("Workout log migration failed: \(error)", level: .error)
        }

        return summary
    }

    private func migrateWorkingWeights(
        legacyUserId: String,
        supabaseUserId: String,
        remoteReady: Bool
    ) async -> UserDataMigrationCollectionSummary {
        var summary = UserDataMigrationCollectionSummary()

        do {
            let legacyWeights = try await local.workingWeights(userId: legacyUserId)
            summary.scanned = legacyWeights.count

            for legacy in legacyWeights {
                let target: WorkingWeight
                if let existing = try await local.workingWeight(id: legacy.id),
                   existing.userId == supabaseUserId {
                    target = existing
                    summary.existingTargets += 1
                } else {
                    target = legacy.rekeyed(to: supabaseUserId)
                    try await local.writeWorkingWeight(target)
                    summary.localWrites += 1
                }

                summary.record(await upsertWorkingWeight(target, remoteReady: remoteReady))
            }
        } catch {
            summary.failures += 1
            logger.log("Working weight migration failed: \(error)", level: .error)
        }

        return summary
    }

    private func migrateSkillProgress(
        legacyUserId: String,
        supabaseUserId: String,
        remoteReady: Bool
    ) async -> UserDataMigrationCollectionSummary {
        var summary = UserDataMigrationCollectionSummary()

        do {
            guard let legacy = try await local.skillProgress(userId: legacyUserId) else {
                return summary
            }
            summary.scanned = 1

            let target: UserSkillProgress
            var shouldWrite = true
            if let existing = try await local.skillProgress(userId: supabaseUserId) {
                let merged = UserSkillProgress.merging(
                    legacy: legacy,
                    target: existing,
                    targetUserId: supabaseUserId
                )
                summary.existingTargets += 1
                shouldWrite = !merged.isMigrationEquivalent(to: existing)
                target = shouldWrite ? merged : existing
            } else {
                target = legacy.rekeyed(to: supabaseUserId)
            }

            if shouldWrite {
                try await local.writeSkillProgress(target)
                summary.localWrites += 1
            }
            summary.record(await upsertSkillProgress(target, remoteReady: remoteReady))
        } catch {
            summary.failures += 1
            logger.log("Skill progress migration failed: \(error)", level: .error)
        }

        return summary
    }

    private func existingWorkoutLog(id: String, supabaseUserId: String) async throws -> WorkoutLog? {
        guard let existing = try await local.workoutLog(id: id),
              existing.userId == supabaseUserId else {
            return nil
        }
        return existing
    }

    private func upsertWorkingWeight(
        _ weight: WorkingWeight,
        remoteReady: Bool
    ) async -> RemoteMigrationOutcome {
        guard remoteReady else {
            return .deferred
        }

        do {
            try await remote.upsertWorkingWeight(weight)
            return .upserted
        } catch SupabaseDatabaseError.notAuthenticated {
            logger.log("Working weight Supabase migration deferred: not authenticated", level: .warning)
            return .deferred
        } catch {
            logger.log(
                "Working weight Supabase migration failed: \(error)",
                level: .error,
                context: ["id": weight.id]
            )
            return .failed
        }
    }

    private func upsertSkillProgress(
        _ progress: UserSkillProgress,
        remoteReady: Bool
    ) async -> RemoteMigrationOutcome {
        guard remoteReady else {
            return .deferred
        }

        do {
            try await remote.upsertSkillProgress(progress)
            return .upserted
        } catch SupabaseDatabaseError.notAuthenticated {
            logger.log("Skill progress Supabase migration deferred: not authenticated", level: .warning)
            return .deferred
        } catch {
            logger.log(
                "Skill progress Supabase migration failed: \(error)",
                level: .error,
                context: ["userId": progress.userId]
            )
            return .failed
        }
    }
}

private enum RemoteMigrationOutcome {
    case upserted
    case deferred
    case failed
}

private extension UserDataMigrationCollectionSummary {
    mutating func record(_ outcome: RemoteMigrationOutcome) {
        switch outcome {
        case .upserted:
            remoteUpserts += 1
        case .deferred:
            remoteDeferred += 1
        case .failed:
            failures += 1
        }
    }
}

private extension WorkoutLog {
    func rekeyed(to userId: String) -> WorkoutLog {
        WorkoutLog(
            id: id,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            plannedWorkoutName: plannedWorkoutName,
            startedAt: startedAt,
            completedAt: completedAt,
            exerciseEntries: exerciseEntries,
            overallNotes: overallNotes,
            overallRPE: overallRPE,
            durationMinutes: durationMinutes
        )
    }

    var isSupabaseMigrationCompatible: Bool {
        UUID(uuidString: id) != nil && UUID(uuidString: programId) != nil
    }
}

private extension WorkingWeight {
    func rekeyed(to userId: String) -> WorkingWeight {
        WorkingWeight(
            id: id,
            userId: userId,
            exerciseName: exerciseName,
            weightKg: weightKg,
            lastReps: lastReps,
            lastRPE: lastRPE,
            updatedAt: updatedAt,
            sourceLogId: sourceLogId,
            consecutiveSessionsAtTarget: consecutiveSessionsAtTarget
        )
    }
}

private extension UserSkillProgress {
    func rekeyed(to userId: String) -> UserSkillProgress {
        UserSkillProgress(
            userId: userId,
            nodeStates: nodeStates,
            achievedAt: achievedAt,
            masteredAt: masteredAt,
            updatedAt: updatedAt,
            skillProgress: skillProgress,
            lastTrainedAt: lastTrainedAt,
            bookmarkedNodeIds: bookmarkedNodeIds,
            activeGoalIds: activeGoalIds,
            weeklySchedule: weeklySchedule,
            currentWeekPhase: currentWeekPhase
        )
    }

    static func merging(
        legacy: UserSkillProgress,
        target: UserSkillProgress,
        targetUserId: String
    ) -> UserSkillProgress {
        let targetWasEmpty = target.isMigrationEmpty
        return UserSkillProgress(
            userId: targetUserId,
            nodeStates: legacy.nodeStates.merging(target.nodeStates) { _, target in target },
            achievedAt: legacy.achievedAt.merging(target.achievedAt) { legacy, target in
                legacy < target ? legacy : target
            },
            masteredAt: legacy.masteredAt.merging(target.masteredAt) { legacy, target in
                legacy < target ? legacy : target
            },
            updatedAt: legacy.updatedAt > target.updatedAt ? legacy.updatedAt : target.updatedAt,
            skillProgress: legacy.skillProgress.merging(target.skillProgress) { _, target in target },
            lastTrainedAt: legacy.lastTrainedAt.merging(target.lastTrainedAt) { legacy, target in
                legacy > target ? legacy : target
            },
            bookmarkedNodeIds: legacy.bookmarkedNodeIds.union(target.bookmarkedNodeIds),
            activeGoalIds: legacy.activeGoalIds.union(target.activeGoalIds),
            weeklySchedule: targetWasEmpty
                ? normalizedSchedule(legacy.weeklySchedule)
                : mergedSchedule(legacy: legacy.weeklySchedule, target: target.weeklySchedule),
            currentWeekPhase: targetWasEmpty ? legacy.currentWeekPhase : target.currentWeekPhase
        )
    }

    var isMigrationEmpty: Bool {
        nodeStates.isEmpty
            && achievedAt.isEmpty
            && masteredAt.isEmpty
            && skillProgress.isEmpty
            && lastTrainedAt.isEmpty
            && bookmarkedNodeIds.isEmpty
            && activeGoalIds.isEmpty
            && weeklySchedule.allSatisfy { $0 == nil }
            && currentWeekPhase == .moderate
    }

    func isMigrationEquivalent(to other: UserSkillProgress) -> Bool {
        userId == other.userId
            && nodeStates == other.nodeStates
            && achievedAt == other.achievedAt
            && masteredAt == other.masteredAt
            && updatedAt == other.updatedAt
            && skillProgress == other.skillProgress
            && lastTrainedAt == other.lastTrainedAt
            && bookmarkedNodeIds == other.bookmarkedNodeIds
            && activeGoalIds == other.activeGoalIds
            && weeklySchedule == other.weeklySchedule
            && currentWeekPhase == other.currentWeekPhase
    }

    static func mergedSchedule(
        legacy: [DayCategory?],
        target: [DayCategory?]
    ) -> [DayCategory?] {
        (0..<7).map { index in
            let targetValue = target.indices.contains(index) ? target[index] : nil
            let legacyValue = legacy.indices.contains(index) ? legacy[index] : nil
            return targetValue ?? legacyValue
        }
    }

    static func normalizedSchedule(_ schedule: [DayCategory?]) -> [DayCategory?] {
        (0..<7).map { index in
            schedule.indices.contains(index) ? schedule[index] : nil
        }
    }
}
