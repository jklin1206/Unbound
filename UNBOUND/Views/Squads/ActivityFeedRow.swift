// UNBOUND/Views/Squads/ActivityFeedRow.swift
//
// One line of squad activity ("Mara trained Push Day · 2h ago") in the
// calm-list language: flat on the page background, initials avatar in
// neutral tones, metadata as a MetaLine. Rendered by SquadCrewTab's RECENT
// section. Violet appears only on the streak milestone readout.
import SwiftUI

struct ActivityFeedRow: View {
    let entry: SquadActivityEntry
    let roster: [SquadMember]

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    /// "now" for anything under a minute — the formatter would otherwise say
    /// "in 0s" for entries created this second.
    private var relativeTime: String {
        if abs(entry.createdAt.timeIntervalSinceNow) < 60 { return "now" }
        return Self.relativeFormatter.localizedString(for: entry.createdAt, relativeTo: .now)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 2) {
                rowContent
                    .lineLimit(2)
                MetaLine([relativeTime])
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        switch entry.payload {
        case .squadStreakExtended:
            symbolCircle("flame.fill")
        case .linkedSession:
            symbolCircle("person.2.fill")
        case .memberJoined:
            symbolCircle("person.badge.plus")
        default:
            initialsCircle(for: entry.userId)
        }
    }

    private func symbolCircle(_ systemName: String) -> some View {
        ZStack {
            Circle().fill(Color.unbound.surfaceElevated)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - Row content

    @ViewBuilder
    private var rowContent: some View {
        switch entry.payload {
        case .workoutCompleted(let title, let exerciseCount, let durationMinutes):
            let detail = [
                title,
                exerciseCount > 0 ? "\(exerciseCount) exercises" : nil,
                durationMinutes.map { "\($0)m" }
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
            actorLine(name: displayName(for: entry.userId), action: " trained \(detail)")

        case .trialCompleted(let trialName, _):
            actorLine(name: displayName(for: entry.userId), action: " completed \(trialName)")

        case .titleUnlocked(let titleId):
            HStack(spacing: 6) {
                actorLine(name: displayName(for: entry.userId), action: " earned")
                TitleBadge(titleId: titleId, compact: true)
            }

        case .linkedSession(let participantIds, let durationMinutes):
            let names = participantIds
                .map { displayName(for: $0) }
                .prefix(2)
                .joined(separator: " & ")
            actorLine(name: names, action: " trained together · \(durationMinutes)m")

        case .memberJoined(let memberDisplayName):
            actorLine(name: memberDisplayName, action: " joined the squad")

        case .affinityChanged(let newAxis, let byDisplayName):
            actorLine(name: byDisplayName, action: " set affinity to \(newAxis?.displayName ?? "None")")

        case .squadStreakExtended(let weeks):
            Group {
                Text("Squad streak hit ")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                + Text("\(weeks) weeks")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.accent)
            }
        }
    }

    private func actorLine(name: String, action: String) -> some View {
        Group {
            Text(name)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            + Text(action)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    // MARK: - Helpers

    private func displayName(for userId: UUID?) -> String {
        guard let userId else { return "Squad" }
        return roster.first { $0.userId == userId }?.displayName ?? "Crewmate"
    }

    private func initials(for userId: UUID?) -> String {
        guard let userId,
              let member = roster.first(where: { $0.userId == userId }) else {
            return "?"
        }
        return member.displayName
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private func initialsCircle(for userId: UUID?) -> some View {
        ZStack {
            Circle().fill(Color.unbound.surfaceElevated)
            Text(initials(for: userId))
                .font(Font.unbound.captionS.weight(.heavy))
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(width: 34, height: 34)
    }
}

#Preview {
    let roster: [SquadMember] = [
        SquadMember(id: UUID(), squadId: UUID(), userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, joinedAt: .now, displayName: "Justin Lin", equippedTitle: nil, buildIdentity: nil),
        SquadMember(id: UUID(), squadId: UUID(), userId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, joinedAt: .now, displayName: "Alex Kim", equippedTitle: nil, buildIdentity: nil)
    ]
    let userId1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let userId2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let squadId = UUID()

    ScrollView {
        LazyVStack(spacing: 0) {
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: userId1, kind: .workoutCompleted, payload: .workoutCompleted(title: "Push Day", exerciseCount: 6, durationMinutes: 52), createdAt: Date().addingTimeInterval(-1200)),
                roster: roster
            )
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: userId2, kind: .titleUnlocked, payload: .titleUnlocked(titleId: TitleID(path: .axis(.power), tier: .gold)), createdAt: Date().addingTimeInterval(-3600)),
                roster: roster
            )
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: nil, kind: .squadStreakExtended, payload: .squadStreakExtended(weeks: 4), createdAt: Date().addingTimeInterval(-600)),
                roster: roster
            )
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: userId1, kind: .linkedSession, payload: .linkedSession(participantUserIds: [userId1, userId2], durationMinutes: 45), createdAt: Date().addingTimeInterval(-1800)),
                roster: roster
            )
        }
        .padding(.horizontal, 20)
    }
    .background(Color.unbound.bg)
}
