import Foundation

actor SquadMessageService {
    static let shared = SquadMessageService()

    private let backend: SquadMessageBackendProtocol
    private let logger = LoggingService.shared
    private var localMessages: [UUID: [SquadMessage]] = [:]

    init(backend: SquadMessageBackendProtocol = SquadMessageBackend.shared) {
        self.backend = backend
    }

    func fetchRecent(
        squadId: UUID,
        fallbackMessages: [SquadMessage],
        limit: Int = 80
    ) async -> [SquadMessage] {
        do {
            let remote = try await backend.fetchRecentMessages(squadId: squadId, limit: limit)
            let merged = Self.mergedMessages(remote + (localMessages[squadId] ?? []), fallbackMessages)
            localMessages[squadId] = merged.filter { $0.authorUserId == nil || isLocalOnly($0.authorUserId) }
            return merged
        } catch {
            logger.log("SquadMessageService.fetchRecent falling back locally: \(error)", level: .debug)
            return Self.mergedMessages(localMessages[squadId] ?? [], fallbackMessages)
        }
    }

    func sendText(squadId: UUID, authorUserId: UUID?, body: String) async -> SquadMessage {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = SquadMessage(
            id: UUID(),
            squadId: squadId,
            authorUserId: authorUserId,
            kind: .text(.init(body: String(cleanBody.prefix(1000)))),
            reactions: [],
            createdAt: Date()
        )

        return await sendMessage(message)
    }

    func sendMessage(_ message: SquadMessage) async -> SquadMessage {
        guard message.authorUserId != nil else {
            appendLocal(message)
            return message
        }

        do {
            return try await backend.insertMessage(message, clientMessageId: message.id.uuidString)
        } catch {
            logger.log("SquadMessageService.sendText saved local fallback: \(error)", level: .warning)
            appendLocal(message)
            return message
        }
    }

    func setReaction(
        emoji: SquadMessageReaction.Emoji,
        messageId: UUID,
        squadId: UUID,
        userId: UUID,
        shouldAdd: Bool
    ) async {
        do {
            if shouldAdd {
                _ = try await backend.addReaction(
                    SquadMessageReaction(
                        id: UUID(),
                        messageId: messageId,
                        userId: userId,
                        emoji: emoji,
                        createdAt: Date()
                    ),
                    squadId: squadId
                )
            } else {
                try await backend.deleteReaction(messageId: messageId, userId: userId, emoji: emoji)
            }
        } catch {
            logger.log("SquadMessageService.setReaction failed: \(error)", level: .warning)
        }
    }

    func report(messageId: UUID, reporterUserId: UUID?, reason: String = "inappropriate", detail: String? = nil) async {
        guard let reporterUserId else { return }
        do {
            try await backend.reportMessage(
                messageId: messageId,
                reporterUserId: reporterUserId,
                reason: reason,
                detail: detail
            )
        } catch {
            logger.log("SquadMessageService.report failed: \(error)", level: .warning)
        }
    }

    nonisolated static func mergedMessages(_ lhs: [SquadMessage], _ rhs: [SquadMessage]) -> [SquadMessage] {
        var byId: [UUID: SquadMessage] = [:]
        for message in rhs {
            byId[message.id] = message
        }
        for message in lhs {
            byId[message.id] = message
        }
        return byId.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func appendLocal(_ message: SquadMessage) {
        var existing = localMessages[message.squadId] ?? []
        existing.removeAll { $0.id == message.id }
        existing.append(message)
        localMessages[message.squadId] = existing.sorted { $0.createdAt > $1.createdAt }
    }

    private func isLocalOnly(_ userId: UUID?) -> Bool {
        guard let userId else { return false }
        return SquadUserIdentity.usesLocalOnlySquad(for: userId.uuidString)
    }
}

actor SquadRoutineDropService {
    static let shared = SquadRoutineDropService()

    private let backend: SquadRoutineDropBackendProtocol
    private let messageService: SquadMessageService
    private let logger = LoggingService.shared
    private var localDrops: [UUID: [SquadRoutineDrop]] = [:]

    init(
        backend: SquadRoutineDropBackendProtocol = SquadRoutineDropBackend.shared,
        messageService: SquadMessageService = .shared
    ) {
        self.backend = backend
        self.messageService = messageService
    }

    func share(
        workout: SavedWorkout,
        note: String?,
        squad: Squad,
        authorUserId: UUID,
        authorDisplayName: String
    ) async -> SquadRoutineDrop {
        let drop = SquadRoutineDrop(
            squadId: squad.id,
            authorUserId: authorUserId,
            authorDisplayName: authorDisplayName,
            title: workout.title,
            note: note,
            workout: workout
        )

        let savedDrop: SquadRoutineDrop
        if SquadUserIdentity.usesLocalOnlySquad(for: authorUserId.uuidString) {
            appendLocal(drop)
            savedDrop = drop
        } else {
            do {
                savedDrop = try await backend.insertDrop(drop)
            } catch {
                logger.log("SquadRoutineDropService.share saved local fallback: \(error)", level: .warning)
                appendLocal(drop)
                savedDrop = drop
            }
        }

        await publishShareMessage(for: savedDrop)
        NotificationCenter.default.post(name: .squadRoutineDropShared, object: savedDrop)
        return savedDrop
    }

    func fetchRecent(squadId: UUID, limit: Int = 20) async -> [SquadRoutineDrop] {
        do {
            let remote = try await backend.fetchRecentDrops(squadId: squadId, limit: limit)
            let merged = Self.mergedDrops(remote + (localDrops[squadId] ?? []))
            localDrops[squadId] = Self.mergedDrops(localDrops[squadId] ?? [])
            return Array(merged.prefix(limit))
        } catch {
            logger.log("SquadRoutineDropService.fetchRecent falling back locally: \(error)", level: .debug)
            return Array((localDrops[squadId] ?? []).prefix(limit))
        }
    }

    nonisolated static func mergedDrops(_ drops: [SquadRoutineDrop]) -> [SquadRoutineDrop] {
        var byId: [UUID: SquadRoutineDrop] = [:]
        for drop in drops {
            byId[drop.id] = drop
        }
        return byId.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func appendLocal(_ drop: SquadRoutineDrop) {
        var existing = localDrops[drop.squadId] ?? []
        existing.removeAll { $0.id == drop.id }
        existing.insert(drop, at: 0)
        localDrops[drop.squadId] = Self.mergedDrops(existing)
    }

    private func publishShareMessage(for drop: SquadRoutineDrop) async {
        let message = SquadMessage(
            id: UUID(),
            squadId: drop.squadId,
            authorUserId: drop.authorUserId,
            kind: .savedWorkoutShare(.init(
                shareId: drop.id,
                workoutTitle: drop.title,
                sharedById: drop.authorUserId
            )),
            reactions: [],
            createdAt: drop.createdAt
        )
        _ = await messageService.sendMessage(message)
    }
}
