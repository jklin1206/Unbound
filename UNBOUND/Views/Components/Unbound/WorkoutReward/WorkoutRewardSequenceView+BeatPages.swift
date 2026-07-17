import SwiftUI
import UIKit

extension WorkoutRewardSequenceView {
    var cosmeticBeat: some View {
        let tint = summary.cosmeticUnlocks.first?.tint ?? Color.unbound.rankGold
        return RewardPanel(tint: tint, active: currentBeatKind == .cosmetic) {
            VStack(alignment: .leading, spacing: 16) {
                beatHeader(
                    kicker: "UNLOCKED",
                    title: summary.cosmeticUnlocks.count > 1 ? "NEW COSMETICS" : "NEW COSMETIC",
                    tint: tint
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    ForEach(Array(summary.cosmeticUnlocks.enumerated()), id: \.offset) { _, unlock in
                        CosmeticUnlockRow(unlock: unlock)
                    }
                }
            }
        }
    }

    var streakBeat: some View {
        let streak = summary.streak ?? StreakReward(dayCount: 1, didExtend: true)
        let tint = Color.unbound.emberGlow
        return RewardPanel(tint: tint, active: currentBeatKind == .streak) {
            VStack(spacing: 14) {
                beatHeader(kicker: "STREAK", title: "KEEP IT LIT", tint: tint)
                    .frame(maxWidth: .infinity, alignment: .leading)

                StreakFlame(active: currentBeatKind == .streak && pageRevealed, tint: tint)
                    .frame(width: 150, height: 168)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streak.dayCount)")
                        .font(.system(size: 70, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(streak.dayCount == 1 ? "DAY" : "DAYS")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(tint)
                }

                Text("Log again within 3 days to keep it alive.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    var sessionCompleteBeat: some View {
        // Whole numbers only — "9435.8 LB" is decimal noise at hero size.
        // The number counts up fast from zero as the page reveals (odometer),
        // in the user's configured unit; Reduce Motion lands it instantly.
        let volumeTarget = weightUnit.displayValue(fromKilograms: summary.volumeKg)
        let volumeRevealed = currentBeatKind == .sessionComplete && pageRevealed
        let countsUp = !UIAccessibility.isReduceMotionEnabled
        let volumeUnit = weightUnit.shortLabel.uppercased()

        return RewardPanel(tint: Color.unbound.textPrimary, active: currentBeatKind == .sessionComplete) {
            VStack(spacing: 22) {
                Text("COMPLETED")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .shadow(color: Color.unbound.textPrimary.opacity(0.35), radius: 14)
                    .scaleEffect(pageRevealed ? 1 : 0.88)
                    .opacity(pageRevealed ? 1 : 0)

                Text(summary.workoutName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textSecondary)

                VStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.rewardBlue.opacity(0.95))
                        .frame(width: 220, height: 3)
                        .shadow(color: Color.rewardBlue.opacity(0.55), radius: 10)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        CountUpNumberText(value: (volumeRevealed || !countsUp) ? volumeTarget : 0)
                            .font(.system(size: 66, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .shadow(color: Color.white.opacity(0.35), radius: 18)
                            .animation(countsUp ? .easeOut(duration: 1.1) : nil, value: volumeRevealed)
                        Text(volumeUnit)
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary.opacity(0.85))
                    }

                    Rectangle()
                        .fill(Color.rewardBlue.opacity(0.95))
                        .frame(width: 220, height: 3)
                        .shadow(color: Color.rewardBlue.opacity(0.55), radius: 10)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .offset(y: pageRevealed ? 0 : 18)
                .opacity(pageRevealed ? 1 : 0)

                HStack(spacing: 0) {
                    readout(value: "\(summary.durationMinutes)m", label: "DURATION")
                    readout(value: "\(summary.workSets)", label: "SETS")
                    readout(value: summary.rpe.map { "\($0)" } ?? "—", label: "RPE")
                }
                .opacity(pageRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.22).delay(0.16), value: pageRevealed)
            }
            .frame(maxWidth: .infinity)
        }
    }

    var xpBeat: some View {
        RewardPanel(tint: Color.rewardBlue, active: currentBeatKind == .xp || summary.xp.didIncreaseLevel) {
            VStack(alignment: .leading, spacing: 22) {
                // No beat header here — the hero's LEVEL kicker + LVL number IS
                // this page's title. A header above it just repeated "LVL".
                LevelProgressHero(
                    label: "Level",
                    levelBefore: summary.xp.previousLevel,
                    levelAfter: summary.xp.newLevel,
                    xpGained: Double(animatedXP),
                    xpIntoLevel: summary.xp.xpIntoCurrentLevel,
                    xpNeededForLevel: summary.xp.xpNeededForCurrentLevel,
                    xpRemaining: summary.xp.xpRemainingInLevel,
                    progressBefore: summary.xp.previousProgress,
                    progressAfter: summary.xp.newProgress,
                    tint: Color.rewardBlue,
                    animate: currentBeatKind == .xp && pageRevealed
                )

                // A one-line breakdown equal to the total is an echo of the
                // counter above, not a composition — only render real splits.
                if !(summary.xp.breakdown.count == 1 && summary.xp.breakdown.first?.amount == summary.xp.total) {
                    VStack(spacing: 8) {
                        ForEach(summary.xp.breakdown) { line in
                            rewardLine(label: line.label, value: "+\(line.amount) XP", tint: Color.rewardBlue)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Unified RANKS page — one card per exercise (skills AND lifts) showing the
    /// rank badge earned, a bar toward the next rank, and any PR. Replaces the old
    /// per-(skill,tier) "proof" rows and the separate lift-rank page.
    var ranksBeat: some View {
        let ranks = summary.exerciseRanks
        let tint = proofTint
        let rankUpCount = ranks.filter(\.didRankUp).count + (ranks.isEmpty ? summary.tally.ranksAdvanced : 0)
        let title = rankUpCount > 1 ? "RANKS EARNED" : (rankUpCount == 1 ? "RANK UP" : "RANKS")

        // The hero IS the top rank-up's card — repeating it in the list below
        // was pure duplication, so the list carries only the other movements.
        let heroReward = ranks.first(where: \.didRankUp)
        let listedRanks = ranks.filter { $0.id != heroReward?.id }

        return RewardPanel(tint: tint, active: currentBeatKind == .proof || summary.emblemIgnition) {
            VStack(alignment: .leading, spacing: 16) {
                beatHeader(kicker: "RANK STANDARDS", title: title, tint: tint)

                if let heroReward {
                    RankStandardHero(
                        reward: heroReward,
                        rankUpCount: rankUpCount,
                        animate: currentBeatKind == .proof && pageRevealed
                    )
                }

                if !listedRanks.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(listedRanks) { reward in
                            ExerciseRankCard(
                                reward: reward,
                                animate: currentBeatKind == .proof && pageRevealed
                            )
                        }
                    }
                } else if ranks.isEmpty, !summary.beats.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(summary.beats) { beat in
                            ProofRewardRow(beat: beat, tint: tint)
                        }
                    }
                } else if ranks.isEmpty {
                    if summary.tally.standardsCleared > 0 {
                        rewardLine(label: "Ranks earned", value: "\(summary.tally.standardsCleared)", tint: tint)
                    }
                    if summary.tally.newBests > 0 {
                        rewardLine(label: "New bests", value: "\(summary.tally.newBests)", tint: Color.unbound.emberGlow)
                    }
                }
            }
        }
    }

    // The radar reads on the profile's honest cumulative scale, zoomed to a
    // LABELED level bracket so early shapes aren't an invisible dot. Ghost =
    // before, fill eases forward to after — a level-up is a continued push,
    // never the old fill → snap-empty → refill wrap.
    var attributeBeat: some View {
        RewardPanel(tint: Color.rewardBlue, active: currentBeatKind == .attributes || summary.attributeDeltas.contains(where: \.didAdvanceTier)) {
            VStack(alignment: .leading, spacing: 20) {
                beatHeader(kicker: "ATTRIBUTES", title: "BUILD SHIFT", tint: Color.rewardBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 14) {
                    VStack(spacing: 7) {
                        ZStack(alignment: .center) {
                            AttributeHex(
                                current: bracketScaled(previousAttributeMap),
                                showLabels: false,
                                radius: 56
                            )
                            .opacity(0.20)
                            .frame(width: 122, height: 122)

                            AnimatedRewardAttributeHex(
                                previous: bracketScaled(previousAttributeMap),
                                current: bracketScaled(currentAttributeMap),
                                progress: attributeHexProgress,
                                radius: 56
                            )
                            .frame(width: 122, height: 122)
                            .shadow(color: Color.rewardBlue.opacity(0.20), radius: 16)
                        }
                        .frame(width: 124, height: 124)
                        .padding(10)
                        .background(
                            Hexagon()
                                .fill(Color.unbound.surface.opacity(0.76))
                                .overlay(Hexagon().stroke(Color.rewardBlue.opacity(0.20), lineWidth: 1))
                        )

                        Text("GRID TO LVL \(attributeHexBracket)")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }

                    if let primaryAttributeDelta {
                        AttributeRankSpotlight(
                            delta: primaryAttributeDelta,
                            animate: currentBeatKind == .attributes && pageRevealed
                        )
                    }
                }

                // The spotlight already carries the primary attribute — the row
                // list holds only the OTHER trained axes (repeating the same
                // numbers twice on one page was the noisiest offender here).
                VStack(spacing: 12) {
                    ForEach(summary.attributeDeltas.prefix(5).filter { $0.id != primaryAttributeDelta?.id }) { delta in
                        AttributeLevelProgressRow(
                            delta: delta,
                            animate: currentBeatKind == .attributes && pageRevealed
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    var prBeat: some View {
        if !summary.personalRecords.isEmpty {
            RewardPanel(tint: summary.personalRecords.first?.family.tint ?? Color.unbound.emberGlow, active: currentBeatKind == .collection) {
                VStack(alignment: .leading, spacing: 12) {
                    beatHeader(kicker: "PERSONAL RECORD", title: "NEW BEST SET", tint: summary.personalRecords.first?.family.tint ?? Color.unbound.emberGlow)
                    ForEach(summary.personalRecords) { pr in
                        PRRewardRow(pr: pr)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var badgeBeat: some View {
        if !summary.badges.isEmpty {
            let tint = summary.badges.first?.rankTier?.rewardTint ?? Color.unbound.impact
            RewardPanel(tint: tint, active: currentBeatKind == .collection) {
                VStack(alignment: .leading, spacing: 12) {
                    beatHeader(kicker: summary.badges.contains(where: { $0.rankTier != nil }) ? "RANK SIGIL" : "BADGE UNLOCKED", title: "ARTIFACTS", tint: tint)
                    ForEach(summary.badges, id: \.id) { badge in
                        let badgeTint = badge.rankTier?.rewardTint ?? tint
                        HStack(spacing: 12) {
                            RewardBadgeAsset(unlock: badge, tint: badgeTint)
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(badge.title.uppercased())
                                    .font(Font.unbound.bodyMStrong)
                                    .foregroundStyle(badge.rankTier == nil ? Color.unbound.textPrimary : badgeTint)
                                Text(badge.subtitle ?? "Unlocked this session.")
                                    .font(Font.unbound.captionS)
                                    .foregroundStyle(Color.unbound.textTertiary)
                            }
                            Spacer()
                        }
                    }

                    // One note for the whole list — stamping a pill on every
                    // badge repeated the same promise three times in a column.
                    if summary.badges.contains(where: { $0.rankTier == nil }) {
                        Text("Each badge unlocks a profile title.")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
            }
        }
    }

    // The collection beat only exists when there are PRs or badges (see
    // rewardBeats), so no empty fallback is needed here.
    var collectionBeat: some View {
        VStack(spacing: 24) {
            if !summary.personalRecords.isEmpty { prBeat }
            if !summary.badges.isEmpty { badgeBeat }
        }
    }

    func progressionBeat(_ receipt: ProgressionReceipt) -> some View {
        RewardPanel(tint: Color.unbound.success, active: currentBeatKind == .progression) {
            VStack(alignment: .leading, spacing: 16) {
                beatHeader(kicker: "SESSION RECEIPT", title: "EARNED XP", tint: Color.unbound.success)

                VStack(spacing: 12) {
                    ReceiptTotalRow(
                        label: "Level XP",
                        value: "+\(formatReceiptNumber(receipt.overallLevelXPGained)) XP",
                        tint: Color.rewardBlue,
                        show: receipt.overallLevelXPGained > 0
                    )
                    ReceiptTotalRow(
                        label: "Skill XP",
                        value: "+\(receipt.skillXPGained) XP",
                        tint: Color.unbound.impact,
                        show: receipt.skillXPGained > 0
                    )
                    if receipt.noveltyMultiplier > 1.001 {
                        rewardLine(label: "Body Novelty", value: "\(String(format: "%.2f", receipt.noveltyMultiplier))x", tint: Color.rewardTeal)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var rankTrialBeat: some View {
        if let callout = summary.rankTrialCallout {
            let tint = callout.passed ? Color.unbound.rankGold : Color.unbound.alert
            RewardPanel(tint: tint, active: currentBeatKind == .rankTrial) {
                VStack(alignment: .leading, spacing: 18) {
                    beatHeader(kicker: "RANK TRIAL", title: callout.title.uppercased(), tint: tint)

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(tint.opacity(0.18))
                                .frame(width: 66, height: 66)
                            Circle()
                                .stroke(tint.opacity(0.72), lineWidth: 1.5)
                                .frame(width: 66, height: 66)
                            Image(systemName: callout.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(tint)
                                .shadow(color: tint.opacity(0.45), radius: 14)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(callout.subtitle.uppercased())
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                            Text(callout.statusLine.uppercased())
                                .font(Font.unbound.captionS.weight(.semibold))
                                .tracking(1.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                        }
                    }

                    // One result line; on a fail, one more line naming where it
                    // held. The old Verdict/Detail/Receipt ledger printed the
                    // same string on adjacent rows.
                    VStack(spacing: 10) {
                        rewardLine(label: "Result", value: callout.receiptLine, tint: tint)
                        if !callout.passed && callout.detailLine != callout.receiptLine {
                            rewardLine(label: "Held at", value: callout.detailLine, tint: Color.rewardBlue)
                        }
                    }
                }
            }
        }
    }

    var finalYield: some View {
        RewardPanel(tint: dominantRewardTint, active: true) {
            VStack(spacing: 24) {
                Text("REWARDS COLLECTED")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)

                let skillXP = summary.progression?.skillXPGained ?? 0
                let primaryXPValue = summary.xp.total > 0 ? "+\(summary.xp.total)" : "+\(skillXP)"
                let primaryXPLabel = summary.xp.total > 0 ? "LVL XP" : "SKILL XP"
                let rankUpCount = summary.liftProgress.filter(\.didAdvanceTier).count + summary.tally.ranksAdvanced
                let badgeCount = summary.badges.count
                // Four legible tokens max: XP, Arcs, rank ups, badges. The old
                // feats tally ("38 RANKS" next to "11 RANK UPS") counted
                // standards+unlocks+bests under a label nobody could parse.
                // Zero-value tokens are noise, not rewards — only earned tokens render.
                HStack(spacing: summary.arcsEarned > 0 ? 12 : 20) {
                    yieldToken(value: primaryXPValue, label: primaryXPLabel, tint: Color.rewardBlue)
                    if summary.arcsEarned > 0 {
                        arcYieldToken(amount: summary.arcsEarned)
                    }
                    if rankUpCount > 0 {
                        yieldToken(value: "\(rankUpCount)", label: rankUpCount == 1 ? "RANK UP" : "RANK UPS", tint: dominantLiftTint)
                    }
                    if badgeCount > 0 {
                        yieldToken(value: "\(badgeCount)", label: badgeCount == 1 ? "BADGE" : "BADGES", tint: Color.unbound.impact)
                    }
                }

                if let badge = summary.badges.first {
                    RewardBadgeAsset(unlock: badge, tint: badge.rankTier?.rewardTint ?? Color.unbound.impact)
                        .frame(width: 76, height: 76)
                        .shadow(color: (badge.rankTier?.rewardTint ?? Color.unbound.impact).opacity(0.45), radius: 18)
                }

                addPhotoButton

                Text("SESSION LOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

}
