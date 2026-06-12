// UNBOUND/Views/Squads/SquadDetailView+Header.swift
import SwiftUI

extension SquadDetailView {
    var squadBackdrop: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color.unbound.accent.opacity(0.17),
                        Color.unbound.warnOrange.opacity(0.07),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 340)

                Image("SquadCrest")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(proxy.size.width * 0.74, 320))
                    .opacity(0.11)
                    .blendMode(.screen)
                    .offset(x: 78, y: -58)

                LinearGradient(
                    stops: [
                        .init(color: Color.unbound.bg.opacity(0.02), location: 0),
                        .init(color: Color.unbound.bg.opacity(0.72), location: 0.72),
                        .init(color: Color.unbound.bg, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 360)
            }
            .frame(width: proxy.size.width, height: 360, alignment: .top)
        }
        .frame(height: 360)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var squadTitlesRow: some View {
        if !state.unlockedSquadTitles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(state.unlockedSquadTitles, id: \.self) { titleId in
                        SquadTitleBadge(titleId: titleId, compact: true)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    func headerCard(squad: Squad) -> some View {
        ZStack(alignment: .topTrailing) {
            SquadConsoleBackground(tint: Color.unbound.accent)

            SquadLogoMarkView(logoId: squad.logoId, size: 164, showsBorder: false)
                .opacity(0.13)
                .blendMode(.screen)
                .offset(x: 36, y: -34)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    editableCrestMark(squad: squad, size: 92)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(state.roster.count)")
                            .font(Font.unbound.monoM.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .monospacedDigit()
                        Text(state.roster.count == 1 ? "MEMBER" : "MEMBERS")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text(squad.name)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text("Protect the streak, win challenges, climb the season.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        squadMetaPill(
                            icon: "person.2.fill",
                            value: "\(state.roster.count)/8",
                            label: "CREW",
                            tint: Color.unbound.accent
                        )
                        squadMetaPill(
                            icon: "flame.fill",
                            value: "\(squad.squadStreakWeeks)W",
                            label: "STREAK",
                            tint: Color.unbound.warnOrange
                        )
                        squadMetaPill(
                            icon: "trophy.fill",
                            value: currentSeason.title,
                            label: "SEASON",
                            tint: Color.unbound.accent
                        )
                    }

                    squadTitlesRow
                }

                HStack(spacing: 10) {
                    Button {
                        showChallengeCreate = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("NEW CHALLENGE")
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.2)
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.unbound.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: Color.unbound.accent.opacity(0.24), radius: 18, y: 8)
                    }
                    .buttonStyle(.plain)

                    if let inviteURL = squad.inviteURL {
                        ShareLink(item: inviteURL) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.unbound.bg.opacity(0.52))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.unbound.accent.opacity(0.32),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 14)
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            crestMark(size: 82, logoId: nil)
            Text("You're not in a squad.")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func crestMark(size: CGFloat, logoId: String?) -> some View {
        SquadLogoMarkView(logoId: logoId, size: size)
    }

    @ViewBuilder
    private func editableCrestMark(squad: Squad, size: CGFloat) -> some View {
        if canEditSquad(squad) {
            Button {
                showLogoEditor = true
            } label: {
                crestMark(size: size, logoId: squad.logoId)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.unbound.bg)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.unbound.accent))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 1))
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(.plain)
        } else {
            crestMark(size: size, logoId: squad.logoId)
        }
    }

    private func squadMetaPill(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.unbound.bg.opacity(0.46)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }
}
