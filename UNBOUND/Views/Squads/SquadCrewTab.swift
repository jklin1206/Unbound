// UNBOUND/Views/Squads/SquadCrewTab.swift
//
// CREW tab: who's live, the squad streak, the roster, recent shared
// activity, and shared routines — each as its own tinted section card
// (streak = ember, crew = cyan, recent = violet, routines = orange).
import SwiftUI

extension SquadDetailView {
    @ViewBuilder
    func crewTabContent(squad: Squad) -> some View {
        liveNowRow
        squadStreakSection(squad: squad)
        crewSection
        recentActivitySection
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
                        .fill(Color.unbound.success)
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.unbound.success.opacity(0.10))
            )
        }
    }

    func squadStreakSection(squad: Squad) -> some View {
        SquadStreakHeroView(squad: squad, rows: squadBoardRows, season: currentSeason)
    }

    var crewSection: some View {
        let presenceMap = Dictionary(uniqueKeysWithValues: state.activeRosterPresence.map { ($0.userId, $0) })
        let liveCount = state.activeRosterPresence.count
        return SquadSectionCard(
            title: "CREW",
            icon: "person.2.fill",
            tint: Color.unbound.coachCyan,
            trailing: liveCount > 0 ? "\(liveCount) live" : "\(state.roster.count)/\(state.currentSquad?.maxSize ?? 10)",
            trailingTint: liveCount > 0 ? Color.unbound.success : nil
        ) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(state.roster) { member in
                    SquadMemberRow(
                        member: member,
                        isLive: presenceMap[member.userId] != nil,
                        isSelf: member.userId == currentUserId,
                        weeklySessionCount: weeklySessionCount(for: member.userId),
                        lastTrainedAt: lastTrainedAt(for: member.userId),
                        displayNameOverride: displayName(for: member),
                        onTap: { memberDetailTarget = member }
                    )
                }

                if state.roster.count < (state.currentSquad?.maxSize ?? 10),
                   let inviteURL = state.currentSquad?.inviteURL {
                    ShareLink(item: inviteURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.unbound.coachCyan)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .strokeBorder(Color.unbound.coachCyan.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                )
                            Text("Invite a crewmate")
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    func lastTrainedAt(for userId: UUID) -> Date? {
        memberWorkoutLogs[userId]?
            .compactMap { $0.completedAt ?? $0.startedAt }
            .max()
    }

    @ViewBuilder
    var recentActivitySection: some View {
        if !state.recentActivity.isEmpty {
            SquadSectionCard(
                title: "RECENT",
                icon: "sparkles",
                tint: Color.unbound.accent
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(state.recentActivity.prefix(6)) { entry in
                        ActivityFeedRow(entry: entry, roster: state.roster)
                    }
                }
            }
        }
    }

    var routineDropsSection: some View {
        SquadSectionCard(
            title: "SHARED ROUTINES",
            icon: "square.and.arrow.down.fill",
            tint: Color.unbound.warnOrange,
            trailing: routineDrops.isEmpty ? nil : "\(routineDrops.count)"
        ) {
            VStack(alignment: .leading, spacing: 2) {
                if let routineDropStatus {
                    Text(routineDropStatus)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.success)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                }

                if routineDrops.isEmpty {
                    Text("No routines shared yet. Share a Saved Workout from the Program tab.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                } else {
                    ForEach(routineDrops.prefix(6)) { drop in
                        SquadRoutineDropRow(
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
}
