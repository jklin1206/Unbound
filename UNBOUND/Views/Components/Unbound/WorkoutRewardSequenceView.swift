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
    @State private var hexPrev: [AttributeKey: Double] = [:]   // phase from-map
    @State private var hexCur: [AttributeKey: Double] = [:]    // phase to-map
    @State private var finishRequested = false

    private enum RewardBeatKind: Equatable {
        case sessionComplete
        case xp
        case rankBadge
        case proof
        case rankReveal
        case attributes
        case collection
        case progression
        case rankTrial
        case weeklyVow
        case cosmetic
        case streak
        case final
    }

    private var rewardBeats: [RewardBeatKind] {
        var beats: [RewardBeatKind] = [.sessionComplete]

        if summary.xp.total > 0 || !summary.xp.breakdown.isEmpty {
            beats.append(.xp)
        }

        // Dedicated badge reveal for the top rank earned this session — shown
        // just before the cleared-standards breakdown.
        if earnedBadgeTier != nil {
            beats.append(.rankBadge)
        }

        if !summary.exerciseRanks.isEmpty || !summary.beats.isEmpty || summary.tally.hasAnyReward {
            beats.append(.proof)
        }

        // Movement-XP impact only — lift rank-ups now live on the RANKS page.
        if summary.progression?.movementLines.isEmpty == false {
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

        if summary.rankTrialCallout != nil {
            beats.append(.rankTrial)
        }

        if summary.weeklyVowCallout != nil {
            beats.append(.weeklyVow)
        }

        if !summary.cosmeticUnlocks.isEmpty {
            beats.append(.cosmetic)
        }

        if let streak = summary.streak, streak.dayCount > 0 {
            beats.append(.streak)
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

    /// Highest rank tier earned this session (across all cleared/unlocked beats).
    /// Drives the dedicated badge reveal.
    private var earnedBadgeTier: SkillTier? {
        summary.beats.compactMap(\.tier).max()
    }

    /// The skill whose top earned tier is being celebrated.
    private var earnedBadgeSkillTitle: String? {
        guard let tier = earnedBadgeTier else { return nil }
        return summary.beats.first { $0.tier == tier }?.skillTitle
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
        if let rankTrial = summary.rankTrialCallout { return rankTrial.passed ? Color.unbound.rankGold : Color.unbound.alert }
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
        case .rankBadge:
            rankBadgeBeat
        case .proof:
            ranksBeat
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
        case .rankTrial:
            rankTrialBeat
        case .weeklyVow:
            weeklyVowBeat
        case .cosmetic:
            cosmeticBeat
        case .streak:
            streakBeat
        case .final:
            finalYield
        }
    }

    private var cosmeticBeat: some View {
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

                Text("Equip in Settings → Appearance.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var streakBeat: some View {
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

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(summary.volumeKg.rounded()))")
                            .font(.system(size: 66, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .shadow(color: Color.white.opacity(0.35), radius: 18)
                        Text("KG")
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

    private var rankBadgeBeat: some View {
        let tier = earnedBadgeTier ?? .novice
        return RewardPanel(tint: tier.rewardTint, active: currentBeatKind == .rankBadge) {
            RankBadgeRevealView(
                tier: tier,
                skillTitle: earnedBadgeSkillTitle ?? "",
                multi: summary.tally.ranksAdvanced > 1 ? summary.tally.ranksAdvanced : nil,
                active: currentBeatKind == .rankBadge && pageRevealed
            )
        }
    }

    /// Unified RANKS page — one card per exercise (skills AND lifts) showing the
    /// rank badge earned, a bar toward the next rank, and any PR. Replaces the old
    /// per-(skill,tier) "proof" rows and the separate lift-rank page.
    private var ranksBeat: some View {
        let ranks = summary.exerciseRanks
        let tint = proofTint
        let rankUpCount = ranks.filter(\.didRankUp).count + (ranks.isEmpty ? summary.tally.ranksAdvanced : 0)
        let title = rankUpCount > 1 ? "RANKS EARNED" : (rankUpCount == 1 ? "RANK UP" : "RANKS")

        return RewardPanel(tint: tint, active: currentBeatKind == .proof || summary.emblemIgnition) {
            VStack(alignment: .leading, spacing: 16) {
                beatHeader(kicker: "RANKS", title: title, tint: tint)

                if !ranks.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(ranks) { reward in
                            ExerciseRankCard(
                                reward: reward,
                                animate: currentBeatKind == .proof && pageRevealed
                            )
                        }
                    }
                } else if !summary.beats.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(summary.beats) { beat in
                            ProofRewardRow(beat: beat, tint: tint)
                        }
                    }
                } else {
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

    @ViewBuilder
    private var rankRevealBeat: some View {
        if let receipt = summary.progression, !receipt.movementLines.isEmpty {
            movementImpactBeat(receipt)
        }
    }

    private func movementImpactBeat(_ receipt: ProgressionReceipt) -> some View {
        let lines = Array(receipt.movementLines.prefix(3))
        let rankedUp = lines.contains(where: \.didRankUp)
        let tint = rankedUp ? Color.unbound.rankGold : Color.unbound.success

        return RewardPanel(tint: tint, active: currentBeatKind == .rankReveal) {
            VStack(alignment: .leading, spacing: 18) {
                beatHeader(
                    kicker: rankedUp ? "MOVEMENT RANK UP" : "MOVEMENT XP",
                    title: rankedUp ? "TIER ASCENDED" : "EARNED THIS SESSION",
                    tint: tint
                )

                if let topLine = lines.first {
                    MovementXPSpotlight(
                        line: topLine,
                        tint: topLine.didRankUp ? Color.unbound.rankGold : tint,
                        animate: currentBeatKind == .rankReveal && pageRevealed
                    )
                }

                VStack(spacing: 12) {
                    ForEach(lines.dropFirst()) { line in
                        MovementXPProgressRow(
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
                            levels: previousAttributeLevels,
                            tiers: previousAttributeTiers,
                            showLabels: false,
                            radius: 66
                        )
                        .opacity(0.20)
                        .frame(width: 142, height: 142)

                        AnimatedRewardAttributeHex(
                            previous: hexPrev.isEmpty ? previousAttributeMap : hexPrev,
                            current: hexCur.isEmpty ? currentAttributeMap : hexCur,
                            levels: currentAttributeLevels,
                            tiers: currentAttributeTiers,
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(badge.title.uppercased())
                                    .font(Font.unbound.bodyMStrong)
                                    .foregroundStyle(badge.rankTier == nil ? Color.unbound.textPrimary : badgeTint)
                                Text(badge.subtitle ?? "Unlocked this session.")
                                    .font(Font.unbound.captionS)
                                    .foregroundStyle(Color.unbound.textTertiary)
                                if badge.rankTier == nil {
                                    Text("UNLOCKS PROFILE TITLE")
                                        .font(Font.unbound.monoS)
                                        .tracking(0.6)
                                        .foregroundStyle(badgeTint)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(badgeTint.opacity(0.16)))
                                        .padding(.top, 1)
                                }
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
                beatHeader(kicker: "SESSION LEDGER", title: "EARNED XP", tint: Color.unbound.success)

                VStack(spacing: 12) {
                    ReceiptTotalRow(
                        label: "Movement XP",
                        value: "+\(formatReceiptNumber(receipt.totalMovementAP)) XP",
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
                    progressionMiniSection(title: "Movements") {
                        VStack(spacing: 10) {
                            ForEach(receipt.movementLines) { line in
                                MovementXPProgressRow(
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
    private var rankTrialBeat: some View {
        if let callout = summary.rankTrialCallout {
            let tint = callout.passed ? Color.unbound.rankGold : Color.unbound.alert
            RewardPanel(tint: tint, active: currentBeatKind == .rankTrial) {
                VStack(alignment: .leading, spacing: 18) {
                    beatHeader(kicker: "RANK TRIAL RECEIPT", title: callout.title.uppercased(), tint: tint)

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

                    VStack(spacing: 10) {
                        rewardLine(label: "Verdict", value: callout.passed ? "Cleared" : "Not Cleared", tint: tint)
                        rewardLine(label: "Detail", value: callout.detailLine, tint: Color.rewardBlue)
                        rewardLine(label: "Receipt", value: callout.receiptLine, tint: tint)
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
                            rewardLine(label: "Vow Bonus", value: "+\(bonus.overallLevelXP) LVL XP", tint: Color.rewardBlue)
                            rewardLine(label: "Vow Badge", value: bonus.badgeProgress.displayText, tint: tint)
                            rewardLine(label: "Vow Cosmetic", value: bonus.cosmeticProgress.displayText, tint: tint)
                        }
                        rewardLine(label: "Standard", value: callout.proofName, tint: tint)
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
                let primaryXPLabel = summary.xp.total > 0 ? "LVL XP" : "SKILL XP"
                let proofCount = summary.tally.standardsCleared + summary.tally.unlocksGained + summary.tally.newBests
                let featCount = summary.personalRecords.count + summary.badges.count + proofCount + (summary.weeklyVowCallout == nil ? 0 : 1)
                let featLabel = proofCount > 0 ? "RANKS" : (summary.weeklyVowCallout == nil ? "FEATS" : "VOW")
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
        UnboundSound.shared.preloadRewardKit()
        UnboundHaptics.heavy()
        playSound(for: currentBeatKind)
        revealCurrentPage()
        #if DEBUG
        // Reward-demo recording: drive the page advances hands-free so the whole
        // sequence plays autonomously for a screen capture (no tap injection).
        if ProcessInfo.processInfo.arguments.contains("-rewardDemo")
            || ProcessInfo.processInfo.environment["REWARD_DEMO"] == "1" {
            for step in 1...(maxBeat + 1) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.3 * Double(step)) {
                    advanceRewardPage()
                }
            }
        }
        #endif
    }

    private func revealCurrentPage() {
        let revealedBeat = currentBeatKind
        if revealedBeat == .attributes { attributeHexProgress = 0 }

        pageRevealed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                pageRevealed = true
            }
            guard revealedBeat == .attributes else { return }
            runHexSequence()
        }
    }

    /// Attribute-hex reveal. Every axis fills from its prior level-progress to its
    /// new progress; an axis that LEVELED UP this session overshoots to full,
    /// then rolls over (snap to empty) and refills to its new (small) progress —
    /// the same level-up feel as the XP bar, per axis.
    private func runHexSequence() {
        let prev = previousAttributeMap
        let cur = currentAttributeMap
        let leveled = Set(summary.attributeDeltas.filter(\.didIncreaseLevel).map(\.key))

        // Phase 1: fill toward current; leveled axes overshoot to full.
        var phase1 = cur
        for key in leveled { phase1[key] = 100 }
        hexPrev = prev
        hexCur = phase1
        attributeHexProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: leveled.isEmpty ? 1.15 : 0.95)) {
                attributeHexProgress = 1
            }
        }

        guard !leveled.isEmpty else { return }

        // Phase 2: leveled axes roll over — snap empty, then refill to real value.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 + 0.95 + 0.16) {
            var from = cur
            for key in leveled { from[key] = 0 }
            hexPrev = from
            hexCur = cur
            attributeHexProgress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                withAnimation(.easeOut(duration: 0.7)) { attributeHexProgress = 1 }
            }
        }
    }

    private func animateXP() {
        animatedXP = 0
        let total = summary.xp.total
        for step in 1...12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65 + Double(step) * 0.055) {
                animatedXP = Int(Double(total) * Double(step) / 12.0)
                // Rising tick zips up with the count (pitch climbs as the bar fills).
                UnboundSound.shared.play(.xpTick, volume: 0.32, rate: 1.0 + Float(step) / 12.0 * 0.7)
            }
        }
    }

    /// Per-beat audio. XP ticks (animateXP), the level-up chord (LevelProgressHero),
    /// and the rank stinger (RankBadgeRevealView) are fired from their own views.
    private func playSound(for kind: RewardBeatKind) {
        switch kind {
        case .sessionComplete: UnboundSound.shared.play(.sessionComplete, volume: 0.85)
        case .cosmetic: UnboundSound.shared.play(.rankReveal, volume: 0.7)
        case .streak: UnboundSound.shared.play(.rankReveal, volume: 0.7)
        case .final: UnboundSound.shared.play(.finish)
        default: break
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

        playSound(for: currentBeatKind)

        switch currentBeatKind {
        case .xp:
            animatedXP = 0
            UnboundHaptics.heavy()
        case .proof, .rankReveal, .attributes, .collection, .progression, .rankTrial, .weeklyVow, .cosmetic, .streak:
            UnboundHaptics.medium()
        case .sessionComplete, .final, .rankBadge:
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

    // The reward hex shows progress toward the next level (moves a lot per
    // session), not the absolute level/100 (that's the profile's job).
    private var previousAttributeMap: [AttributeKey: Double] {
        if !summary.attributePreviousHexValues.isEmpty {
            return summary.attributePreviousHexValues
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.levelProgressStart * 100) })
    }

    private var currentAttributeMap: [AttributeKey: Double] {
        if !summary.attributeCurrentHexValues.isEmpty {
            return summary.attributeCurrentHexValues
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.currentProgress * 100) })
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
        "+\(formatReceiptNumber(delta.xpGained)) XP"
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

}
