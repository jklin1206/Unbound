import SwiftUI
import UIKit

struct ExerciseRankCard: View {
    let reward: ExerciseRankReward
    var animate: Bool

    @State private var fill: CGFloat = 0
    @State private var badgePop: CGFloat = 0.7

    var body: some View {
        HStack(spacing: 13) {
            // Rank badge earned for this exercise.
            Image(reward.badgeAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .scaleEffect(badgePop)
                .shadow(color: reward.tint.opacity(0.55), radius: 11)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(reward.exerciseName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if reward.didRankUp {
                        Text("RANK UP")
                            .font(Font.unbound.monoS)
                            .tracking(0.6)
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(reward.tint))
                    }

                    Spacer(minLength: 4)

                    Text(reward.rank.displayName.uppercased())
                        .font(Font.unbound.monoS)
                        .tracking(0.8)
                        .foregroundStyle(reward.tint)
                        .lineLimit(1)
                }

                // Progress toward the next rank.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.unbound.surfaceElevated)
                            .frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [reward.tint.opacity(0.6), reward.tint],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: max(6, geo.size.width * fill), height: 6)
                            .shadow(color: reward.tint.opacity(0.55), radius: 4)
                    }
                }
                .frame(height: 6)
                .padding(.top, 1)

                HStack(spacing: 8) {
                    Text(microText)
                        .font(Font.unbound.captionS)
                        .tracking(0.3)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)

                    if let pr = reward.personalBestText {
                        Text(pr)
                            .font(Font.unbound.captionS)
                            .tracking(0.3)
                            .foregroundStyle(Color.unbound.emberGlow)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(reward.tint.opacity(reward.didRankUp ? 0.42 : 0.18), lineWidth: 1)
                )
        )
        .onAppear { runIfReady() }
        .onChange(of: animate) { _, _ in runIfReady() }
    }

    private var microText: String {
        if reward.isMaxed { return "MAX RANK" }
        if let t = reward.nextThresholdText { return t }
        if let next = reward.nextRank { return "→ \(next.displayName)" }
        return ""
    }

    private func runIfReady() {
        guard animate else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { badgePop = 1.0 }
        withAnimation(.easeOut(duration: 0.9).delay(0.1)) { fill = CGFloat(reward.progressToNext) }
    }
}

struct ProofRewardRow: View {
    let beat: RewardBeat
    let tint: Color

    var body: some View {
        let isBest = beat.kind == .newBest
        let rowTint = beat.tier?.rewardTint ?? tint
        return HStack(spacing: 12) {
            // LEFT — the exercise you trained.
            VStack(alignment: .leading, spacing: 2) {
                Text(beat.subtitle.uppercased())
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(isBest ? "NEW BEST" : "RANK EARNED")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 10)

            // RIGHT — the badge they earned.
            if let tier = beat.tier, !isBest {
                HStack(spacing: 9) {
                    Text(tier.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.0)
                        .foregroundStyle(tier.rewardTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(tier.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .shadow(color: tier.rewardTint.opacity(0.6), radius: 7)
                }
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.unbound.emberGlow)
                    .frame(width: 42, height: 42)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(rowTint.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch beat.kind {
        case .standardCleared:
            return "checkmark.seal.fill"
        case .prereqCleared:
            return "link.badge.plus"
        case .skillUnlock:
            return "sparkles"
        case .rankAdvance:
            return "chevron.up.2"
        case .newBest:
            return "flame.fill"
        }
    }
}

struct AnimatedRewardAttributeHex: View, Animatable {
    let previous: [AttributeKey: Double]
    let current: [AttributeKey: Double]
    let levels: [AttributeKey: Int]?
    let tiers: [AttributeKey: RankTitle]?
    var progress: Double
    let radius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        AttributeHex(
            current: interpolated(from: previous, to: current),
            levels: levels,
            tiers: tiers,
            showLabels: false,
            radius: radius
        )
    }

    private func interpolated(
        from start: [AttributeKey: Double],
        to end: [AttributeKey: Double]
    ) -> [AttributeKey: Double] {
        let clamped = min(1, max(0, progress))
        return Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
            let from = start[key] ?? 0
            let to = end[key] ?? from
            return (key, from + (to - from) * clamped)
        })
    }
}

/// Dedicated reveal of the top rank badge earned this session: the actual
/// `rank_title_*` art slams in with a spring, an expanding ring + glow + sparkle
/// burst, the tier name, and (on a multi-rung jump) a "RANKS ADVANCED" chip.
/// Fires the rank-reveal stinger + heavy haptic on appear.
struct RankBadgeRevealView: View {
    let tier: SkillTier
    let skillTitle: String
    let multi: Int?
    let active: Bool

