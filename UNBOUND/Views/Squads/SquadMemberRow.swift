// UNBOUND/Views/Squads/SquadMemberRow.swift
//
// One roster member: colored identity avatar (green dot when live), name,
// and real training facts. The viewer's own row highlights with a full-width
// elevated fill that never shifts the text (no indent).
import SwiftUI

struct SquadMemberRow: View {
    let member: SquadMember
    var isLive: Bool = false
    var isSelf: Bool = false
    var weeklySessionCount: Int = 0
    var lastTrainedAt: Date?
    var displayNameOverride: String?
    /// Cosmetic frame tier + equipped border (from the member's flair, resolved
    /// by the caller). Drives the avatar's frame + border so crewmates show the
    /// cosmetics they've equipped.
    var frameTier: RankTitle = .initiate
    var borderId: ShopProfileBorderID?
    var avatarImage: UIImage?
    let onTap: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var resolvedName: String {
        displayNameOverride ?? member.displayName
    }

    private var identityTint: Color {
        SquadMemberPalette.tint(for: member.userId)
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

                if weeklySessionCount > 0 {
                    Text("\(weeklySessionCount)")
                        .font(Font.unbound.monoM)
                        .foregroundStyle(identityTint)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .squadOwnRowHighlight(isSelf)
        .accessibilityLabel("\(resolvedName), \(lastTrainedText)")
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            CosmeticAvatar(
                tier: frameTier,
                size: 38,
                image: avatarImage,
                letterFallback: initials,
                shopBorder: borderId
            )

            if isLive {
                Circle()
                    .fill(Color.unbound.success)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Color.unbound.surface, lineWidth: 2))
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
    VStack(spacing: 2) {
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
    .padding(26)
    .background(RoundedRectangle(cornerRadius: 20).fill(Color.unbound.surface).padding(10))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
