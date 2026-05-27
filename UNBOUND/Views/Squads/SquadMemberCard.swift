// UNBOUND/Views/Squads/SquadMemberCard.swift
import SwiftUI
import UIKit

struct SquadMemberCard: View {
    let member: SquadMember
    let presence: SquadPresence?
    var weeklySessionCount: Int = 0
    var accountabilityBadge: AccountabilityBadgeState?
    var displayNameOverride: String?
    var profileUserId: String?
    var cosmeticTier: RankTitle = .initiate
    let onTap: () -> Void

    @ObservedObject private var photoStore = ProfilePhotoStore.shared

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        avatar
                        Circle()
                            .fill(isActive ? Color.unbound.accent : Color.unbound.textTertiary)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.unbound.bg, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let titleId = member.equippedTitle {
                            TitleBadge(titleId: titleId, compact: true)
                        } else {
                            Text("Untitled")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    metricPill("\(weeklySessionCount)", "WK")
                    if let accountabilityBadge {
                        metricPill(accountabilityBadge.currentTier.roman, "ACCT")
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary.opacity(0.8))
                }

                if let presence, presence.isActive {
                    presenceChip(startedAt: presence.workoutStartedAt)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (isActive ? Color.unbound.accent : Color.unbound.surfaceElevated).opacity(isActive ? 0.18 : 0.82),
                                Color.unbound.surface.opacity(0.90),
                                Color.unbound.bg.opacity(0.62)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isActive ? Color.unbound.accent.opacity(0.42) : Color.unbound.borderSubtle, lineWidth: 1)
            )
            .shadow(color: isActive ? Color.unbound.accent.opacity(0.12) : Color.black.opacity(0.16), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var isActive: Bool {
        presence?.isActive == true
    }

    private var displayName: String {
        let override = displayNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let override, !override.isEmpty { return override }
        return member.displayName
    }

    private var resolvedProfileUserId: String {
        profileUserId ?? member.userId.uuidString
    }

    private var profileImage: UIImage? {
        photoStore.image(userId: resolvedProfileUserId)
    }

    private var avatar: some View {
        let initials = displayName.split(separator: " ").compactMap { $0.first }.prefix(2)
        let initialString = initials.map(String.init).joined()
        return CosmeticAvatar(
            tier: cosmeticTier,
            size: 50,
            image: profileImage,
            letterFallback: initialString.isEmpty ? "U" : initialString
        )
        .shadow(color: cosmeticTier.rewardTint.opacity(0.22), radius: 10, y: 5)
    }

    private func presenceChip(startedAt: Date) -> some View {
        let elapsedMinutes = Int(Date.now.timeIntervalSince(startedAt) / 60)
        return HStack(spacing: 4) {
            Circle().fill(Color.unbound.accent).frame(width: 6, height: 6)
            Text("IN WORKOUT · \(elapsedMinutes)m")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
    }

    private func metricPill(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.unbound.bg.opacity(0.46)))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 12) {
        SquadMemberCard(
            member: SquadMember(
                id: UUID(),
                squadId: UUID(),
                userId: UUID(),
                joinedAt: Date(),
                displayName: "Justin Lin",
                equippedTitle: nil,
                buildIdentity: nil
            ),
            presence: SquadPresence(
                userId: UUID(),
                squadId: UUID(),
                workoutStartedAt: Date().addingTimeInterval(-23 * 60),
                expiresAt: Date().addingTimeInterval(3600)
            ),
            displayNameOverride: "Justin Lin",
            onTap: {}
        )
        SquadMemberCard(
            member: SquadMember(
                id: UUID(),
                squadId: UUID(),
                userId: UUID(),
                joinedAt: Date(),
                displayName: "Alex Kim",
                equippedTitle: nil,
                buildIdentity: nil
            ),
            presence: nil,
            onTap: {}
        )
    }
    .padding(16)
    .background(Color.unbound.bg)
}