    @State private var badgeIn = false
    @State private var sparkles = false
    @State private var played = false

    var body: some View {
        VStack(spacing: 24) {
            Text("RANK EARNED")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(3)
                .foregroundStyle(tier.rewardTint)
                .opacity(badgeIn ? 1 : 0)

            ZStack {
                // Sparkle burst — small particles flung outward (no ring/disc behind).
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) / 12 * 2 * .pi
                    Circle()
                        .fill(tier.rewardTint)
                        .frame(width: 5, height: 5)
                        .offset(x: sparkles ? cos(angle) * 135 : 0,
                                y: sparkles ? sin(angle) * 135 : 0)
                        .opacity(sparkles ? 0 : 0.95)
                }

                Image(tier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 172, height: 172)
                    .shadow(color: tier.rewardTint.opacity(badgeIn ? 0.85 : 0), radius: 32)
                    .shadow(color: tier.rewardTint.opacity(badgeIn ? 0.45 : 0), radius: 64)
                    .scaleEffect(badgeIn ? 1 : 0.32)
                    .rotationEffect(.degrees(badgeIn ? 0 : -14))
                    .opacity(badgeIn ? 1 : 0)
            }
            .frame(height: 300)

            VStack(spacing: 8) {
                Text(tier.displayName.uppercased())
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundStyle(tier.rewardTint)
                    .shadow(color: tier.rewardTint.opacity(0.5), radius: 16)
                if !skillTitle.isEmpty {
                    Text(skillTitle.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if let multi {
                    Text("▲ \(multi) RANKS ADVANCED")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.bg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(tier.rewardTint, in: Capsule())
                        .padding(.top, 4)
                }
            }
            .opacity(badgeIn ? 1 : 0)
        }
        .onChange(of: active) { _, on in if on { reveal() } }
        .onAppear { if active { reveal() } }
    }

    private func reveal() {
        guard !played else { return }
        played = true
        UnboundSound.shared.play(.rankReveal)
        UnboundHaptics.heavy()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.58)) { badgeIn = true }
        withAnimation(.easeOut(duration: 0.8).delay(0.08)) { sparkles = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { UnboundHaptics.medium() }
    }
}

struct LevelProgressHero: View {
    let label: String
    let levelBefore: Int
    let levelAfter: Int
    let xpGained: Double
    let xpIntoLevel: Double
    let xpNeededForLevel: Double
    let xpRemaining: Double
    let progressBefore: Double
    let progressAfter: Double
    let tint: Color
    let animate: Bool

    @State private var displayedLevel: Int = 0   // flips to the next level only AFTER the bar fills
    @State private var barProgress: Double = 0    // parent-driven fill (fill→100→reset→refill)
    @State private var flourish = false           // cap ignite + shimmer at each 100%
    @State private var levelBurst = false         // scale-pop of the LVL number on the flip
    @State private var flash = false              // full-bleed flash on level-up
    @State private var started = false

    private var leveledUp: Bool { levelAfter > levelBefore }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("LVL \(displayedLevel)")
                        .font(.system(size: 54, weight: .black, design: .monospaced))
                        .foregroundStyle(tint)
                        .shadow(color: tint.opacity(levelBurst ? 0.95 : 0.52), radius: levelBurst ? 34 : 20)
                        .scaleEffect(levelBurst ? 1.22 : 1.0, anchor: .leading)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                        .allowsTightening(true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(formatWhole(xpGained)) XP")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.56)
                        .allowsTightening(true)
                        .multilineTextAlignment(.trailing)
                    Text(leveledUp ? "LVL \(levelBefore) -> \(levelAfter)" : "LVL \(levelAfter)")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.3)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)
                        .allowsTightening(true)
                        .multilineTextAlignment(.trailing)
                }
            }

            RPGStatBar(
                from: 0,
                to: progressAfter,
                tint: tint,
                animate: false,
                height: 32,
                segments: 10,
                showOriginCap: true,
                celebrate: leveledUp,
                controlledProgress: barProgress,
                forceFlourish: flourish
            )
            .shadow(color: tint.opacity(levelBurst ? 0.85 : 0.42), radius: levelBurst ? 30 : 20)
            .scaleEffect(levelBurst ? 1.03 : 1.0)

            HStack {
                Text("\(formatWhole(xpIntoLevel)) / \(formatWhole(xpNeededForLevel)) XP")
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                Spacer()
                Text("\(formatWhole(xpRemaining)) XP TO NEXT")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(flash ? 0.22 : 0))
                .blur(radius: 8)
                .allowsHitTesting(false)
        )
        .onAppear {
            displayedLevel = levelBefore
            barProgress = progressBefore
            if animate { runSequence() }
        }
        .onChange(of: animate) { _, on in if on { runSequence() } }
    }

    /// The level-up bar choreography. For each level gained, the bar fills to
    /// 100%, the moment lands (chord + haptic + flash), the LVL number flips to
    /// the next level, then the bar snaps empty and refills. The final fill lands
    /// at the new level's actual XP. No level-up → one clean fill.
    private func runSequence() {
        guard !started else { return }
        started = true
        displayedLevel = levelBefore
        barProgress = progressBefore

        let gained = max(0, levelAfter - levelBefore)
        let seg = 0.85
        var t = 0.25

        guard gained > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                withAnimation(.easeOut(duration: seg)) { barProgress = progressAfter }
            }
            return
        }

        for i in 0..<gained {
            let startVal = i == 0 ? progressBefore : 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                barProgress = startVal
                withAnimation(.easeOut(duration: seg)) { barProgress = 1.0 }
            }
            t += seg

            let newLevel = levelBefore + i + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                UnboundSound.shared.play(.levelUp)
                UnboundHaptics.heavy()
                withAnimation(.easeOut(duration: 0.12)) { flourish = true; flash = true }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                    displayedLevel = newLevel
                    levelBurst = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { levelBurst = false }
                    withAnimation(.easeOut(duration: 0.4)) { flash = false; flourish = false }
                    barProgress = 0   // snap empty for the next fill
                }
            }
            t += 0.55
        }

        // Final fill into the new level's XP carryover.
        DispatchQueue.main.asyncAfter(deadline: .now() + t) {
            withAnimation(.easeOut(duration: seg)) { barProgress = progressAfter }
        }
    }
}

