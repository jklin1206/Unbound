// UNBOUND/Services/Squads/SquadActivityBackend.swift
import Foundation
import Supabase

// MARK: - Production backend
//
// Reads/writes to the `squad_activity` Supabase table.
// Tests never touch this file — they use MockSquadActivityBackend.

final class SquadActivityBackend: SquadActivityBackendProtocol, @unchecked Sendable {
    static let shared = SquadActivityBackend()
    private let logger = LoggingService.shared

    private init() {}

    // MARK: - Private Codable row type

    // SquadActivityEntry has an associated-value enum payload, which
    // doesn't round-trip cleanly through Codable automatically.
    // We store `kind` + `payload` as a flat JSON blob in the DB and
    // reconstitute them with the encoding helpers below.

    private struct ActivityRow: Codable {
        let id: UUID
        let squad_id: UUID
        let user_id: UUID?
        let kind: String
        let payload: ActivityPayloadJSON
        let created_at: Date

        func toModel() -> SquadActivityEntry? {
            guard let entryKind = SquadActivityEntry.Kind(rawValue: kind) else { return nil }
            guard let activityPayload = payload.toPayload(kind: entryKind) else { return nil }
            return SquadActivityEntry(
                id: id,
                squadId: squad_id,
                userId: user_id,
                kind: entryKind,
                payload: activityPayload,
                createdAt: created_at
            )
        }
    }

    // Flat JSON representation of SquadActivityPayload stored in the `payload` jsonb column.
    // TrialTheme and TitleID have associated values that can't use rawValue directly,
    // so we serialize them to plain string fields here.
    private struct ActivityPayloadJSON: Codable {
        // trialCompleted
        var trialName: String?
        var themeAxis: String?          // AttributeKey rawValue, nil = wildcard
        var themeIsWildcard: Bool?
        // titleUnlocked — store as a pre-encoded display string since TitleID is complex
        var titleDisplayName: String?
        // linkedSession
        var participantUserIds: [String]?
        var durationMinutes: Int?
        // memberJoined
        var memberDisplayName: String?
        // affinityChanged
        var newAxis: String?
        var byDisplayName: String?
        // squadStreakExtended
        var weeks: Int?

        func toPayload(kind: SquadActivityEntry.Kind) -> SquadActivityPayload? {
            switch kind {
            case .trialCompleted:
                guard let name = trialName else { return nil }
                let theme: TrialTheme
                if themeIsWildcard == true {
                    theme = .wildcard
                } else if let axisRaw = themeAxis,
                          let axis = AttributeKey(rawValue: axisRaw) {
                    theme = .axis(axis)
                } else {
                    theme = .wildcard
                }
                return .trialCompleted(trialName: name, theme: theme)
            case .titleUnlocked:
                // Round-trip via display name is lossy; this path is display-only in activity feed.
                // Re-decode uses a placeholder TitleID (axis: .power, tier: .bronze) — the display
                // name is stored alongside for rendering. Full re-construction would need a TitleID
                // encoding scheme stored as separate columns; deferred.
                let fallback = TitleID(path: .axis(.power), tier: .bronze)
                return .titleUnlocked(titleId: fallback)
            case .linkedSession:
                let ids = (participantUserIds ?? []).compactMap(UUID.init)
                return .linkedSession(participantUserIds: ids, durationMinutes: durationMinutes ?? 0)
            case .memberJoined:
                return .memberJoined(memberDisplayName: memberDisplayName ?? "")
            case .affinityChanged:
                let axis = newAxis.flatMap { AttributeKey(rawValue: $0) }
                return .affinityChanged(newAxis: axis, byDisplayName: byDisplayName ?? "")
            case .squadStreakExtended:
                return .squadStreakExtended(weeks: weeks ?? 0)
            }
        }
    }

    // Converts a SquadActivityEntry into the flat JSON shape for Supabase insert.
    private struct ActivityInsertRow: Encodable {
        let id: String
        let squad_id: String
        let user_id: String?
        let kind: String
        let payload: ActivityPayloadJSON
    }

