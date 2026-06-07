import Foundation


enum ProgressionPersistenceMode {
    case bestEffort
    case strict
}

@MainActor
final class MovementProgressService {
    static let shared = MovementProgressService()

    private init() {}

    func ingest(
        _ log: PerformanceLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> MovementProgressIngestResult {
        do {
            return try await ingest(log, database: database, persistenceMode: .bestEffort)
        } catch {
            LoggingService.shared.log(
                "Movement progress best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": log.id]
            )
            return MovementProgressIngestResult()
        }
    }

    func ingestStrict(
        _ log: PerformanceLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> MovementProgressIngestResult {
        try await ingest(log, database: database, persistenceMode: .strict)
    }

    private func ingest(
        _ log: PerformanceLog,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> MovementProgressIngestResult {
        let priorStates = await loadPriorStates(
            userId: log.userId,
            standardIds: MovementAPCalculator.rankStandardMovementIds(from: log),
            database: database
        )
        let gains = MovementAPCalculator.gains(from: log, priorStates: priorStates)
        return try await persist(
            gains: gains,
            userId: log.userId,
            sourceLogId: log.id,
            priorStates: priorStates,
            database: database,
            persistenceMode: persistenceMode
        )
    }

    func ingest(
        _ log: WorkoutLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> MovementProgressIngestResult {
        do {
            return try await ingest(log, database: database, persistenceMode: .bestEffort)
        } catch {
            LoggingService.shared.log(
                "Movement progress best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": log.id]
            )
            return MovementProgressIngestResult()
        }
    }

    func ingestStrict(
        _ log: WorkoutLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> MovementProgressIngestResult {
        try await ingest(log, database: database, persistenceMode: .strict)
    }

    private func ingest(
        _ log: WorkoutLog,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> MovementProgressIngestResult {
        let priorStates = await loadPriorStates(
            userId: log.userId,
            standardIds: MovementAPCalculator.rankStandardMovementIds(from: log),
            database: database
        )
        let gains = MovementAPCalculator.gains(from: log, priorStates: priorStates)
        return try await persist(
            gains: gains,
            userId: log.userId,
            sourceLogId: log.id,
            priorStates: priorStates,
            database: database,
            persistenceMode: persistenceMode
        )
    }

    private func persist(
        gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        priorStates: [String: MovementProgressState] = [:],
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> MovementProgressIngestResult {
        let grouped = Dictionary(grouping: gains, by: \.rankStandardMovementId)
        var updatedStates: [MovementProgressState] = []
        var persistedGains: [MovementAPGain] = []
        var replayPriorStates = priorStates
        let profile = await loadUserProfile(userId: userId, database: database)

        for (standardId, standardGains) in grouped {
            guard let first = standardGains.first else { continue }
            var state = await loadState(
                userId: userId,
                standardId: standardId,
                fallback: first,
                database: database
            )

            if state.processedSourceLogIds.contains(sourceLogId) {
                if persistenceMode == .strict {
                    if let receipt = await loadPersistedMovementReceipt(
                        sourceLogId: sourceLogId,
                        standardId: standardId,
                        database: database
                    ) {
                        replayPriorStates[standardId] = receipt.priorState
                        updatedStates.append(receipt.updatedState)
                        persistedGains.append(contentsOf: receipt.gains)
                    } else {
                        let replayGains = await loadPersistedGains(
                            fallbackGains: standardGains,
                            database: database
                        )
                        if let replayPriorState = await loadPersistedPriorState(
                            sourceLogId: sourceLogId,
                            standardId: standardId,
                            database: database
                        ) {
                            replayPriorStates[standardId] = replayPriorState
                        }
                        updatedStates.append(state)
                        persistedGains.append(contentsOf: replayGains)
                    }
                }
                continue
            }

            let priorState = state
            state.apply(gains: standardGains, sourceLogId: sourceLogId)
            state.refreshProvenTier(
                bodyweightKg: profile?.weightKg,
                sex: profile?.biologicalSex
            )
            try await persistMovementArtifacts(
                priorState: priorState,
                state: state,
                gains: standardGains,
                sourceLogId: sourceLogId,
                database: database,
                persistenceMode: persistenceMode
            )

            updatedStates.append(state)
            persistedGains.append(contentsOf: standardGains)
        }

        if !updatedStates.isEmpty {
            NotificationCenter.default.post(
                name: .movementProgressUpdated,
                object: nil,
                userInfo: ["states": updatedStates]
            )
        }

        return MovementProgressIngestResult(
            gains: persistedGains,
            updatedStates: updatedStates,
            priorStates: replayPriorStates
        )
    }

    private func persistMovementArtifacts(
        priorState: MovementProgressState,
        state: MovementProgressState,
        gains: [MovementAPGain],
        sourceLogId: String,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws {
        switch persistenceMode {
        case .strict:
            try await database.create(
                priorState,
                collection: "movement_progress_prior_states",
                documentId: movementPriorStateDocumentId(
                    sourceLogId: sourceLogId,
                    standardId: state.rankStandardMovementId
                )
            )
            for gain in gains {
                try await database.create(gain, collection: "movement_ap_gains", documentId: gain.id)
            }
            try await database.create(
                MovementProgressSourceReceipt(
                    sourceLogId: sourceLogId,
                    userId: state.userId,
                    rankStandardMovementId: state.rankStandardMovementId,
                    gains: gains,
                    priorState: priorState,
                    updatedState: state
                ),
                collection: "movement_progress_source_receipts",
                documentId: movementPriorStateDocumentId(
                    sourceLogId: sourceLogId,
                    standardId: state.rankStandardMovementId
                )
            )
            try await database.create(state, collection: "movement_progress", documentId: state.id)
        case .bestEffort:
            do {
                try await database.create(state, collection: "movement_progress", documentId: state.id)
            } catch {
                LoggingService.shared.log(
                    "Movement progress state write failed: \(error)",
                    level: .warning,
                    context: ["documentId": state.id]
                )
            }
            for gain in gains {
                do {
                    try await database.create(gain, collection: "movement_ap_gains", documentId: gain.id)
                } catch {
                    LoggingService.shared.log(
                        "Movement AP gain write failed: \(error)",
                        level: .warning,
                        context: ["documentId": gain.id]
                    )
                }
            }
        }
    }

    private func loadPersistedPriorState(
        sourceLogId: String,
        standardId: String,
        database: any DatabaseServiceProtocol
    ) async -> MovementProgressState? {
        try? await database.read(
            collection: "movement_progress_prior_states",
            documentId: movementPriorStateDocumentId(sourceLogId: sourceLogId, standardId: standardId)
        )
    }

    private func loadPersistedMovementReceipt(
        sourceLogId: String,
        standardId: String,
        database: any DatabaseServiceProtocol
    ) async -> MovementProgressSourceReceipt? {
        try? await database.read(
            collection: "movement_progress_source_receipts",
            documentId: movementPriorStateDocumentId(sourceLogId: sourceLogId, standardId: standardId)
        )
    }

    private func movementPriorStateDocumentId(sourceLogId: String, standardId: String) -> String {
        "\(sourceLogId):\(standardId)"
    }

    private func loadPersistedGains(
        fallbackGains: [MovementAPGain],
        database: any DatabaseServiceProtocol
    ) async -> [MovementAPGain] {
        var gains: [MovementAPGain] = []
        for fallback in fallbackGains {
            if let persisted: MovementAPGain = try? await database.read(
                collection: "movement_ap_gains",
                documentId: fallback.id
            ) {
                gains.append(persisted)
            } else {
                gains.append(fallback)
            }
        }
        return gains
    }

    private func loadState(
        userId: String,
        standardId: String,
        fallback: MovementAPGain,
        database: any DatabaseServiceProtocol
    ) async -> MovementProgressState {
        let documentId = "\(userId):\(standardId)"
        if var existing: MovementProgressState = try? await database.read(
            collection: "movement_progress",
            documentId: documentId
        ) {
            if existing.displayName != fallback.standardDisplayName || existing.rankTemplate != fallback.rankTemplate {
                existing.displayName = fallback.standardDisplayName
                existing.rankTemplate = fallback.rankTemplate
                existing.updatedAt = Date()
            }
            return existing
        }

        return MovementProgressState(
            userId: userId,
            rankStandardMovementId: standardId,
            displayName: fallback.standardDisplayName,
            rankTemplate: fallback.rankTemplate
        )
    }

    private func loadUserProfile(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> UserProfile? {
        try? await database.read(collection: "users", documentId: userId)
    }

    private func loadPriorStates(
        userId: String,
        standardIds: [String],
        database: any DatabaseServiceProtocol
    ) async -> [String: MovementProgressState] {
        var states: [String: MovementProgressState] = [:]
        for standardId in standardIds {
            let documentId = "\(userId):\(standardId)"
            if let existing: MovementProgressState = try? await database.read(
                collection: "movement_progress",
                documentId: documentId
            ) {
                states[standardId] = existing
            }
        }
        return states
    }
}