struct MovementXPSpotlight: View {
    let line: ProgressionMovementLine
    let tint: Color
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RankPulseRings(tint: tint, hot: line.didRankUp, animate: animate)
                    VStack(spacing: 0) {
                        Text("+\(formatWhole(line.xpGained))")
                            .font(.system(size: 31, weight: .black, design: .monospaced))
                            .foregroundStyle(tint)
                        Text("XP")
                            .font(Font.unbound.captionS.weight(.black))
                            .tracking(2.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: 7) {
                    Text(line.name.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                    if line.didRankUp, let rank = line.currentRank {
                        Text("RANK UP → \(rank.displayName.uppercased())")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.4)
                            .foregroundStyle(tint)
                    } else if let rank = line.currentRank {
                        Text("RANK \(rank.displayName.uppercased())")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.4)
                            .foregroundStyle(tint)
                    }
                    Text(rankProgressLabel)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if line.currentRank != nil, line.nextRank != nil {
                RPGStatBar(
                    from: line.didRankUp ? 0 : line.fractionToNextRank,
                    to: line.fractionToNextRank,
                    tint: tint,
                    animate: animate,
                    height: 24,
                    segments: 10,
                    showOriginCap: true
                )
            }
        }
        .padding(.vertical, 4)
    }

    private var rankProgressLabel: String {
        guard let current = line.currentRank else { return "+XP EARNED" }
        guard let next = line.nextRank else { return "MAXED — \(current.displayName.uppercased())" }
        return "\(Int((line.fractionToNextRank * 100).rounded()))% → \(next.displayName.uppercased())"
    }
}

struct AttributeRankSpotlight: View {
    let delta: AttributeDeltaReward
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP ATTRIBUTE")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(delta.key.shortCode)
                    .font(.system(size: 35, weight: .black, design: .monospaced))
                    .foregroundStyle(delta.tint)
                    .shadow(color: delta.tint.opacity(0.38), radius: 14)
                Text("LVL \(delta.currentLevel)")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Text(delta.currentTier.displayName.uppercased())
                .font(Font.unbound.captionS.weight(.black))
                .tracking(1.4)
                .foregroundStyle(delta.currentTier.rewardTextTint)

            HStack(spacing: 8) {
                Text("+\(formatWhole(delta.xpGained)) XP")
                    .font(Font.unbound.monoM.weight(.black))
                    .foregroundStyle(delta.tint)
                if delta.didAdvanceTier {
                    LevelUpChip(text: "RANK UP", tint: delta.tint)
                } else if delta.didIncreaseLevel {
                    LevelUpChip(text: "LVL UP", tint: delta.tint)
                }
            }

            Text("\(formatWhole(delta.xpIntoCurrentLevel)) / \(formatWhole(delta.xpNeededForCurrentLevel)) XP")
                .font(Font.unbound.captionS.weight(.heavy))
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .scaleEffect(animate && (delta.didAdvanceTier || delta.didIncreaseLevel) ? 1.02 : 1)
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: animate)
    }
}
