// UNBOUND/Views/Squads/SquadChallengesTab.swift
import SwiftUI

extension SquadDetailView {
    @ViewBuilder
    var challengesTabContent: some View {
        missionSection
        challengesSection
    }

    // MARK: - Mission section

    @ViewBuilder
    private var missionSection: some View {
        if let mission = currentMissionState {
            let namedContributions: [(name: String, total: Int)] = missionContributions.map { contribution in
                let name = contribution.userId.map { displayName(for: $0) } ?? "Linked sessions"
                return (name: name, total: contribution.total)
            }
            SquadMissionCard(mission: mission, contributions: namedContributions)
        } else if state.currentSquad.map({ canEditSquad($0) }) ?? false {
            weeklyMissionEmptyCard(isCaptain: true)
        } else {
            weeklyMissionEmptyCard(isCaptain: false)
        }
    }

    private func weeklyMissionEmptyCard(isCaptain: Bool) -> some View {
        Button {
            if isCaptain {
                showMissionPick = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.unbound.accent.opacity(0.14))
                        Image(systemName: "flag.2.crossed.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(Color.unbound.accent)
                    }
                    .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("WEEKLY MISSION")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(isCaptain ? "Pick the crew target" : "Waiting on the captain")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(isCaptain ? "Choose one co-op goal for this week. Every logged session can push the bar." : "The next mission appears here as soon as it is picked or auto-assigned.")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    missionEmptyPill(value: "1", label: "MISSION")
                    missionEmptyPill(value: "7D", label: "WINDOW")
                    missionEmptyPill(value: "\(SquadRewardPolicy.missionArcs)", label: "ARCS")
                }

                if isCaptain {
                    HStack(spacing: 8) {
                        Text("CHOOSE MISSION")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.bg)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.unbound.bg)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.accent))
                }
            }
            .padding(16)
            .squadPanel(cornerRadius: 22, tint: Color.unbound.accent)
        }
        .buttonStyle(.plain)
        .disabled(!isCaptain)
    }

    private func missionEmptyPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Capsule().fill(Color.unbound.accent.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Color.unbound.accent.opacity(0.22), lineWidth: 1))
    }

    // MARK: - Challenges section

    var challengesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("CHALLENGES")
                Spacer()
                Button {
                    showChallengeCreate = true
                } label: {
                    Label("NEW", systemImage: "plus")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            if activeChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.unbound.warnOrange.opacity(0.14))
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(Color.unbound.warnOrange)
                        }
                        .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("NO ACTIVE CHALLENGES")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("Start a 1v1 and put points on the season board.")
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }

                    Button {
                        showChallengeCreate = true
                    } label: {
                        Label("START CHALLENGE", systemImage: "bolt.fill")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.unbound.warnOrange.opacity(0.82))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .squadPanel(cornerRadius: 20, tint: Color.unbound.warnOrange)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        challengeMetric(value: "\(activeChallenges.count)", label: "ACTIVE")
                        challengeMetric(value: "\(challengeStatsByMember.values.map(\.seasonWins).reduce(0, +))", label: "SEASON WINS")
                        Spacer(minLength: 0)
                    }
                    ForEach(Array(activeChallenges.prefix(3))) { challenge in
                        ChallengeDashboardRow(challenge: challenge, roster: state.roster, currentUserId: currentUserId)
                    }
                    if activeChallenges.count > 3 {
                        Text("+\(activeChallenges.count - 3) more active")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(14)
                .squadPanel(cornerRadius: 20, tint: Color.unbound.warnOrange)
            }
        }
    }

    func challengeMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(minWidth: 82)
        .frame(height: 42)
        .background(Capsule().fill(Color.unbound.warnOrange.opacity(0.11)))
        .overlay(Capsule().strokeBorder(Color.unbound.warnOrange.opacity(0.24), lineWidth: 1))
    }
}