    private func makeInsertRow(from entry: SquadActivityEntry) -> ActivityInsertRow {
        var p = ActivityPayloadJSON()
        switch entry.payload {
        case let .trialCompleted(name, theme):
            p.trialName = name
            switch theme {
            case .axis(let key):
                p.themeAxis = key.rawValue
                p.themeIsWildcard = false
            case .wildcard:
                p.themeIsWildcard = true
            }
        case let .titleUnlocked(titleId):
            p.titleDisplayName = titleId.displayName
        case let .linkedSession(ids, duration):
            p.participantUserIds = ids.map(\.uuidString)
            p.durationMinutes = duration
        case let .memberJoined(displayName):
            p.memberDisplayName = displayName
        case let .affinityChanged(axis, byName):
            p.newAxis = axis?.rawValue
            p.byDisplayName = byName
        case let .squadStreakExtended(weeks):
            p.weeks = weeks
        }
        return ActivityInsertRow(
            id: entry.id.uuidString,
            squad_id: entry.squadId.uuidString,
            user_id: entry.userId?.uuidString,
            kind: entry.kind.rawValue,
            payload: p
        )
    }

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }

    // MARK: - SquadActivityBackendProtocol

    func insert(_ entry: SquadActivityEntry) async {
        let row = makeInsertRow(from: entry)
        do {
            try await db
                .from("squad_activity")
                .insert(row)
                .execute()
        } catch {
            logger.log(
                "SquadActivityBackend.insert failed: \(error)",
                level: .warning,
                context: ["kind": entry.kind.rawValue]
            )
        }
    }

    func fetchRecent(squadId: UUID, limit: Int) async throws -> [SquadActivityEntry] {
        let rows: [ActivityRow] = try await db
            .from("squad_activity")
            .select()
            .eq("squad_id", value: squadId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap { $0.toModel() }
    }
}

// MARK: - SquadMessage storage

protocol SquadMessageBackendProtocol: AnyObject {
    func fetchRecentMessages(squadId: UUID, limit: Int) async throws -> [SquadMessage]
    func insertMessage(_ message: SquadMessage, clientMessageId: String?) async throws -> SquadMessage
    func addReaction(_ reaction: SquadMessageReaction, squadId: UUID) async throws -> SquadMessageReaction
    func deleteReaction(messageId: UUID, userId: UUID, emoji: SquadMessageReaction.Emoji) async throws
    func reportMessage(messageId: UUID, reporterUserId: UUID, reason: String, detail: String?) async throws
}

struct SquadMessageStoragePayload: Codable, Equatable, Sendable {
    var body: String?
    var title: String?
    var detail: String?
    var durationMinutes: Int?
    var challengeId: String?
    var shareId: String?
    var workoutTitle: String?
    var sharedById: String?
}

enum SquadMessageStorageCoder {
    static func storageKind(for kind: SquadMessage.Kind) -> String {
        switch kind {
        case .text: return "text"
        case .workout: return "workout"
        case .pr: return "pr"
        case .vowSeal: return "vowSeal"
        case .challengeEvent: return "challengeEvent"
        case .savedWorkoutShare: return "savedWorkoutShare"
        case .system: return "system"
        }
    }

    static func payload(for kind: SquadMessage.Kind) -> SquadMessageStoragePayload {
        var payload = SquadMessageStoragePayload()
        switch kind {
        case .text(let value):
            payload.body = value.body
        case .workout(let value):
            payload.title = value.title
            payload.durationMinutes = value.durationMinutes
        case .pr(let value):
            payload.title = value.title
            payload.detail = value.detail
        case .vowSeal(let value):
            payload.title = value.title
        case .challengeEvent(let value):
            payload.title = value.title
            payload.detail = value.detail
            payload.challengeId = value.challengeId?.uuidString
        case .savedWorkoutShare(let value):
            payload.shareId = value.shareId.uuidString
            payload.workoutTitle = value.workoutTitle
            payload.sharedById = value.sharedById.uuidString
        case .system(let value):
            payload.body = value.body
        }
        return payload
    }

    static func messageKind(storageKind: String, payload: SquadMessageStoragePayload) -> SquadMessage.Kind? {
        switch storageKind {
        case "text":
            guard let body = payload.body else { return nil }
            return .text(.init(body: body))
        case "workout":
            guard let title = payload.title else { return nil }
            return .workout(.init(title: title, durationMinutes: payload.durationMinutes))
        case "pr":
            guard let title = payload.title, let detail = payload.detail else { return nil }
            return .pr(.init(title: title, detail: detail))
        case "vowSeal":
            guard let title = payload.title else { return nil }
            return .vowSeal(.init(title: title))
        case "challengeEvent":
            guard let title = payload.title, let detail = payload.detail else { return nil }
            return .challengeEvent(.init(
                title: title,
                detail: detail,
                challengeId: payload.challengeId.flatMap(UUID.init(uuidString:))
            ))
        case "savedWorkoutShare":
            guard
                let shareIdRaw = payload.shareId,
                let shareId = UUID(uuidString: shareIdRaw),
                let workoutTitle = payload.workoutTitle,
                let sharedByRaw = payload.sharedById,
                let sharedById = UUID(uuidString: sharedByRaw)
            else { return nil }
            return .savedWorkoutShare(.init(
                shareId: shareId,
                workoutTitle: workoutTitle,
                sharedById: sharedById
            ))
        case "system":
            guard let body = payload.body else { return nil }
            return .system(.init(body: body))
        default:
            return nil
        }
    }
}

