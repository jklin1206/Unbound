// UNBOUND/Views/Squads/ActivityFeedRow.swift
import SwiftUI

struct ActivityFeedRow: View {
    let entry: SquadActivityEntry
    let roster: [SquadMember]

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatarView
            VStack(alignment: .leading, spacing: 3) {
                rowContent
                Text(Self.relativeFormatter.localizedString(for: entry.createdAt, relativeTo: .now))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        switch entry.payload {
        case .squadStreakExtended:
            // System event — squad icon
            ZStack {
                Circle().fill(Color.unbound.accent.opacity(0.15))
                Image(systemName: "figure.2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .frame(width: 34, height: 34)

        case .linkedSession(let participantIds, _):
            // Stacked initials for first two participants
            ZStack(alignment: .leading) {
                initialsCircle(for: participantIds.first, offset: 0)
                if participantIds.count > 1 {
                    initialsCircle(for: participantIds.dropFirst().first, offset: 14)
                }
            }
            .frame(width: 48, height: 34)

        default:
            initialsCircle(for: entry.userId, offset: 0)
                .frame(width: 34, height: 34)
        }
    }

    // MARK: - Row content

    @ViewBuilder
    private var rowContent: some View {
        switch entry.payload {
        case .trialCompleted(let trialName, _):
            Group {
                Text(displayName(for: entry.userId))
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                + Text(" crushed \(trialName)")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

        case .titleUnlocked(let titleId):
            HStack(spacing: 6) {
                Group {
                    Text(displayName(for: entry.userId))
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    + Text(" earned")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                TitleBadge(titleId: titleId, compact: true)
            }

        case .linkedSession(let participantIds, let durationMinutes):
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.unbound.accent)
                let countLabel = participantIds.count > 1
                    ? "\(participantIds.count) members"
                    : displayName(for: participantIds.first)
                Text("Trained together · \(durationMinutes)m")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                + Text(" (\(countLabel))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.unbound.textTertiary)
            }

        case .memberJoined(let memberDisplayName):
            Group {
                Text(memberDisplayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                + Text(" joined the squad")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

        case .affinityChanged(let newAxis, let byDisplayName):
            let axisName = newAxis?.displayName ?? "None"
            Group {
                Text(byDisplayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                + Text(" set affinity to \(axisName)")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

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

    // MARK: - Helpers

    private func displayName(for userId: UUID?) -> String {
        guard let userId else { return "Squad" }
        return roster.first { $0.userId == userId }?.displayName ?? "Someone"
    }

    private func displayName(for userId: UUID) -> String {
        roster.first { $0.userId == userId }?.displayName ?? "Someone"
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

    @ViewBuilder
    private func initialsCircle(for userId: UUID?, offset: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.unbound.accent.opacity(0.2))
            Text(initials(for: userId))
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.unbound.accent)
        }
        .frame(width: 34, height: 34)
        .offset(x: offset)
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
            Divider()
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: userId1, kind: .trialCompleted, payload: .trialCompleted(trialName: "Endurance Push", theme: .axis(.endurance)), createdAt: Date().addingTimeInterval(-7200)),
                roster: roster
            )
            Divider()
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: userId2, kind: .titleUnlocked, payload: .titleUnlocked(titleId: TitleID(path: .axis(.power), tier: .gold)), createdAt: Date().addingTimeInterval(-3600)),
                roster: roster
            )
            Divider()
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: nil, kind: .squadStreakExtended, payload: .squadStreakExtended(weeks: 4), createdAt: Date().addingTimeInterval(-600)),
                roster: roster
            )
            Divider()
            ActivityFeedRow(
                entry: SquadActivityEntry(id: UUID(), squadId: squadId, userId: userId1, kind: .linkedSession, payload: .linkedSession(participantUserIds: [userId1, userId2], durationMinutes: 45), createdAt: Date().addingTimeInterval(-1800)),
                roster: roster
            )
            Divider()
        }
        .padding(.horizontal, 16)
    }
    .background(Color.unbound.bg)
}
