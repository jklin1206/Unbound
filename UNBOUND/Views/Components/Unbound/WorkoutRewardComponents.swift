import SwiftUI
import UIKit

// MARK: - Components

func formatWhole(_ value: Double) -> String {
    "\(Int(value.rounded()))"
}

struct CinematicRewardHUD: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    HUDNotchedLine(tint: tint)
                        .frame(height: 34)
                        .padding(.top, 92)
                    Spacer()
                    HUDNotchedLine(tint: tint)
                        .frame(height: 34)
                        .padding(.bottom, 126)
                }

                Path { path in
                    let step: CGFloat = 54
                    for x in stride(from: CGFloat(0), through: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 120))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height - 142))
                    }
                    for y in stride(from: CGFloat(160), through: geo.size.height - 160, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(tint.opacity(0.045), lineWidth: 1)

                VStack {
                    Spacer()
                    Rectangle()
                        .fill(tint.opacity(0.72))
                        .frame(width: max(24, geo.size.width * progress), height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 106)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct HUDNotchedLine: View {
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let mid = geo.size.width / 2
                path.move(to: CGPoint(x: 0, y: 10))
                path.addLine(to: CGPoint(x: mid - 46, y: 10))
                path.addLine(to: CGPoint(x: mid - 34, y: 22))
                path.addLine(to: CGPoint(x: mid + 34, y: 22))
                path.addLine(to: CGPoint(x: mid + 46, y: 10))
                path.addLine(to: CGPoint(x: geo.size.width, y: 10))
            }
            .stroke(tint.opacity(0.72), lineWidth: 1.2)
        }
    }
}

struct TriangleCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct RewardPanel<Content: View>: View {
    let tint: Color
    let active: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .center, spacing: 0) { content }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .shadow(color: active ? tint.opacity(0.18) : .clear, radius: 24, y: 8)
    }
}

// MARK: - Streak flame

struct StreakFlame: View {
    let active: Bool
    let tint: Color

    @State private var lit = false
    @State private var sparkles = false
    @State private var flicker = false

    // Cohesive fire — bright gold top into deep orange-red, no off-hue.
    private let fire = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.86, blue: 0.34),
            Color(red: 1.00, green: 0.55, blue: 0.12),
            Color(red: 0.92, green: 0.22, blue: 0.06)
        ],
        startPoint: .top, endPoint: .bottom
    )
    private let emberShadow = Color(red: 1.0, green: 0.5, blue: 0.12)

    var body: some View {
        ZStack {
            // Sparkle burst — same flare as the rank-badge reveal.
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi
                Circle()
                    .fill(emberShadow)
                    .frame(width: 5, height: 5)
                    .offset(x: sparkles ? cos(angle) * 118 : 0,
                            y: sparkles ? sin(angle) * 118 : 0)
                    .opacity(sparkles ? 0 : 0.95)
            }

            Image(systemName: "flame.fill")
                .font(.system(size: 104, weight: .black))
                .foregroundStyle(fire)
                .shadow(color: emberShadow.opacity(flicker ? 0.85 : 0.5), radius: flicker ? 34 : 24)
                .shadow(color: emberShadow.opacity(lit ? 0.4 : 0), radius: 60)
                .scaleEffect(lit ? (flicker ? 1.05 : 0.98) : 0.4, anchor: .bottom)
                .rotationEffect(.degrees(lit ? 0 : -10))
                .opacity(lit ? 1 : 0)
        }
        .onChange(of: active) { _, on in if on { ignite() } }
        .onAppear { if active { ignite() } }
    }

    private func ignite() {
        // Spring slam-in + sparkle burst (the badge reveal), then a living flicker.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { lit = true }
        withAnimation(.easeOut(duration: 0.8).delay(0.08)) { sparkles = true }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.55)) {
            flicker = true
        }
    }
}

