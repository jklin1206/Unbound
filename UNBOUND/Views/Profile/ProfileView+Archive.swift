// UNBOUND/Views/Profile/ProfileView+Archive.swift
//
// The archive stack below the header: build card, badges section, and the
// photo journey/calendar band — plus the shared band container + page wash.
import SwiftUI

extension ProfileView {

    var profileArchiveStack: some View {
        VStack(spacing: 14) {
            ProfileArchiveBand(tint: activeProfileTint) {
                ProfileBuildCard(
                    profile: attributeProfile,
                    classIdentity: BuildClassStore.shared.heldIdentity(
                        userId: attributeProfile.userId,
                        live: attributeProfile.buildIdentity
                    )
                )
            }

            ProfileArchiveBand(tint: Color.unbound.rankGold) {
                badgesArchiveSection
            }

            ProfileArchiveBand(tint: Color.unbound.impact) {
                VStack(spacing: 0) {
                    if let beforePhoto, let afterPhoto {
                        ProgressJourneySection(dayZero: beforePhoto, now: afterPhoto)
                    }
                    PhotoCalendarView().environmentObject(services)
                }
            }

            Spacer().frame(height: 118)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    var profileBaseWash: some View {
        LinearGradient(
            stops: [
                .init(color: activeProfileTint.opacity(0.10), location: 0),
                .init(color: Color.unbound.bg.opacity(0.98), location: 0.32),
                .init(color: Color.black.opacity(0.28), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Archive

    private var badgesArchiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BADGES")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("\(unlockedBadges.count) / \(totalBadgeCount) UNLOCKED")
                        .font(Font.unbound.titleS)
                        .tracking(0.7)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }
                Spacer()
                NavigationLink(destination: BadgeGalleryView().environmentObject(services)) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if unlockedBadges.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "seal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Earn your first badge by logging a session.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(unlockedBadges.prefix(10))) { b in
                            badgeTile(b)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            UnboundNativeDivider(opacity: 0.52)
        }
        .overlay(alignment: .bottom) {
            UnboundNativeDivider(opacity: 0.42)
        }
    }

    private func badgeTile(_ badge: Badge) -> some View {
        VStack(spacing: 6) {
            BadgeEmblemView(badge: badge, size: 58, isUnlocked: true)
            Text(badge.displayName.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 68)
    }
}

private struct ProfileArchiveBand<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surface.opacity(0.38),
                            tint.opacity(0.05),
                            Color.unbound.surface.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.72), lineWidth: 0.5)
        }
    }
}
