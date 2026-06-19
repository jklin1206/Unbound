// UNBOUND/Views/Squads/SquadCrewTab.swift
import SwiftUI

extension SquadDetailView {
    @ViewBuilder
    func crewTabContent(squad: Squad) -> some View {
        liveNowRow
        squadStreakSection(squad: squad)
        crewSection
        routineDropsSection
    }

    @ViewBuilder
    var liveNowRow: some View {
        let others = state.activeRosterPresence.filter { $0.userId != currentUserId }
        if let live = others.first {
            Button {
                NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(displayName(for: live.userId)) is training now")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(others.count > 1 ? "+\(others.count - 1) more live — jump in" : "Jump in and link the session")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
            }
            .buttonStyle(.plain)
        }
    }

    func squadStreakSection(squad: Squad) -> some View {
        SquadStreakHeroView(squad: squad, rows: squadBoardRows, season: currentSeason)
    }

    var crewSection: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let presenceMap = Dictionary(uniqueKeysWithValues: state.activeRosterPresence.map { ($0.userId, $0) })
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("CREW RANKS")
                Spacer()
                if !state.activeRosterPresence.isEmpty {
                    Text("\(state.activeRosterPresence.count) LIVE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(state.roster) { member in
                    SquadMemberCard(
                        member: member,
                        presence: presenceMap[member.userId],
                        weeklySessionCount: weeklySessionCount(for: member.userId),
                        accountabilityBadge: accountabilityBadge(for: member.userId),
                        displayNameOverride: displayName(for: member),
                        profileUserId: resolvedProfileUserId(for: member),
                        cosmeticTier: frameTier(for: member),
                        onTap: { memberDetailTarget = member }
                    )
                }
            }
        }
    }

    var routineDropsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("ROUTINE DROPS")
                Spacer()
                Text("\(routineDrops.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.warnOrange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.unbound.warnOrange.opacity(0.12)))
            }

            if let routineDropStatus {
                Text(routineDropStatus)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if routineDrops.isEmpty {
                emptySlab("No routines shared yet. Drop a Saved Workout from the Program tab.", icon: "square.and.arrow.up.fill")
            } else {
                VStack(spacing: 10) {
                    ForEach(routineDrops.prefix(5)) { drop in
                        SquadRoutineDropCard(
                            drop: drop,
                            authorName: displayName(for: drop.authorUserId),
                            isMine: drop.authorUserId == currentUserId,
                            onSave: { saveRoutineDrop(drop) },
                            onUseToday: { useRoutineDropToday(drop) }
                        )
                    }
                }
            }
        }
    }

    func emptySlab(_ copy: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.78)))

            Text(copy)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .squadPanel(cornerRadius: 18, tint: Color.unbound.textTertiary)
    }

}