// MARK: - Unified per-exercise rank card (skills + lifts)

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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("LVL \(displayedLevel)")
                        .font(.system(size: 54, weight: .black, design: .monospaced))
                        .foregroundStyle(tint)
                        .shadow(color: tint.opacity(levelBurst ? 0.95 : 0.52), radius: levelBurst ? 34 : 20)
                        .scaleEffect(levelBurst ? 1.22 : 1.0, anchor: .leading)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(formatWhole(xpGained)) XP")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(leveledUp ? "LVL \(levelBefore) -> \(levelAfter)" : "LVL \(levelAfter)")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.3)
                        .foregroundStyle(Color.unbound.textTertiary)
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
                Spacer()
                Text("\(formatWhole(xpRemaining)) XP TO NEXT")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
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

struct RankPulseRings: View {
    let tint: Color
    let hot: Bool
    let animate: Bool

    var body: some View {
        ZStack {
            Hexagon()
                .stroke(tint.opacity(0.18), lineWidth: 2)
                .frame(width: 116, height: 116)
                .scaleEffect(animate ? 1.10 : 0.86)
                .opacity(animate ? 0.92 : 0.34)
            Hexagon()
                .stroke(tint.opacity(hot ? 0.72 : 0.46), lineWidth: hot ? 2.2 : 1.5)
                .frame(width: 92, height: 92)
                .shadow(color: tint.opacity(hot ? 0.58 : 0.22), radius: hot ? 24 : 10)
            if hot {
                Hexagon()
                    .stroke(tint.opacity(animate ? 0.0 : 0.68), lineWidth: 1.4)
                    .frame(width: 92, height: 92)
                    .scaleEffect(animate ? 1.42 : 0.86)
            }
        }
        .animation(.easeOut(duration: 0.9), value: animate)
    }
}

struct LevelUpChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(Font.unbound.captionS.weight(.black))
            .tracking(1.4)
            .foregroundStyle(Color.unbound.bg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint, in: Capsule())
            .shadow(color: tint.opacity(0.40), radius: 10)
    }
}

struct AttributeLevelProgressRow: View {
    let delta: AttributeDeltaReward
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(delta.key.shortCode) LVL \(delta.currentLevel)")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("CURRENT RANK \(delta.currentTier.displayName.uppercased())")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(delta.currentTier.rewardTextTint.opacity(0.95))
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(formatWhole(delta.xpGained)) XP")
                        .font(Font.unbound.monoM.weight(.black))
                        .foregroundStyle(delta.tint)
                    Text(levelText)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(delta.didIncreaseLevel ? delta.tint : Color.unbound.textTertiary)
                }
            }

            RPGStatBar(
                from: delta.levelProgressStart,
                to: delta.currentProgress,
                tint: delta.tint,
                animate: animate,
                height: 18,
                segments: 8,
                showOriginCap: false
            )

            HStack {
                Text("\(formatWhole(delta.xpIntoCurrentLevel)) / \(formatWhole(delta.xpNeededForCurrentLevel)) XP")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(formatWhole(delta.xpRemainingInLevel)) XP TO NEXT")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(.vertical, 9)
        .overlay(Rectangle().fill(Color.unbound.textPrimary.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    private var levelText: String {
        delta.didIncreaseLevel ? "LVL \(delta.previousLevel) -> \(delta.currentLevel)" : "TO NEXT"
    }
}

struct MovementXPProgressRow: View {
    let line: ProgressionMovementLine
    let tint: Color
    let animate: Bool

    private var rowTint: Color { line.didRankUp ? Color.unbound.rankGold : tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textPrimary)
                    if let rank = line.currentRank {
                        Text(line.didRankUp ? "RANK UP → \(rank.displayName.uppercased())" : "RANK \(rank.displayName.uppercased())")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.1)
                            .foregroundStyle(line.didRankUp ? rowTint : Color.unbound.textTertiary)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(formatWhole(line.xpGained)) XP")
                        .font(Font.unbound.monoM.weight(.black))
                        .foregroundStyle(rowTint)
                    if line.currentRank != nil {
                        Text(toNextLabel)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
            }

            if line.currentRank != nil, line.nextRank != nil {
                RPGStatBar(
                    from: line.didRankUp ? 0 : line.fractionToNextRank,
                    to: line.fractionToNextRank,
                    tint: rowTint,
                    animate: animate,
                    height: 16,
                    segments: 5,
                    showOriginCap: false
                )
            }
        }
    }

    private var toNextLabel: String {
        guard let next = line.nextRank else { return "MAXED" }
        return "\(Int((line.fractionToNextRank * 100).rounded()))% → \(next.displayName.uppercased())"
    }
}

