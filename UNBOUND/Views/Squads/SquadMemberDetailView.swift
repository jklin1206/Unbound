// UNBOUND/Views/Squads/SquadMemberDetailView.swift
//
// Read-only view pushed when a crew member's card is tapped.
// No messaging or comments in v1.
import SwiftUI

struct SquadMemberDetailView: View {
    let member: SquadMember
    let roster: [SquadMember]

    @State private var memberActivity: [SquadActivityEntry] = []
    @State private var isLoading = true

    // Derived: entries where kind == .titleUnlocked (rank-up proxy)
    private var rankUpCount: Int {
        memberActivity.filter { $0.kind == .titleUnlocked }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 1. Hero: BuildIdentity + displayName
                heroSection
                // 2. Equipped TitleBadge
                if let titleId = member.equippedTitle {
                    equippedTitleSection(titleId: titleId)
                }
                // 3. ASCENDANT SKILLS — placeholder
                ascendantSkillsSection
                // 4. Rank-ups counter
                rankUpsSection
                // 5. Recent activity feed for this member
                recentActivitySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Hero section

    private var heroSection: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                VStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle().fill(Color.unbound.accent.opacity(0.2))
                        Text(initials)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Color.unbound.accent)
                    }
                    .frame(width: 60, height: 60)

                    // Display name
                    Text(member.displayName)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)

                    // BuildIdentity
                    if let identity = member.buildIdentity {
                        // TODO(squads-impl, Phase 16+): Replace text+bars with real
                        // BuildHexView once per-member AttributeProfile snapshots flow
                        // to SquadMember.buildIdentity.
                        VStack(spacing: 4) {
                            Text(identity.displayName)
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.accent)
                            Text(identity.tagline)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Text("Build identity not set")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .padding(20)
            )
    }

    // MARK: - Equipped title

    private func equippedTitleSection(titleId: TitleID) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("EQUIPPED TITLE")
                        TitleBadge(titleId: titleId, compact: false)
                    }
                    Spacer()
                }
                .padding(14)
            )
    }

    // MARK: - Ascendant Skills

    private var ascendantSkillsSection: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("ASCENDANT SKILLS")
                    // TODO(squads-impl, Phase 16+): Render member's gold-tier individual
                    // Titles here once the member skill-tier snapshot is returned as part
                    // of SquadMember. For v1, SquadMember.buildIdentity does not carry
                    // individual skill nodes; this section is an intentional placeholder.
                    Text("Skill data available after first sync.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
    }

    // MARK: - Rank-ups counter

    private var rankUpsSection: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.unbound.rankGold)
                    VStack(alignment: .leading, spacing: 2) {
                        sectionHeader("RANK-UPS")
                        Text("\(rankUpCount)")
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                    Spacer()
                }
                .padding(14)
            )
            .frame(height: 64)
    }

    // MARK: - Recent activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RECENT ACTIVITY")
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color.unbound.accent)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if memberActivity.isEmpty {
                Text("No activity yet.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(memberActivity) { entry in
                        ActivityFeedRow(entry: entry, roster: roster)
                        if entry.id != memberActivity.last?.id {
                            Divider()
                                .overlay(Color.unbound.borderSubtle)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - Helpers

    private var initials: String {
        member.displayName
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private func load() async {
        guard let userId = AuthService.shared.currentUserId else {
            isLoading = false
            return
        }
        let all = (try? await SquadActivityService.shared.fetchRecent(userId: userId)) ?? []
        memberActivity = all
            .filter { $0.userId == member.userId }
            .prefix(20)
            .map { $0 }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SquadMemberDetailView(
            member: SquadMember(
                id: UUID(),
                squadId: UUID(),
                userId: UUID(),
                joinedAt: Date(),
                displayName: "Justin Lin",
                equippedTitle: nil,
                buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
            ),
            roster: []
        )
    }
}
