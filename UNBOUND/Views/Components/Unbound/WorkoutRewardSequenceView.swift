import SwiftUI
import UIKit

// MARK: - WorkoutRewardSequenceView
//
// Full workout-end payout. Beats are staged, but the user can continue
// immediately once the final yield is visible. Color is deliberate:
// XP uses blue, lift families own their own hues, attributes use axis
// colors, and violet is reserved for major tier/system impact.

struct WorkoutRewardSequenceView: View {
    let summary: WorkoutRewardSequenceSummary
    let onDismiss: () -> Void

    @State private var beat: Int = 0
    @State private var animatedXP: Int = 0
    @State private var pageRevealed = false
    @State private var attributeHexProgress: Double = 0
    @State private var finishRequested = false

    private enum RewardBeatKind: Equatable {
        case sessionComplete
        case xp
        case proof
        case rankReveal
        case attributes
        case collection
        case progression
        case weeklyVow
        case final
    }

    private var rewardBeats: [RewardBeatKind] {
        var beats: [RewardBeatKind] = [.sessionComplete]

        if summary.xp.total > 0 || !summary.xp.breakdown.isEmpty {
            beats.append(.xp)
        }

        if !summary.beats.isEmpty || summary.tally.hasAnyReward {
            beats.append(.proof)
        }

        if !summary.liftProgress.isEmpty || summary.progression?.movementLines.isEmpty == false {
            beats.append(.rankReveal)
        }

        if !summary.attributeDeltas.isEmpty {
            beats.append(.attributes)
        }

        if !summary.personalRecords.isEmpty || !summary.badges.isEmpty {
            beats.append(.collection)
        }

        if summary.progression?.hasContent == true {
            beats.append(.progression)
        }

        if summary.weeklyVowCallout != nil {
            beats.append(.weeklyVow)
        }

        beats.append(.final)
        return beats
    }

    private var maxBeat: Int {
        max(0, rewardBeats.count - 1)
    }

    private var currentBeatKind: RewardBeatKind {
        rewardBeats[min(max(beat, 0), maxBeat)]
    }

