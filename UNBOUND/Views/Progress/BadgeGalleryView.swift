import SwiftUI

// MARK: - BadgeGalleryView
//
// Grid of every badge in the catalog, split into unlocked vs locked.
// Tap a badge → detail sheet.

struct BadgeGalleryView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var badges: [Badge] = []
    @State private var selected: Badge?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 14)]

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(badges) { badge in
                            BadgeTile(badge: badge)
                                .onTapGesture {
                                    UnboundHaptics.medium()
                                    selected = badge
                                }
                        }
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: services.auth.currentUserId) {
            reload()
        }
        .sheet(item: $selected) { badge in
            BadgeDetailSheet(badge: badge)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.unbound.bg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ARCHIVE")
                .font(Font.unbound.monoS)
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(unlockedCount) / \(badges.count)")
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("badges unlocked")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unlockedCount: Int { badges.filter(\.isUnlocked).count }

    private func reload() {
        let userId = services.auth.currentUserId ?? "anonymous"
        badges = services.badges.allBadges(userId: userId)
    }
}

// MARK: - BadgeTile

private struct BadgeTile: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 10) {
            BadgeEmblemView(badge: badge, size: 78)
                .frame(height: 90)

            VStack(spacing: 2) {
                Text(badge.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(badge.isUnlocked ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    .lineLimit(1)
                Text(badge.isUnlocked ? badge.rarity.displayName.uppercased() : "LOCKED")
                    .font(Font.unbound.monoS)
                    .tracking(1.2)
                    .foregroundStyle(badge.isUnlocked ? badge.rarity.tint : Color.unbound.textTertiary)
            }
        }
    }
}

// MARK: - BadgeDetailSheet

private struct BadgeDetailSheet: View {
    let badge: Badge

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                BadgeEmblemView(badge: badge, size: 76)

                VStack(alignment: .leading, spacing: 4) {
                    Text(badge.displayName)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(badge.rarity.displayName.uppercased())
                        .font(Font.unbound.monoS)
                        .tracking(1.4)
                        .foregroundStyle(badge.rarity.tint)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("HOW TO EARN")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(badge.description)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let date = badge.unlockedAt {
                VStack(alignment: .leading, spacing: 6) {
                    Text("UNLOCKED")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(Self.formatter.string(from: date))
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Locked")
                        .font(Font.unbound.bodyM)
                }
                .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

#Preview {
    NavigationStack {
        BadgeGalleryView()
            .environmentObject(ServiceContainer.mock)
    }
}
