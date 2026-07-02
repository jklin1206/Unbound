// UNBOUND/Views/Squads/SquadMemberRow.swift
//
// One roster member as a calm list row: initials avatar (green dot when
// live), name, and a MetaLine of real training facts (last trained, sessions
// this week). The viewer's own row is the only raised surface in the list.
import SwiftUI

struct SquadMemberRow: View {
    let member: SquadMember
    var isLive: Bool = false
    var isSelf: Bool = false
    var weeklySessionCount: Int = 0
    var lastTrainedAt: Date?
    var displayNameOverride: String?
    let onTap: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var resolvedName: String {
        displayNameOverride ?? member.displayName
    }

    private var lastTrainedText: String {
        if isLive { return "Training now" }
        guard let lastTrainedAt else { return "No sessions yet" }
        if abs(lastTrainedAt.timeIntervalSinceNow) < 60 { return "Trained just now" }
        return "Trained " + Self.relativeFormatter.localizedString(for: lastTrainedAt, relativeTo: .now)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(resolvedName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    MetaLine([
                        lastTrainedText,
                        weeklySessionCount > 0 ? "\(weeklySessionCount) this wk" : nil
                    ])
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, isSelf ? 12 : 0)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .activeSurface(isSelf, cornerRadius: 14)
        .accessibilityLabel("\(resolvedName), \(lastTrainedText)")
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(Color.unbound.surfaceElevated)
                Text(initials)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            .frame(width: 38, height: 38)

            if isLive {
                Circle()
                    .fill(Color.unbound.success)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Color.unbound.bg, lineWidth: 2))
            }
        }
    }

    private var initials: String {
        let parts = resolvedName
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()
        return parts.isEmpty ? "U" : parts
    }
}

#Preview {
    let squadId = UUID()
    VStack(spacing: 0) {
        SquadMemberRow(
            member: SquadMember(id: UUID(), squadId: squadId, userId: UUID(), joinedAt: .now, displayName: "You", equippedTitle: nil, buildIdentity: nil),
            isLive: true,
            isSelf: true,
            weeklySessionCount: 4,
            lastTrainedAt: Date().addingTimeInterval(-3600),
            displayNameOverride: "You",
            onTap: {}
        )
        SquadMemberRow(
            member: SquadMember(id: UUID(), squadId: squadId, userId: UUID(), joinedAt: .now, displayName: "Mara Chen", equippedTitle: nil, buildIdentity: nil),
            weeklySessionCount: 2,
            lastTrainedAt: Date().addingTimeInterval(-86400),
            onTap: {}
        )
        SquadMemberRow(
            member: SquadMember(id: UUID(), squadId: squadId, userId: UUID(), joinedAt: .now, displayName: "Kenji", equippedTitle: nil, buildIdentity: nil),
            onTap: {}
        )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
