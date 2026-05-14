import SwiftUI

// MARK: - ProfileView
//
// The ARCHIVE counterpart to Home. Home is LIVE (what's happening today);
// Profile is identity, lifetime state, collection, and settings. Per the
// `project_unbound_home_vs_profile_boundary` memory:
//
//   Home  — today's mission, live rank, live streak, today's stats
//   Profile — who you've become: avatar, rank journey, badges grid,
//             photo library, stats history, settings
//
// This first-pass profile surfaces what we already compute on home at
// rest (rank, stats, badges, body map) and nests the existing
// SettingsView as a push destination for account/preferences.
//
// Deferred to future passes:
//   - Real scan photo library (grid of ProgressPhoto)
//   - Stats history charts (weekly/monthly trend)
//   - Rank journey timeline (when you crossed D → C → B)
//   - Titles collection (separate from badges, per rank memory)

struct ProfileView: View {
    @EnvironmentObject var services: ServiceContainer

    @State private var profile: UserProfile?
    @State private var aggregateRank: SubRank = .eMinus
    @State private var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)
    @State private var liftRanks: [LiftRank] = []
    @State private var heatmapRanks: [MuscleHeatGroup: SubRank] = [:]
    @State private var unlockedBadges: [Badge] = []
    @State private var totalBadgeCount: Int = 0
    @State private var totalWorkouts: Int = 0
    @State private var skillsObtained: Int = 0
    @State private var sessionXP: SessionXPRecord?
    @State private var manualPhotoCount: Int = 0
    @State private var scanPhotoCount: Int = 0
    @State private var isLoading = true

    @AppStorage("unbound.gains") private var gains: Int = 0
    private let xpPerLevel: Int = 250

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()

            // Rank-tier cosmetic backdrop behind the header.
            CosmeticBackdrop(tier: aggregateRank.title, maxHeight: 360)
                .ignoresSafeArea(edges: .top)

            if isLoading {
                ProgressView().tint(Color.unbound.accent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        ProfileBuildCard(profile: attributeProfile)
                        heatmapPlaceholder
                        PhotoCalendarView().environmentObject(services)
                        badgesCard
                        settingsLink
                        Spacer().frame(height: 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarHidden(true)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { _ in
            if let userId = services.auth.currentUserId {
                Task {
                    attributeProfile = services.attribute.profile(userId: userId)
                }
            }
        }
        .attributeRankUpToast()
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        services.badges.bind(userId: userId)

        do {
            profile = try await services.user.fetchProfile(userId: userId)
        } catch {
            profile = nil
        }

        let archetype = profile?.preferredArchetype ?? .vTaper
        aggregateRank = await services.rank.archetypeRank(userId: userId, archetype: archetype)
        attributeProfile = services.attribute.profile(userId: userId)

        liftRanks = await services.rank.fetchAll(userId: userId)
        var computed = MuscleRankCalculator.heatmapRanks(liftRanks: liftRanks)
        for g in MuscleHeatGroup.allCases where computed[g] == nil {
            computed[g] = .eMinus
        }
        heatmapRanks = computed

        unlockedBadges = services.badges.unlockedBadges(userId: userId)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        totalBadgeCount = BadgeCatalog.all.count
        sessionXP = services.sessionXP.record(userId: userId)

        let photos: [ProgressPhoto] = (try? await services.database.query(
            collection: "progressPhotos",
            field: "userId",
            isEqualTo: userId,
            orderBy: "capturedAt",
            descending: true,
            limit: 500
        )) ?? []
        manualPhotoCount = photos.filter { $0.source == .manual }.count
        scanPhotoCount = photos.filter { $0.source == .scan }.count

        // Total workouts + skills obtained — character-sheet vitals.
        let logs: [SessionLog] = (try? await services.database.query(
            collection: "sessionLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "createdAt",
            descending: true,
            limit: 1000
        )) ?? []
        totalWorkouts = logs.count

        let states = SkillProgressService.shared.nodeStates
        skillsObtained = states.values.filter { $0 == .achieved || $0 == .mastered }.count

        isLoading = false
    }

    // MARK: - Header card

    private var headerCard: some View {
        let level = (gains / xpPerLevel) + 1
        let levelProgress = Double(gains % xpPerLevel) / Double(xpPerLevel)
        let currentXP = gains % xpPerLevel
        let archetype = profile?.preferredArchetype
        let initial = avatarInitial
        let scanCount = max(profile?.totalScans ?? 0, scanPhotoCount)
        let rankColor = aggregateRank.regionTint

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UNBOUND")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)
                    Text("PROFILE")
                        .font(Font.unbound.titleM)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                NavigationLink(destination: SettingsView(services: services)) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.unbound.bg.opacity(0.75)))
                        .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center, spacing: 16) {
                CosmeticAvatar(
                    tier: aggregateRank.title,
                    size: 104,
                    image: nil, // future: user-uploaded profile photo
                    letterFallback: initial
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text(displayName.uppercased())
                        .font(Font.unbound.titleL)
                        .tracking(0.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        profilePill(archetype?.displayName.uppercased() ?? "UNBOUND")
                        profilePill("LV \(level)")
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(currentXP) / \(xpPerLevel) SP")
                                .font(Font.unbound.monoS.weight(.bold))
                                .foregroundStyle(Color.unbound.textSecondary)
                            Spacer()
                            Text(longestStreakLabel)
                                .font(Font.unbound.monoS)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .lineLimit(1)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.unbound.borderSubtle)
                                Capsule()
                                    .fill(rankColor)
                                    .frame(width: max(6, proxy.size.width * levelProgress))
                                    .shadow(color: rankColor.opacity(0.45), radius: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }

            HStack(spacing: 8) {
                profileMetric(label: "BEST", value: "\(sessionXP?.longestStreak ?? 0)D")
                profileMetric(label: "SCANS", value: "\(scanCount)")
                profileMetric(label: "PHOTOS", value: "\(manualPhotoCount)")
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
                DossierLinework(color: rankColor)
                    .opacity(0.42)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(rankColor.opacity(0.24), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func profilePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Color.unbound.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.unbound.bg.opacity(0.72)))
            .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private func profileMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoM.weight(.black))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var displayName: String {
        if let name = profile?.displayName, !name.isEmpty { return name }
        if let archetype = profile?.preferredArchetype {
            return archetype.shortName.uppercased()
        }
        return "UNBOUND"
    }

    private var avatarInitial: String {
        if let name = profile?.displayName, let first = name.first {
            return String(first).uppercased()
        }
        if let archetype = profile?.preferredArchetype {
            return String(archetype.shortName.prefix(1)).uppercased()
        }
        return "U"
    }

    private var longestStreakLabel: String {
        let longest = sessionXP?.longestStreak ?? 0
        if longest == 0 { return "NO STREAK YET" }
        return "BEST \(longest)-DAY STREAK"
    }

    // MARK: - Rank journey card

    private var rankJourneyCard: some View {
        let nextRank = aggregateRank.advanced(by: 1)
        let ordinal = aggregateRank.ordinal
        let journeyFraction = max(0.05, min(1.0, Double(ordinal) / 17.0))
        let rankColor = aggregateRank.regionTint

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("RANK JOURNEY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(ordinal + 1) / 18")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            HStack(alignment: .center, spacing: 12) {
                RankBadge(rank: aggregateRank, size: .small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(aggregateRank.displayName.uppercased())
                        .font(Font.unbound.monoM)
                        .tracking(1.6)
                        .foregroundStyle(rankColor)
                    Text("TITLE \(ordinal + 1) / 18")
                        .font(Font.unbound.captionS)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(nextRank.displayName)
                        .font(Font.unbound.monoM.weight(.bold))
                        .foregroundStyle(nextRank.regionTint)
                }
            }

            rankJourneyBar(fraction: journeyFraction, color: rankColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [rankColor.opacity(0.12), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
            }
        )
    }

    private func rankJourneyBar(fraction: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.borderSubtle)
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, proxy.size.width * fraction))
                        .shadow(color: color.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 4)

            HStack(spacing: 0) {
                ForEach(RankTitle.allCases, id: \.self) { title in
                    Text(title.displayName.prefix(3).uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(rankTickColor(for: title))
                        .frame(maxWidth: .infinity)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }

    private func rankTickColor(for title: RankTitle) -> Color {
        let ord = SubRank.allCases.first(where: { $0.title == title })?.ordinal ?? 0
        return ord <= aggregateRank.ordinal
            ? Color.unbound.textSecondary
            : Color.unbound.textTertiary.opacity(0.5)
    }

    // MARK: - Heatmap placeholder
    //
    // Per design memory: heatmap slot kept, render dropped. The full
    // muscle-group heatmap will land alongside the per-skill rank
    // migration. For now this card holds the slot so users see where
    // it'll live and the profile doesn't feel hollow.

    private var heatmapPlaceholder: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("MUSCLE HEATMAP")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("COMING SOON")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.accent)
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Color.unbound.accent.opacity(0.65))
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Per-muscle progression")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Track Chest · Lats · Quads · Glutes · Core through every PR and skill mastered. Lights up as you train.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    // MARK: - Badges card

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.unbound.bg.opacity(0.75)))
                        .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
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

    // MARK: - Photo library placeholder

    private var photoLibraryPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PHOTO LIBRARY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("COMING SOON")
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.bg)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.unbound.textTertiary.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                        .aspectRatio(0.72, contentMode: .fit)
                }
            }
            Text("Your front + back scan progression will live here.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    // MARK: - Settings link

    private var settingsLink: some View {
        NavigationLink(destination: SettingsView(services: services)) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("SETTINGS")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func tierName(for rank: SubRank) -> String {
        rank.displayName
    }
}

private struct DossierLinework: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.58, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.44))
                    path.move(to: CGPoint(x: width * 0.72, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.24))
                    path.move(to: CGPoint(x: width * 0.05, y: height * 0.72))
                    path.addLine(to: CGPoint(x: width * 0.42, y: height))
                }
                .stroke(color.opacity(0.26), lineWidth: 1)

                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Rectangle()
                            .fill(Color.unbound.borderSubtle.opacity(0.42))
                            .frame(width: width * CGFloat(0.14 + Double(index) * 0.035), height: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
        }
        .allowsHitTesting(false)
    }
}
