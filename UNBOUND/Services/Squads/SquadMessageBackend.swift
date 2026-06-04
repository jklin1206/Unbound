// UNBOUND/Services/Squads/SquadMessageBackend.swift
import Foundation
import Supabase

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