    var body: some View {
        ZStack {
            rewardBackdrop
            rewardAtmosphere

            VStack(spacing: 0) {
                topRail

                ScrollView(showsIndicators: false) {
                    currentRewardPage
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(420, UIScreen.main.bounds.height - 250), alignment: .center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 190)
                        .id(beat)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .scale(scale: 1.04).combined(with: .opacity)
                        ))
                }
            }

            VStack {
                Spacer()
                bottomActions
            }
        }
        .onAppear { startBeats() }
        .onChange(of: beat) { _, newBeat in
            revealCurrentPage()
            if rewardBeats[min(max(newBeat, 0), maxBeat)] == .xp {
                animateXP()
            }
        }
    }

    // MARK: - Chrome

    private var topRail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<rewardBeats.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= beat ? Color.rewardBlue.opacity(0.95) : Color.unbound.textPrimary.opacity(0.18))
                        .frame(width: index == beat ? 22 : 7, height: 3)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: beat)
                }
            }
            Text(summary.workoutName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var rewardBackdrop: some View {
        ZStack {
            Image("reward_backdrop_void")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.08)
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                .ignoresSafeArea()
            Color.black.opacity(0.72).ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color.black.opacity(0.42), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var rewardAtmosphere: some View {
        ZStack {
            RadialGradient(
                colors: [Color.rewardBlue.opacity(0.20), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            RadialGradient(
                colors: [Color.unbound.impact.opacity(0.10), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var dominantRewardTint: Color {
        if let advance = summary.liftProgress.first(where: \.didAdvanceTier) { return advance.toTier.rewardTint }
        if let pr = summary.personalRecords.first { return pr.family.tint }
        if let attribute = summary.attributeDeltas.first(where: \.didAdvanceTier) { return attribute.tint }
        if let vow = summary.weeklyVowCallout { return vow.theme.tintColor }
        return Color.rewardBlue
    }

    // MARK: - Beats

    @ViewBuilder
    private var currentRewardPage: some View {
        switch currentBeatKind {
        case .sessionComplete:
            sessionCompleteBeat
        case .xp:
            xpBeat
        case .proof:
            proofBeat
        case .rankReveal:
            rankRevealBeat
        case .attributes:
            attributeBeat
        case .collection:
            collectionBeat
        case .progression:
            if let progression = summary.progression {
                progressionBeat(progression)
            }
        case .weeklyVow:
            weeklyVowBeat
        case .final:
            finalYield
        }
    }

    private var sessionCompleteBeat: some View {
        RewardPanel(tint: Color.unbound.textPrimary, active: currentBeatKind == .sessionComplete) {
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

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(volumeText.replacingOccurrences(of: "t", with: ""))
                            .font(.system(size: 66, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .shadow(color: Color.white.opacity(0.35), radius: 18)
                        Text(summary.volumeKg >= 1000 ? "T" : "KG")
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary.opacity(0.92))
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

    private var xpBeat: some View {
        RewardPanel(tint: Color.rewardBlue, active: currentBeatKind == .xp || summary.xp.didIncreaseLevel) {
            VStack(alignment: .leading, spacing: 22) {
                beatHeader(kicker: "XP BANKED", title: "LVL", tint: Color.rewardBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                VStack(spacing: 8) {
                    ForEach(summary.xp.breakdown) { line in
                        rewardLine(label: line.label, value: "+\(line.amount) XP", tint: Color.rewardBlue)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var proofBeat: some View {
        let tally = summary.tally
        let shownBeats = Array(summary.beats.prefix(6))
        let tint = proofTint
        let title = tally.ranksAdvanced > 1 ? "MULTI-RANK UP" : (tally.unlocksGained > 0 ? "SKILL UNLOCKED" : "STANDARDS CLEARED")

        return RewardPanel(tint: tint, active: currentBeatKind == .proof || summary.emblemIgnition) {
            VStack(alignment: .leading, spacing: 20) {
                beatHeader(kicker: "PROOF LOCKED", title: title, tint: tint)

                if summary.emblemIgnition {
                    HStack(spacing: 14) {
                        ZStack {
                            RankPulseRings(tint: tint, hot: true, animate: currentBeatKind == .proof && pageRevealed)
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(tint)
                                .shadow(color: tint.opacity(0.5), radius: 18)
                        }
                        .frame(width: 86, height: 86)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(tally.ranksAdvanced > 1 ? "\(tally.ranksAdvanced) RANKS ADVANCED" : "EMBLEM IGNITED")
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                            Text("Your logged work cleared real standards.")
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }

                VStack(spacing: 10) {
                    if !shownBeats.isEmpty {
                        ForEach(shownBeats) { beat in
                            ProofRewardRow(beat: beat, tint: tint)
                        }
                    } else {
                        if tally.standardsCleared > 0 {
                            rewardLine(label: "Standards cleared", value: "\(tally.standardsCleared)", tint: tint)
                        }
                        if tally.unlocksGained > 0 {
                            rewardLine(label: "Unlocks gained", value: "\(tally.unlocksGained)", tint: tint)
                        }
                        if tally.newBests > 0 {
                            rewardLine(label: "New bests", value: "\(tally.newBests)", tint: Color.unbound.emberGlow)
                        }
                    }

                    if summary.beats.count > shownBeats.count {
                        rewardLine(
                            label: "More proof",
                            value: "+\(summary.beats.count - shownBeats.count)",
                            tint: tint
                        )
                    }
                }

                HStack(spacing: 12) {
                    proofToken(value: "\(tally.standardsCleared)", label: "STANDARDS", tint: tint)
                    proofToken(value: "\(tally.unlocksGained)", label: "UNLOCKS", tint: Color.unbound.impact)
                    proofToken(value: "\(tally.newBests)", label: "BESTS", tint: Color.unbound.emberGlow)
                }
            }
        }
    }

    @ViewBuilder
    private var rankRevealBeat: some View {
        if !summary.liftProgress.isEmpty {
            liftRankRevealBeat
        } else if let receipt = summary.progression, !receipt.movementLines.isEmpty {
            movementImpactBeat(receipt)
        }
    }

    private var liftRankRevealBeat: some View {
        let advanced = summary.liftProgress.filter(\.didAdvanceTier)
        let shown = advanced.isEmpty ? Array(summary.liftProgress.prefix(2)) : Array(advanced.prefix(2))
        let tint = shown.first?.currentTier.rewardTint ?? dominantLiftTint

        return RewardPanel(tint: tint, active: currentBeatKind == .rankReveal) {
            VStack(alignment: .leading, spacing: 22) {
                beatHeader(
                    kicker: advanced.isEmpty ? "MOVEMENT RANK" : "MOVEMENT RANK UP",
                    title: advanced.isEmpty ? "CURRENT TIER" : "TIER ASCENDED",
                    tint: tint
                )

                ForEach(shown) { lift in
                    LiftRankSpotlight(
                        lift: lift,
                        revealed: pageRevealed,
                        animate: currentBeatKind == .rankReveal && pageRevealed
                    )
                }
            }
        }
    }

    private func movementImpactBeat(_ receipt: ProgressionReceipt) -> some View {
        let lines = Array(receipt.movementLines.prefix(3))
        let tint = lines.first?.didAdvanceCheckpoint == true ? Color.unbound.rankGold : Color.unbound.success

        return RewardPanel(tint: tint, active: currentBeatKind == .rankReveal) {
            VStack(alignment: .leading, spacing: 18) {
                beatHeader(kicker: "MOVEMENT AP", title: "LIFT CREDIT", tint: tint)

                if let topLine = lines.first {
                    MovementAPSpotlight(
                        line: topLine,
                        tint: tint,
                        animate: currentBeatKind == .rankReveal && pageRevealed
                    )
                }

                VStack(spacing: 12) {
                    ForEach(lines.dropFirst()) { line in
                        MovementAPProgressRow(
                            line: line,
                            tint: Color.unbound.success,
                            animate: currentBeatKind == .rankReveal && pageRevealed
                        )
                    }
                }
            }
        }
    }

    private var attributeBeat: some View {
        RewardPanel(tint: Color.rewardBlue, active: currentBeatKind == .attributes || summary.attributeDeltas.contains(where: \.didAdvanceTier)) {
            VStack(alignment: .leading, spacing: 20) {
                beatHeader(kicker: "BUILD UPDATED", title: "ATTRIBUTE RANKS", tint: Color.rewardBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        AttributeHex(
                            current: previousAttributeMap,
                            peak: previousAttributeMap,
                            levels: previousAttributeLevels,
                            tiers: previousAttributeTiers,
                            prestigeGlow: previousAttributePrestigeGlow,
                            showLabels: false,
                            radius: 66
                        )
                        .opacity(0.20)
                        .frame(width: 142, height: 142)

                        AnimatedRewardAttributeHex(
                            previous: previousAttributeMap,
                            current: currentAttributeMap,
                            levels: currentAttributeLevels,
                            tiers: currentAttributeTiers,
                            previousPrestigeGlow: previousAttributePrestigeGlow,
                            currentPrestigeGlow: currentAttributePrestigeGlow,
                            progress: attributeHexProgress,
                            radius: 66
                        )
                        .frame(width: 142, height: 142)
                        .shadow(color: Color.rewardBlue.opacity(0.20), radius: 16)
                    }

                    if let primaryAttributeDelta {
                        AttributeRankSpotlight(
                            delta: primaryAttributeDelta,
                            animate: currentBeatKind == .attributes && pageRevealed
                        )
                    }
                }

                VStack(spacing: 12) {
                    ForEach(summary.attributeDeltas.prefix(5)) { delta in
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
    private var prBeat: some View {
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
    private var badgeBeat: some View {
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
                            VStack(alignment: .leading, spacing: 3) {
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
                }
            }
        }
    }

    private var collectionBeat: some View {
        VStack(spacing: 24) {
            if !summary.personalRecords.isEmpty { prBeat }
            if !summary.badges.isEmpty { badgeBeat }
            if summary.personalRecords.isEmpty && summary.badges.isEmpty {
                RewardPanel(tint: dominantRewardTint, active: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        beatHeader(kicker: "COLLECTED", title: "SESSION SPOILS", tint: dominantRewardTint)
                        rewardLine(label: "XP BANKED", value: "+\(summary.xp.total)", tint: Color.rewardBlue)
                        rewardLine(label: "LIFT BANDS", value: "\(summary.liftProgress.count)", tint: dominantLiftTint)
                    }
                }
            }
        }
    }

    private func progressionBeat(_ receipt: ProgressionReceipt) -> some View {
        RewardPanel(tint: Color.unbound.success, active: currentBeatKind == .progression) {
            VStack(alignment: .leading, spacing: 16) {
                beatHeader(kicker: "ASCENSION LEDGER", title: "ROUTED CREDIT", tint: Color.unbound.success)

                VStack(spacing: 12) {
                    ReceiptTotalRow(
                        label: "Movement AP",
                        value: "+\(formatReceiptNumber(receipt.totalMovementAP)) AP",
                        tint: Color.unbound.success,
                        show: receipt.totalMovementAP > 0
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

                if !receipt.movementLines.isEmpty {
                    progressionMiniSection(title: "Movement Banks") {
                        VStack(spacing: 10) {
                            ForEach(receipt.movementLines) { line in
                                MovementAPProgressRow(
                                    line: line,
                                    tint: Color.unbound.success,
                                    animate: currentBeatKind == .progression && pageRevealed
                                )
                            }
                        }
                    }
                }

                if !receipt.bodyRegionLines.isEmpty {
                    progressionMiniSection(title: "Body Regions") {
                        Text(receipt.bodyRegionLines.map(\.name).joined(separator: " · "))
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weeklyVowBeat: some View {
        if let callout = summary.weeklyVowCallout {
            let tint = callout.theme.tintColor
            RewardPanel(tint: tint, active: currentBeatKind == .weeklyVow) {
                VStack(alignment: .leading, spacing: 18) {
                    beatHeader(kicker: "BINDING VOW BONUS", title: callout.title.uppercased(), tint: tint)

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(tint.opacity(0.18))
                                .frame(width: 66, height: 66)
                            Circle()
                                .stroke(tint.opacity(0.72), lineWidth: 1.5)
                                .frame(width: 66, height: 66)
                            Image(systemName: "checkmark.seal.fill")
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
                            Text(callout.shareSubtitle.uppercased())
                                .font(Font.unbound.captionS.weight(.semibold))
                                .tracking(1.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                        }
                    }

                    VStack(spacing: 10) {
                        if let bonus = callout.completionBonus {
                            rewardLine(label: "Binding Bonus", value: "+\(bonus.overallLevelXP) LV XP", tint: Color.rewardBlue)
                            rewardLine(label: "Binding Badge", value: bonus.badgeProgress.displayText, tint: tint)
                            rewardLine(label: "Binding Cosmetic", value: bonus.cosmeticProgress.displayText, tint: tint)
                        }
                        rewardLine(label: "Proof", value: callout.proofName, tint: tint)
                        rewardLine(label: "Receipt", value: callout.receiptLine, tint: Color.rewardBlue)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: callout.completionBonus?.shareCard == nil ? "checkmark.seal.fill" : "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text(callout.completionBonus?.shareCard == nil ? "RECEIPT SAVED" : "SHARE CARD READY")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.8)
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(tint.opacity(0.12)))
                    .overlay(Capsule().stroke(tint.opacity(0.42), lineWidth: 1))
                }
            }
        }
    }

    private var arcBeat: some View {
        RewardPanel(tint: summary.arcProgress.didCompleteArc ? Color.unbound.impact : Color.unbound.rankGold, active: currentBeatKind == .collection) {
            VStack(alignment: .leading, spacing: 14) {
                beatHeader(kicker: "ARC PROGRESS", title: summary.arcProgress.arcName.uppercased(), tint: summary.arcProgress.didCompleteArc ? Color.unbound.impact : Color.unbound.rankGold)

                SegmentedArcProgress(progress: summary.arcProgress.progress, segments: summary.arcProgress.totalSessions, tint: summary.arcProgress.didCompleteArc ? Color.unbound.impact : Color.unbound.rankGold)

                HStack {
                    Text("SESSION \(summary.arcProgress.completedSessions) / \(summary.arcProgress.totalSessions) COMPLETE")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                    Text("WEEK \(summary.arcProgress.week)/\(summary.arcProgress.totalWeeks)")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                if summary.arcProgress.didCompleteWeek || summary.arcProgress.didCompleteArc {
                    rewardLine(
                        label: summary.arcProgress.didCompleteArc ? "ARC CLOSED" : "WEEK COMPLETE",
                        value: "+\(summary.arcProgress.bonusXP) XP",
                        tint: summary.arcProgress.didCompleteArc ? Color.unbound.impact : Color.unbound.rankGold
                    )
                }
            }
        }
    }

    private var finalYield: some View {
        RewardPanel(tint: dominantRewardTint, active: true) {
            VStack(spacing: 24) {
                Text("REWARDS COLLECTED")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)

                let skillXP = summary.progression?.skillXPGained ?? 0
                let primaryXPValue = summary.xp.total > 0 ? "+\(summary.xp.total)" : "+\(skillXP)"
                let primaryXPLabel = summary.xp.total > 0 ? "LV XP" : "SKILL XP"
                let proofCount = summary.tally.standardsCleared + summary.tally.unlocksGained + summary.tally.newBests
                let featCount = summary.personalRecords.count + summary.badges.count + proofCount + (summary.weeklyVowCallout == nil ? 0 : 1)
                let featLabel = proofCount > 0 ? "PROOF" : (summary.weeklyVowCallout == nil ? "FEATS" : "BIND")
                HStack(spacing: 20) {
                    yieldToken(value: primaryXPValue, label: primaryXPLabel, tint: Color.rewardBlue)
                    yieldToken(value: "\(summary.liftProgress.filter(\.didAdvanceTier).count + summary.tally.ranksAdvanced)", label: "RANK UPS", tint: dominantLiftTint)
                    yieldToken(value: "\(featCount)", label: featLabel, tint: proofCount > 0 ? proofTint : (summary.weeklyVowCallout?.theme.tintColor ?? Color.unbound.impact))
                }

                if let callout = summary.weeklyVowCallout {
                    weeklyVowShareChip(callout)
                } else if let badge = summary.badges.first {
                    RewardBadgeAsset(unlock: badge, tint: badge.rankTier?.rewardTint ?? Color.unbound.impact)
                        .frame(width: 76, height: 76)
                        .shadow(color: (badge.rankTier?.rewardTint ?? Color.unbound.impact).opacity(0.45), radius: 18)
                }

                Text("SESSION LOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button {
                advanceRewardPage()
            } label: {
                HStack(spacing: 10) {
                    Text(finishRequested ? "SAVING" : (beat >= maxBeat ? "FINISH" : "TAP TO COLLECT"))
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.4)
                    if finishRequested {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.unbound.textPrimary)
                    } else {
                        Image(systemName: beat >= maxBeat ? "checkmark" : "chevron.right")
                            .font(.system(size: 11, weight: .black))
                    }
                }
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.92))
                .padding(.horizontal, 20)
                .frame(height: 46)
                .background(.ultraThinMaterial.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(Color.rewardBlue.opacity(0.50), lineWidth: 1.5))
                .shadow(color: Color.rewardBlue.opacity(0.22), radius: 16)
            }
            .buttonStyle(.plain)
            .disabled(finishRequested)
            .accessibilityIdentifier("workoutRewardContinueButton")
            .accessibilityLabel(finishRequested ? "SAVING" : (beat >= maxBeat ? "FINISH" : "TAP TO COLLECT"))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.88), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func startBeats() {
        UnboundHaptics.heavy()
        revealCurrentPage()
    }

    private func revealCurrentPage() {
        let revealedBeat = currentBeatKind
        if revealedBeat == .attributes {
            attributeHexProgress = 0
        }

        pageRevealed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                pageRevealed = true
            }
            guard revealedBeat == .attributes else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeOut(duration: 1.15)) {
                    attributeHexProgress = 1
                }
            }
        }
    }

    private func animateXP() {
        animatedXP = 0
        let total = summary.xp.total
        for step in 1...12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65 + Double(step) * 0.055) {
                animatedXP = Int(Double(total) * Double(step) / 12.0)
            }
        }
    }

    private func advanceRewardPage() {
        if beat >= maxBeat {
            guard !finishRequested else { return }
            finishRequested = true
            UnboundHaptics.medium()
            onDismiss()
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            beat += 1
        }

        switch currentBeatKind {
        case .xp:
            animatedXP = 0
            UnboundHaptics.heavy()
        case .proof, .rankReveal, .attributes, .collection, .progression, .weeklyVow:
            UnboundHaptics.medium()
        case .sessionComplete, .final:
            UnboundHaptics.soft()
        }
    }

    // MARK: - Helpers

    private var volumeText: String {
        summary.volumeKg >= 1000 ? String(format: "%.1ft", summary.volumeKg / 1000) : String(format: "%.0fkg", summary.volumeKg)
    }

    private var dominantLiftTint: Color {
        summary.liftProgress.first(where: \.didAdvanceTier)?.toTier.rewardTint ?? summary.liftProgress.first?.toTier.rewardTint ?? Color.rewardBlue
    }

    private var proofTint: Color {
        if summary.tally.ranksAdvanced > 0 || summary.emblemIgnition {
            return Color.unbound.rankGold
        }
        if summary.tally.unlocksGained > 0 {
            return Color.unbound.impact
        }
        return Color.unbound.coachCyan
    }

    private var previousAttributeMap: [AttributeKey: Double] {
        if !summary.attributePreviousHexValues.isEmpty {
            return summary.attributePreviousHexValues
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.previousHexChartValue) })
    }

    private var currentAttributeMap: [AttributeKey: Double] {
        if !summary.attributeCurrentHexValues.isEmpty {
            return summary.attributeCurrentHexValues
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.currentHexChartValue) })
    }

    private var previousAttributePrestigeGlow: [AttributeKey: Double] {
        if !summary.attributePreviousPrestigeGlow.isEmpty {
            return summary.attributePreviousPrestigeGlow
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.previousPrestigeGlow) })
    }

    private var currentAttributePrestigeGlow: [AttributeKey: Double] {
        if !summary.attributeCurrentPrestigeGlow.isEmpty {
            return summary.attributeCurrentPrestigeGlow
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.currentPrestigeGlow) })
    }

    private var previousAttributeLevels: [AttributeKey: Int]? {
        summary.attributePreviousLevels.isEmpty ? nil : summary.attributePreviousLevels
    }

    private var currentAttributeLevels: [AttributeKey: Int]? {
        summary.attributeLevels.isEmpty ? nil : summary.attributeLevels
    }

    private var previousAttributeTiers: [AttributeKey: RankTitle]? {
        let tiers = !summary.attributePreviousTiers.isEmpty
            ? summary.attributePreviousTiers
            : Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.previousTier) })
        return tiers.isEmpty ? nil : tiers
    }

    private var currentAttributeTiers: [AttributeKey: RankTitle]? {
        summary.attributeTiers.isEmpty ? nil : summary.attributeTiers
    }

    private var primaryAttributeDelta: AttributeDeltaReward? {
        summary.attributeDeltas.first(where: { $0.didAdvanceTier || $0.didIncreaseLevel })
            ?? summary.attributeDeltas.first
    }

    private func attributeDeltaText(_ delta: AttributeDeltaReward) -> String {
        if delta.xpGained >= 0.5 {
            return "+\(formatReceiptNumber(delta.xpGained)) XP"
        }
        return String(format: "+%.1f", delta.delta)
    }

    private func readout(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func beatHeader(kicker: String, title: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(tint)
            Text(title)
                .font(Font.unbound.titleM)
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textPrimary)
        }
    }

    private func rewardLine(label: String, value: String, tint: Color) -> some View {
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

    private func progressionMiniSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(height: 1)
            Text(title.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
            content()
        }
    }

    private func formatReceiptNumber(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    private func weeklyVowShareChip(_ callout: WeeklyVowRewardCallout) -> some View {
        let tint = callout.theme.tintColor
        let chipTitle = callout.completionBonus?.shareCard?.title ?? callout.shareTitle
        return HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .black))
            VStack(alignment: .leading, spacing: 2) {
                Text(chipTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.5)
                Text(callout.receiptLine.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.42), lineWidth: 1))
    }

    private func yieldToken(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
            Text(label)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func proofToken(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
            Text(label)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
    }
}

// MARK: - Components

private func formatWhole(_ value: Double) -> String {
    "\(Int(value.rounded()))"
}

private struct CinematicRewardHUD: View {
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

private struct HUDNotchedLine: View {
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

private struct TriangleCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct RewardPanel<Content: View>: View {
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

private struct ProofRewardRow: View {
    let beat: RewardBeat
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(beat.title.uppercased())
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(beat.subtitle.uppercased())
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(0.9)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            if let tier = beat.tier {
                Text(tier.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
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

private struct AnimatedRewardAttributeHex: View, Animatable {
    let previous: [AttributeKey: Double]
    let current: [AttributeKey: Double]
    let levels: [AttributeKey: Int]?
    let tiers: [AttributeKey: RankTitle]?
    let previousPrestigeGlow: [AttributeKey: Double]
    let currentPrestigeGlow: [AttributeKey: Double]
    var progress: Double
    let radius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        AttributeHex(
            current: interpolated(from: previous, to: current),
            peak: previous,
            levels: levels,
            tiers: tiers,
            prestigeGlow: interpolated(from: previousPrestigeGlow, to: currentPrestigeGlow),
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

private struct LevelProgressHero: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("LVL \(levelAfter)")
                            .font(.system(size: 54, weight: .black, design: .monospaced))
                            .tracking(0)
                            .foregroundStyle(tint)
                            .shadow(color: tint.opacity(0.52), radius: 20)
                        if levelAfter > levelBefore {
                            Text("UP")
                                .font(Font.unbound.captionS.weight(.black))
                                .tracking(1.8)
                                .foregroundStyle(Color.unbound.bg)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tint, in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(formatWhole(xpGained)) XP")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(levelAfter > levelBefore ? "LVL \(levelBefore) -> \(levelAfter)" : "LVL \(levelAfter)")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.3)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            RPGStatBar(
                from: barStart,
                to: progressAfter,
                tint: tint,
                animate: animate,
                height: 32,
                segments: 10,
                showOriginCap: true
            )
            .shadow(color: tint.opacity(0.42), radius: 20)

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
    }

    private var barStart: Double {
        levelAfter > levelBefore ? 0 : progressBefore
    }
}

private struct LiftRankSpotlight: View {
    let lift: LiftProgressReward
    let revealed: Bool
    let animate: Bool

    var body: some View {
        let rankTint = lift.currentTier.rewardTint
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RankPulseRings(tint: rankTint, hot: lift.didAdvanceTier, animate: animate)
                    Image(lift.currentTier.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .scaleEffect(revealed ? 1 : 0.72)
                        .opacity(revealed ? 1 : 0)
                }
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 8) {
                    Text(lift.liftName.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Text(lift.currentTier.displayName.uppercased())
                        .font(.system(size: 31, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(rankTint)
                        .shadow(color: rankTint.opacity(0.52), radius: 14)
                    Text(lift.didAdvanceTier ? "ADVANCED FROM \(lift.fromTier.displayName.uppercased())" : "\(Int(lift.toProgress * 100))% TO \(lift.nextTierName.uppercased())")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RPGStatBar(
                from: lift.didAdvanceTier ? 0 : lift.fromProgress,
                to: lift.toProgress,
                tint: rankTint,
                animate: animate,
                height: 22,
                segments: 9,
                showOriginCap: false
            )
            .shadow(color: rankTint.opacity(0.30), radius: 14)
        }
        .padding(.vertical, 4)
    }
}

private struct MovementAPSpotlight: View {
    let line: ProgressionMovementLine
    let tint: Color
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RankPulseRings(tint: tint, hot: line.didAdvanceCheckpoint, animate: animate)
                    VStack(spacing: 0) {
                        Text("+\(formatWhole(line.apGained))")
                            .font(.system(size: 31, weight: .black, design: .monospaced))
                            .foregroundStyle(tint)
                        Text("AP")
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
                    Text(line.didAdvanceCheckpoint ? "CHECKPOINT CLEARED" : "CURRENT AP BANK")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(tint)
                    Text("\(formatWhole(line.apIntoCurrentCheckpoint)) / \(formatWhole(line.apNeededForCurrentCheckpoint)) AP")
                        .font(.system(size: 27, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RPGStatBar(
                from: line.didAdvanceCheckpoint ? 0 : line.progressBefore,
                to: line.progressAfter,
                tint: tint,
                animate: animate,
                height: 24,
                segments: 10,
                showOriginCap: true
            )
        }
        .padding(.vertical, 4)
    }
}

private struct AttributeRankSpotlight: View {
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

private struct RankPulseRings: View {
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

private struct LevelUpChip: View {
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

private struct AttributeLevelProgressRow: View {
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

private struct MovementAPProgressRow: View {
    let line: ProgressionMovementLine
    let tint: Color
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("AP BANK \(formatWhole(line.totalAPAfter))")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(line.didAdvanceCheckpoint ? tint : Color.unbound.textTertiary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(formatWhole(line.apGained)) AP")
                        .font(Font.unbound.monoM.weight(.black))
                        .foregroundStyle(tint)
                    Text(line.didAdvanceCheckpoint ? "CHECKPOINT" : "\(formatWhole(line.apRemainingToCheckpoint)) AP LEFT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            RPGStatBar(
                from: barStart,
                to: line.progressAfter,
                tint: tint,
                animate: animate,
                height: 16,
                segments: 5,
                showOriginCap: false
            )

            Text("\(formatWhole(line.apIntoCurrentCheckpoint)) / \(formatWhole(line.apNeededForCurrentCheckpoint)) AP")
                .font(Font.unbound.captionS.weight(.heavy))
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    private var barStart: Double {
        line.checkpointAfter > line.checkpointBefore ? 0 : line.progressBefore
    }
}

private struct ReceiptTotalRow: View {
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

private struct RPGStatBar: View {
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

    @State private var displayedProgress: Double = 0

    var body: some View {
        GeometryReader { geo in
            let capWidth = showOriginCap ? height * 1.55 : height * 0.70
            let rightCapWidth = height * 0.86
            let trackX = capWidth * 0.72
            let trackWidth = max(24, geo.size.width - trackX - rightCapWidth * 0.72)
            let trackHeight = height * 0.54

            ZStack(alignment: .leading) {
                // Left origin ornament. This is vector so it scales perfectly.
                OriginCap(tint: tint, hot: animate, ornate: showOriginCap, assetName: originAssetName)
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
                        CutCornerBar(cut: trackHeight * 0.42)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.85), tint, Color.unbound.textPrimary.opacity(0.72)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: trackWidth * min(1, max(0, displayedProgress)))
                            .shadow(color: tint.opacity(0.46), radius: height * 0.35)
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

                // Right end cap.
                EndCap(tint: tint, assetName: endpointAssetName)
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
        displayedProgress = min(1, max(0, from))
        guard animate else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 1.05)) {
                displayedProgress = min(1, max(0, to))
            }
        }
    }
}

private struct OriginCap: View {
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
                    .fill(Color.unbound.surfaceElevated)
                    .overlay(DiamondShard().stroke(Color.unbound.textPrimary.opacity(0.50), lineWidth: 1))
                    .shadow(color: hot ? tint.opacity(0.42) : .clear, radius: 8)
                DiamondShard()
                    .stroke(tint.opacity(0.72), lineWidth: 1)
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

private struct EndCap: View {
    let tint: Color
    let assetName: String?

    var body: some View {
        ZStack {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.18)
                    .shadow(color: tint.opacity(0.26), radius: 5)
            } else {
                DiamondShard()
                    .fill(Color.unbound.surfaceElevated)
                    .overlay(DiamondShard().stroke(Color.unbound.textPrimary.opacity(0.45), lineWidth: 1))
                DiamondShard()
                    .stroke(tint.opacity(0.5), lineWidth: 1)
                    .padding(4)
            }
        }
    }
}

private struct BarTick: View {
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

private struct DiamondShard: Shape {
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

private struct CutCornerBar: InsettableShape {
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

private struct RewardBadgeAsset: View {
    let unlock: BadgeUnlock
    let tint: Color

    var body: some View {
        Group {
            if UIImage(named: unlock.assetName) != nil {
                Image(unlock.assetName)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: tint.opacity(unlock.rankTier == nil ? 0.35 : 0.55), radius: unlock.rankTier == nil ? 12 : 16)
                    .overlay {
                        if unlock.rankTier != nil {
                            Circle()
                                .stroke(tint.opacity(0.55), lineWidth: 1)
                                .blur(radius: 0.3)
                                .scaleEffect(1.08)
                        }
                    }
            } else {
                BadgeEmblemView(
                    badge: Badge(
                        id: unlock.id,
                        displayName: unlock.title,
                        description: unlock.subtitle ?? "Unlocked this session.",
                        iconSystemName: "rosette",
                        rarity: .rare,
                        unlockedAt: Date()
                    ),
                    size: 56,
                    isUnlocked: true
                )
            }
        }
        .accessibilityLabel(unlock.title)
    }
}

private struct AttributeDeltaRow: View {
    let delta: AttributeDeltaReward

    var body: some View {
        HStack(spacing: 8) {
            Text(delta.key.shortCode)
                .font(Font.unbound.monoS.weight(.heavy))
                .foregroundStyle(delta.tint)
                .frame(width: 34, alignment: .leading)
            Text(String(format: "+%.1f", delta.delta))
                .font(Font.unbound.monoS.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Image(systemName: delta.didAdvanceTier ? "arrow.up.right.square.fill" : "arrow.up")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(delta.tint)
            Spacer(minLength: 0)
        }
    }
}

private struct PRRewardRow: View {
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

private struct SegmentedArcProgress: View {
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

private struct CosmeticUnlockRow: View {
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
