import SwiftUI
import UIKit

// MARK: - RewardCelebrationView
//
// Modal sheet shown after a logged set / finished session / unlocked
// achievement. Renders cards in a stack — one per non-nil reward in
// `RewardSummary`. Scales from quiet (single XP card) to full cinematic
// (rank-up into Vessel/Unbound/Ascendant). Always single-tap to dismiss.
//
// Card order, top to bottom:
//   1. Rank-up hero (if any) — biggest card, RankTitle imagery
//   2. Personal record (if any)
//   3. Badge unlocks (one per unlock)
//   4. XP gained (always shown if > 0, smallest card)
//
// Brand rules: drama only when earned. The bottom four named tiers
// (Veteran/Honed/Vessel/Unbound/Ascendant) get bigger emphasis. Lower
// tier crossings render as a clean compact card.

struct RewardCelebrationView: View {
    let summary: RewardSummary
    let onDismiss: () -> Void

    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            // Full-bleed atmospheric background — dimmer for quiet
            // events, cinematic violet bloom for top-tier rank-ups.
            backdrop

            VStack(spacing: 16) {
                header
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 14) {
                        if let rankUp = summary.rankUp {
                            rankUpCard(rankUp)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                        if let firstSet = summary.firstSet, summary.rankUp == nil {
                            firstSetCard(firstSet)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                        if let pr = summary.personalRecord {
                            personalRecordCard(pr)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        ForEach(summary.badgeUnlocks, id: \.id) { unlock in
                            badgeCard(unlock)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        if summary.xpGained > 0 {
                            xpCard(amount: summary.xpGained)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }

                HStack(spacing: 10) {
                    Button {
                        UnboundHaptics.medium()
                        RewardShareRenderer.presentShareSheet(summary: summary)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule().fill(Color.unbound.surfaceElevated)
                        )
                        .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    UnboundButton(title: "Continue", icon: "arrow.right") {
                        UnboundHaptics.medium()
                        onDismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                hasAppeared = true
            }
            UnboundHaptics.medium()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(headerKicker.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.accent)
            Text(headerTitle)
                .font(.system(.title, design: .default).weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 32)
            if let subtitle = headerSubtitle {
                Text(subtitle)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var headerKicker: String {
        if summary.rankUp != nil { return "Rank Up" }
        if summary.firstSet != nil { return "First Rep" }
        if summary.personalRecord != nil { return "New PR" }
        if !summary.badgeUnlocks.isEmpty { return "Badge Unlocked" }
        return "Set Logged"
    }

    private var headerTitle: String {
        if let rankUp = summary.rankUp { return rankUp.toTier.displayName.uppercased() }
        if let first = summary.firstSet { return first.skillTitle }
        if let pr = summary.personalRecord { return pr.displayValue }
        if let badge = summary.badgeUnlocks.first { return badge.title }
        return summary.skillTitle ?? "Nice Set"
    }

    private var headerSubtitle: String? {
        if let rankUp = summary.rankUp { return rankUp.skillTitle }
        if summary.firstSet != nil { return "Your path begins." }
        if let pr = summary.personalRecord { return pr.exerciseName }
        if let badge = summary.badgeUnlocks.first { return badge.subtitle }
        return nil
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        if let rankUp = summary.rankUp, rankUp.toTier.deservesCinematic {
            // Cinematic — full-bleed cosmetic background for the new tier.
            CosmeticBackdrop(tier: rankUp.toTier, maxHeight: .infinity)
                .opacity(hasAppeared ? 1 : 0)
        } else {
            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(0.16),
                    Color.unbound.bg.opacity(0)
                ],
                center: .top,
                startRadius: 20,
                endRadius: 480
            )
            .ignoresSafeArea()
            .opacity(hasAppeared ? 1 : 0)
        }
    }

    // MARK: - Cards

    private func rankUpCard(_ rankUp: RankUp) -> some View {
        VStack(spacing: 14) {
            // Rank title image — big, glowing.
            Group {
                if UIImage(named: rankUp.toTier.assetName) != nil {
                    Image(rankUp.toTier.assetName)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        Circle().fill(Color.unbound.accent.opacity(0.18))
                        Text(rankUp.toTier.displayName.prefix(1))
                            .font(.system(size: 56, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }
            }
            .frame(width: 140, height: 140)
            .shadow(color: Color.unbound.accent.opacity(0.65), radius: 20)
            .scaleEffect(hasAppeared ? 1.0 : 0.7)

            VStack(spacing: 4) {
                if let from = rankUp.fromTier {
                    Text("\(from.displayName.uppercased())  →  \(rankUp.toTier.displayName.uppercased())")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.accent)
                } else {
                    Text("FIRST RANK EARNED")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.accent)
                }
                Text(rankUp.skillTitle)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(highlightCard(tinted: true))
    }

    private func personalRecordCard(_ pr: PersonalRecord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.unbound.impact.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.unbound.impact)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("PERSONAL RECORD")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.impact)
                Text(pr.displayValue)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(pr.exerciseName)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                if let delta = pr.deltaText {
                    Text(delta)
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.impact)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlightCard(tinted: false))
    }

    private func badgeCard(_ unlock: BadgeUnlock) -> some View {
        HStack(spacing: 14) {
            Group {
                if UIImage(named: unlock.assetName) != nil {
                    Image(unlock.assetName)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        Circle().fill(Color.unbound.accent.opacity(0.18))
                        Image(systemName: "rosette")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("BADGE UNLOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.accent)
                Text(unlock.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                if let sub = unlock.subtitle {
                    Text(sub)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlightCard(tinted: false))
    }

    private func firstSetCard(_ first: FirstSet) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.18))
                    .frame(width: 88, height: 88)
                    .blur(radius: 14)
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color.unbound.accent)
                    .scaleEffect(hasAppeared ? 1.0 : 0.7)
            }

            VStack(spacing: 4) {
                Text("JOURNEY BEGINS")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(first.skillTitle)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("First rep on the path. The hard part is starting.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(highlightCard(tinted: true))
    }

    private func xpCard(amount: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.18))
                    .frame(width: 40, height: 40)
                Text("XP")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.accent)
            }
            Text("+\(amount) XP earned")
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlightCard(tinted: false))
    }

    @ViewBuilder
    private func highlightCard(tinted: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
            if tinted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.accent.opacity(0.16),
                                Color.unbound.accent.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    tinted ? Color.unbound.accent.opacity(0.55) : Color.unbound.border,
                    lineWidth: 1
                )
        }
    }
}
