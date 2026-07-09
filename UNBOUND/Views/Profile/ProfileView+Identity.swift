// UNBOUND/Views/Profile/ProfileView+Identity.swift
//
// The identity block inside the trophy header: handle/title stack, rank and
// level plates, and the display-string helpers derived from the profile.
import SwiftUI

extension ProfileView {

    func identityStack(
        level: Int,
        currentXP: Int,
        lastXPGain: Int,
        levelProgress: Double,
        rankColor: Color,
        rankTextColor: Color
    ) -> some View {
        let xpPerLevel = max(1, Int(OverallLevelCurve.xpRequired(forLevel: level + 1) - OverallLevelCurve.xpRequired(forLevel: level)))
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                // Identity editing lives in the Profile Kit hub (paintbrush)
                // — the name is just a second, more obvious door into it.
                showProfileCosmetics = true
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(profileIdentityName.uppercased())
                            .font(.system(size: 22, weight: .black))
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(profileIdentityName.count > 26 ? 2 : 1)
                            .minimumScaleFactor(profileIdentityName.count > 26 ? 0.52 : 0.62)
                            .allowsTightening(true)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let profileTitleLine {
                        Text(profileTitleLine.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(rankTextColor)
                            .lineLimit(profileTitleLine.count > 28 ? 2 : 1)
                            .minimumScaleFactor(0.58)
                            .allowsTightening(true)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile handle and title")

            // Rank reads as a quiet plate — the trial/gate details live on the
            // Home rank surfaces now, not behind an ⓘ here.
            RankTitlePlate(
                tier: aggregateTier,
                tint: rankColor
            )
            .frame(maxWidth: .infinity)

            LevelProgressPlate(
                currentXP: currentXP,
                xpPerLevel: xpPerLevel,
                lastXPGain: lastXPGain,
                progress: levelProgress,
                tint: rankColor,
                detail: "XP"
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    var profileIdentityName: String {
        playerHandle
    }

    var profileTitleLine: String? {
        trialsState.equippedTitle.map(TitleCatalog.displayName(for:))
    }

    var avatarInitial: String {
        if let handle = cleanedStoredHandle, let first = handle.first {
            return String(first).uppercased()
        }
        return "U"
    }

    private var playerHandle: String {
        if let handle = cleanedStoredHandle {
            return handle.uppercased()
        }
        return "PLAYER"
    }

    private var cleanedStoredHandle: String? {
        guard let handle = profile?.displayHandle else { return nil }
        let cleaned = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return cleaned.isEmpty ? nil : cleaned
    }
}