private struct SquadMessageReactionRow: Codable {
    let id: UUID
    let message_id: UUID
    let user_id: UUID
    let emoji: String
    let created_at: Date

    func toModel() -> SquadMessageReaction? {
        guard let emoji = SquadMessageReaction.Emoji(rawValue: emoji) else { return nil }
        return SquadMessageReaction(
            id: id,
            messageId: message_id,
            userId: user_id,
            emoji: emoji,
            createdAt: created_at
        )
    }
}

private struct SquadMessageRow: Codable {
    let id: UUID
    let squad_id: UUID
    let author_user_id: UUID?
    let kind: String
    let payload: SquadMessageStoragePayload
    let created_at: Date
    let updated_at: Date?
    let deleted_at: Date?
    let squad_message_reactions: [SquadMessageReactionRow]?

    func toModel() -> SquadMessage? {
        guard deleted_at == nil,
              let messageKind = SquadMessageStorageCoder.messageKind(storageKind: kind, payload: payload)
        else { return nil }
        return SquadMessage(
            id: id,
            squadId: squad_id,
            authorUserId: author_user_id,
            kind: messageKind,
            reactions: (squad_message_reactions ?? []).compactMap { $0.toModel() },
            createdAt: created_at
        )
    }
}

final class SquadMessageBackend: SquadMessageBackendProtocol, @unchecked Sendable {
    static let shared = SquadMessageBackend()
    private let logger = LoggingService.shared

    private init() {}

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }

    func fetchRecentMessages(squadId: UUID, limit: Int) async throws -> [SquadMessage] {
        let rows: [SquadMessageRow] = try await db
            .from("squad_messages")
            .select("*, squad_message_reactions(*)")
            .eq("squad_id", value: squadId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap { $0.toModel() }
    }

    func insertMessage(_ message: SquadMessage, clientMessageId: String?) async throws -> SquadMessage {
        struct InsertRow: Encodable {
            let id: String
            let squad_id: String
            let author_user_id: String?
            let kind: String
            let payload: SquadMessageStoragePayload
            let client_message_id: String?
        }
        let row = InsertRow(
            id: message.id.uuidString,
            squad_id: message.squadId.uuidString,
            author_user_id: message.authorUserId?.uuidString,
            kind: SquadMessageStorageCoder.storageKind(for: message.kind),
            payload: SquadMessageStorageCoder.payload(for: message.kind),
            client_message_id: clientMessageId
        )

        do {
            let rows: [SquadMessageRow] = try await db
                .from("squad_messages")
                .insert(row)
                .select("*, squad_message_reactions(*)")
                .execute()
                .value
            return rows.compactMap { $0.toModel() }.first ?? message
        } catch {
            logger.log("SquadMessageBackend.insertMessage failed: \(error)", level: .warning)
            throw error
        }
    }

    func addReaction(_ reaction: SquadMessageReaction, squadId: UUID) async throws -> SquadMessageReaction {
        struct ReactionInsertRow: Encodable {
            let id: String
            let message_id: String
            let user_id: String
            let emoji: String
        }
        let row = ReactionInsertRow(
            id: reaction.id.uuidString,
            message_id: reaction.messageId.uuidString,
            user_id: reaction.userId.uuidString,
            emoji: reaction.emoji.rawValue
        )
        let rows: [SquadMessageReactionRow] = try await db
            .from("squad_message_reactions")
            .insert(row)
            .select()
            .execute()
            .value
        return rows.compactMap { $0.toModel() }.first ?? reaction
    }

    func deleteReaction(messageId: UUID, userId: UUID, emoji: SquadMessageReaction.Emoji) async throws {
        try await db
            .from("squad_message_reactions")
            .delete()
            .eq("message_id", value: messageId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .eq("emoji", value: emoji.rawValue)
            .execute()
    }

    func reportMessage(messageId: UUID, reporterUserId: UUID, reason: String, detail: String?) async throws {
        struct ReportInsertRow: Encodable {
            let message_id: String
            let reporter_user_id: String
            let reason: String
            let detail: String?
        }
        try await db
            .from("squad_message_reports")
            .insert(ReportInsertRow(
                message_id: messageId.uuidString,
                reporter_user_id: reporterUserId.uuidString,
                reason: reason,
                detail: detail
            ))
            .execute()
    }
}

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
            let saved = try await backend.insertMessage(message, clientMessageId: message.id.uuidString)
            return saved
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