struct ReceiptTotalRow: View {
    let label: String
    let value: String
    let tint: Color
    let show: Bool

    var body: some View {
        if show {
            HStack {
                Text(label.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(value.uppercased())
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(tint)
            }
        }
    }
}

/// XP fill — a clean dimensional energy gradient with top gloss while it grows,
/// then a single specular shimmer that sweeps across once the bar reaches the end
/// (the flourish lands at completion, not continuously during the fill).
struct EnergyFill: View {
    let tint: Color
    let cut: CGFloat
    let sweep: Bool   // one-shot shimmer when the bar completes

    @State private var sweepX: CGFloat = -0.45

    var body: some View {
        let shape = CutCornerBar(cut: cut)
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [tint, tint.opacity(0.82), tint.opacity(0.95)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            // Top gloss for glassy depth.
            shape.fill(
                LinearGradient(colors: [Color.white.opacity(0.45), .clear],
                               startPoint: .top, endPoint: .center)
            )
            .blendMode(.screen)
            // One-shot shimmer sweep on completion.
            GeometryReader { g in
                let w = max(1, g.size.width)
                shape.fill(
                    LinearGradient(colors: [.clear, Color.white.opacity(0.75), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: w * 0.32)
                .offset(x: w * sweepX)
                .blendMode(.screen)
                .opacity(sweep ? 1 : 0)
            }
        }
        .clipShape(shape)
        .onChange(of: sweep) { _, on in
            guard on else { return }
            sweepX = -0.45
            withAnimation(.easeOut(duration: 0.5)) { sweepX = 1.15 }
        }
    }
}

struct RPGStatBar: View {
    let from: Double
    let to: Double
    let tint: Color
    let animate: Bool
    var height: CGFloat = 18
    var segments: Int = 10
    var showOriginCap: Bool = false
    var originAssetName: String? = nil
    var endpointAssetName: String? = nil
    var tickAssetName: String? = nil
    /// Only fire the end flourish (shimmer sweep + cap ignite) on a celebratory
    /// completion — i.e. a level-up. A plain fill stays clean and readable.
    var celebrate: Bool = false
    /// When set, the parent drives the fill directly (used by the level-up
    /// choreography: fill→100→reset→refill). The bar skips its own staging.
    var controlledProgress: Double? = nil
    /// Parent-triggered flourish (cap ignite + shimmer) for the controlled path.
    var forceFlourish: Bool = false

    @State private var displayedProgress: Double = 0
    @State private var reachedEnd = false

    private var flourish: Bool {
        controlledProgress != nil ? forceFlourish : (reachedEnd && celebrate)
    }
    private var fillProgress: Double { controlledProgress ?? displayedProgress }

    var body: some View {
        GeometryReader { geo in
            let capWidth = showOriginCap ? height * 1.55 : height * 0.70
            let rightCapWidth = height * 0.86
            // Pull the track left so the origin diamond sits at the fill origin
            // (otherwise the diamond floats too far left of the bar).
            let trackX = showOriginCap ? capWidth * 0.5 : capWidth * 0.72
            let trackWidth = max(24, geo.size.width - trackX - rightCapWidth * 0.72)
            let trackHeight = height * 0.54

            ZStack(alignment: .leading) {
                // Left origin ornament. This is vector so it scales perfectly.
                OriginCap(tint: tint, hot: flourish, ornate: showOriginCap, assetName: originAssetName)
                    .frame(width: capWidth, height: height)
                    .position(x: capWidth / 2, y: height / 2)
                    .zIndex(3)

                // Main track frame.
                CutCornerBar(cut: trackHeight * 0.42)
                    .fill(Color.unbound.bg.opacity(0.92))
                    .frame(width: trackWidth, height: trackHeight)
                    .overlay(
                        CutCornerBar(cut: trackHeight * 0.42)
                            .strokeBorder(Color.unbound.textPrimary.opacity(0.34), lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        CutCornerBar(cut: trackHeight * 0.42)
                            .fill(tint.opacity(0.18))
                            .frame(width: trackWidth * min(1, max(0, from)))
                    }
                    .overlay(alignment: .leading) {
                        let fillWidth = trackWidth * min(1, max(0, fillProgress))
                        EnergyFill(tint: tint, cut: trackHeight * 0.42, sweep: flourish)
                            .frame(width: fillWidth, height: trackHeight)
                            .overlay(alignment: .trailing) {
                                // Glowing head — blooms only on a celebratory completion.
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: trackHeight * 0.5, height: trackHeight)
                                    .blur(radius: trackHeight * 0.32)
                                    .opacity(flourish ? 0.95 : 0)
                                    .shadow(color: tint, radius: trackHeight * 0.6)
                                    .shadow(color: tint.opacity(0.8), radius: trackHeight)
                                    .animation(.easeOut(duration: 0.25), value: flourish)
                            }
                            .shadow(color: tint.opacity(flourish ? 0.6 : 0.32), radius: height * 0.38)
                    }
                    .overlay {
                        HStack(spacing: 0) {
                            ForEach(0..<segments, id: \.self) { index in
                                if index > 0 {
                                    BarTick(assetName: tickAssetName)
                                        .frame(width: showOriginCap ? 6 : 4, height: trackHeight * 1.55)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .position(x: trackX + trackWidth / 2, y: height / 2)
                    .zIndex(1)

                // Right end cap — ignites when the energy reaches it.
                EndCap(tint: tint, ignited: flourish, assetName: endpointAssetName)
                    .frame(width: rightCapWidth, height: height * 0.78)
                    .position(x: trackX + trackWidth, y: height / 2)
                    .zIndex(2)
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
        .onAppear { stageFill() }
        .onChange(of: animate) { _, _ in stageFill() }
        .onChange(of: to) { _, _ in stageFill() }
    }

    private func stageFill() {
        guard controlledProgress == nil else { return }   // parent drives the fill
        displayedProgress = min(1, max(0, from))
        reachedEnd = false
        guard animate else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 1.05)) {
                displayedProgress = min(1, max(0, to))
            }
        }
        // The flourish — shimmer sweep + end-cap ignite — lands as the fill completes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 + 1.05) {
            reachedEnd = true
        }
    }
}

struct OriginCap: View {
    let tint: Color
    let hot: Bool
    let ornate: Bool
    let assetName: String?

    var body: some View {
        ZStack {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(ornate ? 1.45 : 1.25)
                    .shadow(color: hot ? tint.opacity(0.42) : .clear, radius: 8)
            } else {
                DiamondShard()
                    .fill(
                        LinearGradient(
                            colors: hot
                                ? [tint, tint.opacity(0.7), Color.unbound.bg]
                                : [Color.unbound.surfaceElevated, Color.unbound.bg],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(DiamondShard().stroke(Color.unbound.textPrimary.opacity(0.50), lineWidth: 1))
                    .shadow(color: hot ? tint.opacity(0.55) : .clear, radius: 9)
                DiamondShard()
                    .stroke(tint.opacity(hot ? 0.95 : 0.72), lineWidth: 1)
                    .padding(ornate ? 3 : 5)
                if ornate {
                    Rectangle()
                        .fill(tint.opacity(0.72))
                        .frame(width: 2, height: 18)
                        .rotationEffect(.degrees(35))
                }
            }
        }
    }
}

struct EndCap: View {
    let tint: Color
    let ignited: Bool
    let assetName: String?

    var body: some View {
        ZStack {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.18)
                    .shadow(color: tint.opacity(ignited ? 0.7 : 0.26), radius: ignited ? 11 : 5)
            } else {
                DiamondShard()
                    .fill(
                        LinearGradient(
                            colors: ignited
                                ? [Color.white, tint, tint.opacity(0.82)]
                                : [Color.unbound.surfaceElevated, Color.unbound.bg],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(DiamondShard().stroke(
                        ignited ? Color.white.opacity(0.85) : Color.unbound.textPrimary.opacity(0.45),
                        lineWidth: 1))
                    .shadow(color: ignited ? tint.opacity(0.9) : .clear, radius: ignited ? 14 : 0)
                DiamondShard()
                    .stroke(tint.opacity(ignited ? 0.95 : 0.5), lineWidth: 1)
                    .padding(4)
            }
        }
        .scaleEffect(ignited ? 1.18 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.5), value: ignited)
    }
}

struct BarTick: View {
    let assetName: String?

    var body: some View {
        Group {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.74)
            } else {
                Rectangle()
                    .fill(Color.unbound.bg.opacity(0.72))
                    .frame(width: 1)
            }
        }
    }
}

struct DiamondShard: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CutCornerBar: InsettableShape {
    var cut: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let c = min(cut, r.height / 2, r.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> CutCornerBar {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

struct RewardBadgeAsset: View {
    let unlock: BadgeUnlock
    let tint: Color

    var body: some View {
        let badge = BadgeCatalog.all.first { $0.id == unlock.id }
        BadgeMedallion(
            iconSystemName: badge?.iconSystemName ?? "rosette",
            rarity: badge?.rarity ?? (unlock.rankTier != nil ? .legendary : .rare),
            size: 54,
            unlocked: true
        )
        .accessibilityLabel(unlock.title)
    }
}

struct AttributeDeltaRow: View {
    let delta: AttributeDeltaReward

    var body: some View {
        HStack(spacing: 8) {
            Text(delta.key.shortCode)
                .font(Font.unbound.monoS.weight(.heavy))
                .foregroundStyle(delta.tint)
                .frame(width: 34, alignment: .leading)
            Text("+\(Int(delta.xpGained.rounded())) XP")
                .font(Font.unbound.monoS.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Image(systemName: delta.didAdvanceTier ? "arrow.up.right.square.fill" : "arrow.up")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(delta.tint)
            Spacer(minLength: 0)
        }
    }
}

struct PRRewardRow: View {
    let pr: PersonalRecordReward

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if UIImage(named: "badge_art_pr_session") != nil {
                    Image("badge_art_pr_session")
                        .resizable()
                        .scaledToFit()
                        .shadow(color: pr.family.tint.opacity(0.35), radius: 10)
                } else {
                    ZStack {
                        Circle().fill(pr.family.tint.opacity(0.20))
                        Image(systemName: "target")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(pr.family.tint)
                    }
                }
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(pr.liftName.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(pr.deltaText.uppercased())
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            Text(pr.valueText.uppercased())
                .font(Font.unbound.monoM.weight(.heavy))
                .foregroundStyle(pr.family.tint)
        }
    }
}

struct SegmentedArcProgress: View {
    let progress: Double
    let segments: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(segments, 1), id: \.self) { index in
                let filled = Double(index + 1) / Double(max(segments, 1)) <= progress + 0.001
                Rectangle()
                    .fill(filled ? tint : Color.unbound.surfaceElevated)
                    .frame(height: 18)
                    .overlay(Rectangle().stroke(Color.unbound.borderSubtle, lineWidth: 1))
                    .shadow(color: filled ? tint.opacity(0.35) : .clear, radius: 8)
            }
        }
    }
}

struct CosmeticUnlockRow: View {
    let unlock: CosmeticUnlockReward

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if UIImage(named: "badge_art_cosmetic_prism") != nil {
                    Image("badge_art_cosmetic_prism")
                        .resizable()
                        .scaledToFit()
                        .shadow(color: unlock.tint.opacity(0.35), radius: 12)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(colors: [unlock.tint.opacity(0.85), Color.unbound.textPrimary.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.unbound.textPrimary.opacity(0.6), lineWidth: 1))
                }
            }
            .frame(width: 52, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("COSMETIC UNLOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(unlock.tint)
                Text(unlock.title.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(unlock.subtitle)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
        }
    }
}
