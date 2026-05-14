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
