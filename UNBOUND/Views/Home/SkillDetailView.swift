import SwiftUI

// MARK: - SkillDetailView (Form-Lead Redesign)
//
// Single clean scroll, no tabs. Top-to-bottom:
//   1. Minimal top nav (back + bookmark)
//   2. Animated hero — crossfade between two silhouette frames (when frame 2
//      asset exists), violet glow behind
//   3. Title block (centered)
//   4. Progress strip — thin XP bar
//   5. Next Beat card — current target criterion
//   6. Form section — bullets + optional "DON'T" miss
//   7. Requirements (only when locked)
//   8. Sticky bottom action — opens a rep-counter / timer / confirm sheet
//      that ultimately calls SkillProgressService.shared.awardSessionXP.

struct SkillDetailView: View {
    let node: SkillNode
    let graph: SkillGraph
    let nodeStates: [String: NodeState]

    @Environment(\.dismiss) private var dismiss
    @Bindable private var skillProgress = SkillProgressService.shared
    @ObservedObject private var skinService = SkinService.shared

    @State private var phase: Bool = false
    @State private var presentedSheet: SkillDetailSheet?
    @State private var isRankPathExpanded: Bool = false
    @State private var recentExerciseHistory: [ExerciseLogEntry] = []
    @State private var readinessHistoryLoaded: Bool = false
    @State private var selectedGuideTab: SkillGuideTab = .form
    @State private var userSkillTierState: UserSkillTierState = .empty
    @State private var bodyweightKg: Double = 70

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    topNav
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    heroBlock
                        .padding(.top, 12)

                    titleBlock
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    progressStrip
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    rankPathSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    if shouldShowUnlocksNext {
                        unlocksNextSection
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                    }

                    skillGuideSection
                        .padding(.top, 28)
                        .padding(.horizontal, 20)

                    if shouldShowRequirements {
                        requirementsSection
                            .padding(.top, 28)
                            .padding(.horizontal, 20)
                    }

                    Color.clear.frame(height: 112)
                }
            }

            stickyAction
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: Color.unbound.bg.opacity(0), location: 0),
                            .init(color: Color.unbound.bg, location: 0.18),
                            .init(color: Color.unbound.bg, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .zIndex(10)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .sheet(item: $presentedSheet) { sheet in
            sheetView(sheet)
        }
        .task(id: node.id) {
            loadUserSkillTierState()
            await loadBodyweight()
            await loadReadinessHistory()
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: SkillDetailSheet) -> some View {
        switch sheet {
        case .session:
            SkillSessionView(draft: skillSessionDraft)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        case .quickLog:
            QuickLogSheet(
                skillId: node.id,
                skillTitle: node.title,
                defaultReps: defaultRepsForQuickLog,
                isHoldBased: quickLogIsHoldBased,
                holdTargetSeconds: quickLogHoldTargetSeconds
            )
        case .trainChooser:
            trainChooserSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.unbound.bg)
        }
    }

    private var skillSessionDraft: TrainingSessionDraft {
        TrainingSessionAdapters.draft(
            forSkillId: node.id,
            title: node.title,
            userId: AuthService.shared.currentUserId ?? "",
            plan: SkillTrainingPlanLibrary.plan(for: node.id)
        )
    }

    /// True when this skill's primary target is a static hold — the
    /// QuickLog sheet then renders a circular timer instead of a reps
    /// stepper, and hides the weight field.
    private var quickLogIsHoldBased: Bool {
        if case .hold = node.target { return true }
        return false
    }

    /// Hold target seconds derived from the node's primary requirement,
    /// or 30 if the node isn't hold-based (irrelevant in that case).
    private var quickLogHoldTargetSeconds: Int {
        if case .hold(_, let seconds) = node.target { return seconds }
        return 30
    }

    /// Default rep target for the quick-log sheet. A sane default of 5 reps.
    private var defaultRepsForQuickLog: Int {
        5
    }

    // MARK: - 1. Top nav

    private var topNav: some View {
        HStack {
            backButton
            Spacer()
            bookmarkButton
        }
    }

    private var backButton: some View {
        Button {
            UnboundHaptics.medium()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }

    private var bookmarkButton: some View {
        let isBookmarked = skillProgress.isBookmarked(nodeId: node.id)
        return Button {
            UnboundHaptics.medium()
            Task {
                await SkillProgressService.shared.toggleBookmark(nodeId: node.id)
            }
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(
                    isBookmarked ? Color.unbound.accent : Color.unbound.textSecondary
                )
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Animated hero

    /// Still-frame hero. Crossfade was nauseating to look at — replaced with
    /// a single silhouette + glow. Real motion will land later as a Seedance
    /// video clip composited under the title; the multi-step form breakdown
    /// (infographic) lives in its own section below the hero.
    private var heroBlock: some View {
        let artworkAsset = SkillTraditionalVisualResolver.assetName(for: node)
        let hasArtwork = artworkAsset.map { UIImage(named: $0) != nil } ?? false
        let tint = currentSkillIconTint
        let artworkSize: CGFloat = 208

        return ZStack {
            if !hasArtwork {
                Circle()
                    .fill(tint.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 46)

                Circle()
                    .fill(Color.unbound.bg.opacity(0.54))
                    .overlay(
                        Circle()
                            .strokeBorder(tint.opacity(0.32), lineWidth: 2)
                    )
                    .frame(width: 168, height: 168)
                    .shadow(color: Color.black.opacity(0.42), radius: 18)
            }

            if let artworkAsset, hasArtwork {
                Image(artworkAsset)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(tint)
                    .frame(width: artworkSize, height: artworkSize)
                    .shadow(color: Color.black.opacity(0.7), radius: 8)
            } else {
                Image(systemName: node.glyph)
                    .font(.system(size: 140, weight: .regular))
                    .foregroundStyle(tint)
                    .frame(width: 220, height: 220)
                    .shadow(color: tint.opacity(0.55), radius: 28)
            }
        }
        .frame(width: 220, height: 220)
        .frame(maxWidth: .infinity)
    }

    private var currentSkillIconTint: Color {
        node.isMythic ? skinService.currentSkin.impactDecalColor : skinService.currentSkin.decalColor
    }

    // MARK: - 3. Title block

    private var titleBlock: some View {
        let subtitle = "\(node.cluster.displayName) · \(rankDescription(for: node.placementRank))"
        return VStack(spacing: 8) {
            Text(node.title)
                .font(.system(.title, design: .default).weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle.uppercased())
                .font(Font.unbound.captionS.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    /// Plain-English intrinsic-difficulty label, derived from the node's fixed
    /// `placementRank` (RankTier) rather than the retired E–S bucket.
    private func rankDescription(for rank: RankTier) -> String {
        switch rank {
        case .initiate, .novice: return "Beginner"
        case .apprentice, .forged: return "Intermediate"
        case .veteran, .master: return "Advanced"
        case .vessel, .unbound: return "Elite"
        case .ascendant: return "Mythic"
        }
    }

    // MARK: - 4. Progress strip

    private var progressStrip: some View {
        // Earned-rank progress along the 9-tier RankTier ladder (replaces the
        // retired fake-XP bar). Fill = earned tier ordinal / Ascendant.
        // Feat nodes whose floor hasn't been reached have earned nothing real yet
        // (their low ranks are skipped) → empty bar, not a phantom Initiate sliver.
        let earned = userSkillTierState.tier(for: node.id)
        let fraction = node.earnedRankIsBelowFloor(earned)
            ? 0
            : max(0, min(1, Double(earned.rawValue) / Double(RankTier.ascendant.rawValue)))
        return VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surfaceElevated)
                    Capsule()
                        .fill(Color.unbound.accent)
                        .frame(width: max(0, geo.size.width * CGFloat(fraction)))
                }
            }
            .frame(height: 4)
        }
    }

    private func criterionSummary(_ criterion: TierCriterion) -> String {
        switch criterion {
        case .reps(let count, let exerciseName):
            return "\(count) \(displayExerciseName(exerciseName))"
        case .seconds(let seconds):
            return "\(seconds)-second hold"
        case .exerciseSeconds(let seconds, let exerciseName):
            return "\(seconds)s \(displayExerciseName(exerciseName)) hold"
        case .weightKg(let weight):
            return "\(Int(weight.rounded())) kg working set"
        case .exerciseWeightKg(let weight, let exerciseName):
            return "\(Int(weight.rounded())) kg \(displayExerciseName(exerciseName))"
        case .bodyweightRatio(let ratio):
            return "\(String(format: "%.2g", ratio))x bodyweight"
        case .exerciseBodyweightRatio(let ratio, let exerciseName):
            return "\(String(format: "%.2g", ratio))x bodyweight \(displayExerciseName(exerciseName))"
        case .variant(let name):
            return "Log \(displayExerciseName(name))"
        case .compound(let criteria):
            return criteria.map(criterionSummary).joined(separator: " + ")
        }
    }

    private func displayExerciseName(_ name: String) -> String {
        name
            .split(separator: " ")
            .map { part in
                part
                    .split(separator: "-")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }

    @MainActor
    private func loadReadinessHistory() async {
        readinessHistoryLoaded = false
        guard let userId = AuthService.shared.currentUserId else {
            recentExerciseHistory = []
            readinessHistoryLoaded = true
            return
        }

        let logs = (try? await SupabaseWorkoutLogService.shared.fetchRecentLogs(userId: userId, limit: 60)) ?? []
        recentExerciseHistory = logs.flatMap(\.exerciseEntries)
        readinessHistoryLoaded = true
    }

    @MainActor
    private func loadUserSkillTierState() {
        guard let userId = AuthService.shared.currentUserId else {
            userSkillTierState = .empty
            return
        }
        userSkillTierState = UserSkillTierStore.shared.load(userId: userId)
    }

    @MainActor
    private func loadBodyweight() async {
        guard let userId = AuthService.shared.currentUserId,
              let profile = try? await SupabaseUserService.shared.fetchProfile(userId: userId),
              let profileWeightKg = profile.weightKg,
              profileWeightKg > 0
        else { return }

        bodyweightKg = profileWeightKg
    }

    // MARK: - 5. Rank Path section
    //
    // Replaces the old "NEXT BEAT" card. Shows all 9 ranks for this skill
    // with their badge + criterion + clear/current/locked state. Levels
    // 1-5 in the existing data feed Novice through Master; Initiate is
    // entry; Vessel/Unbound/Ascendant remain placeholders until per-skill
    // top-tier criteria are authored (Chunk 3 of the rank redesign).

    private var rankPathSection: some View {
        let rows = rankPathRows()
        // Skipped (below-floor) rungs aren't part of a feat's journey — focus and
        // counts run over the achievable rows only.
        let achievableRows = rows.filter { !$0.isSkipped }
        let active = rows.first(where: { $0.isCurrent }) ?? achievableRows.first ?? rows.first
        let clearedCount = rows.filter(\.isCleared).count
        let achievableCount = achievableRows.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    sectionHeader("Rank Path")
                    Text("Objective gates for \(node.title)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(clearedCount)/\(achievableCount)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                    Text(readinessHistoryLoaded ? "CLEARED" : "LOADING")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            if let active {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        isRankPathExpanded.toggle()
                    }
                    UnboundHaptics.soft()
                } label: {
                    rankFocusCard(active, rows: achievableRows, clearedCount: clearedCount)
                }
                .buttonStyle(.plain)
            }

            if isRankPathExpanded {
                VStack(spacing: 0) {
                    let visibleRows = visibleRankRows(rows)
                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                        rankPathRow(row, isLast: index == visibleRows.count - 1)
                    }
                }
                .padding(.vertical, 6)
                .background(roundedCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                    )
                )
            }
        }
    }

    private struct RankPathDisplayRow: Identifiable {
        var id: SkillTier { tier }
        let tier: SkillTier
        let detail: String
        let isCleared: Bool
        let isCurrent: Bool
        let isFuture: Bool
        /// Feat node: this tier sits BELOW the floor, so it isn't part of this
        /// skill's journey (the move's first rep jumps straight to the floor).
        /// Rendered de-emphasized — present but not achievable here.
        let isSkipped: Bool
        let unlocks: [SkillUnlockStandards.OutgoingUnlock]
    }

    private var outgoingUnlocks: [SkillUnlockStandards.OutgoingUnlock] {
        SkillUnlockStandards.outgoingUnlocks(from: node.id, in: graph)
    }

    private func rankPathRows() -> [RankPathDisplayRow] {
        let tiers = SkillTier.allCases
        let floor = node.rankFloor
        // For a feat node, tiers below the floor are skipped (they share the
        // floor's entry criterion). They aren't real gates — exclude them from
        // the "current gate" search so the focus lands on the first honest rung.
        let firstUncleared = tiers.first { tier in
            if tier.rawValue < floor.rawValue { return false }
            guard let criterion = criterion(for: tier) else { return true }
            return !TierCriterionEvaluator.satisfied(
                criterion: criterion,
                history: recentExerciseHistory,
                bodyweightKg: bodyweightKg
            )
        }

        return tiers.map { tier in
            let skipped = tier.rawValue < floor.rawValue
            let criterion = criterion(for: tier)
            let cleared = !skipped && (criterion.map {
                TierCriterionEvaluator.satisfied(
                    criterion: $0,
                    history: recentExerciseHistory,
                    bodyweightKg: bodyweightKg
                )
            } ?? false)
            let current = !skipped && firstUncleared == tier
            return RankPathDisplayRow(
                tier: tier,
                detail: criterion.map(criterionSummary) ?? fallbackRankCriterion(for: tier),
                isCleared: cleared,
                isCurrent: current,
                isFuture: !skipped && !cleared && !current,
                isSkipped: skipped,
                unlocks: outgoingUnlocks.filter { $0.requirement.requiredTier == tier }
            )
        }
    }

    private func visibleRankRows(_ rows: [RankPathDisplayRow]) -> [RankPathDisplayRow] {
        // Skipped (below-floor) rungs are dropped from a feat's path — the list
        // simply starts at the floor, which reads as a high-floor skill on its own.
        rows.filter { !$0.isCurrent && !$0.isSkipped }
    }

    private func rankFocusCard(_ row: RankPathDisplayRow, rows: [RankPathDisplayRow], clearedCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                rankBadge(tier: row.tier, isCleared: row.isCleared, isCurrent: true)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.isCleared ? "Latest cleared" : "Current gate")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)
                    Text(row.tier.displayName)
                        .font(.system(.title3).weight(.bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(row.detail)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: isRankPathExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("\(clearedCount)/\(rows.count)")
                        .font(Font.unbound.monoS.weight(.heavy))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }

            rankPreviewRail(rows)

            if let plan = SkillTrainingPlanLibrary.plan(for: node.id), !row.isCleared {
                trainingChips(plan: plan, targetText: row.detail)
            }

            if !row.unlocks.isEmpty {
                unlockChips(row.unlocks, prefix: "Unlocks at \(row.tier.displayName)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.accent.opacity(0.18),
                                Color.unbound.accent.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
            }
        )
    }

    private func rankPreviewRail(_ rows: [RankPathDisplayRow]) -> some View {
        let currentIndex = rows.firstIndex(where: { $0.isCurrent }) ?? 0
        let lower = max(0, currentIndex - 2)
        let upper = min(rows.count - 1, currentIndex + 2)
        let previewRows = Array(rows[lower...upper])

        return HStack(spacing: 0) {
            ForEach(Array(previewRows.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 5) {
                    rankMiniDot(row)
                    Text(row.tier.displayName.uppercased())
                        .font(.system(size: 8, weight: row.isCurrent ? .heavy : .semibold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(row.isCurrent ? Color.unbound.accent : Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)

                if index != previewRows.count - 1 {
                    Rectangle()
                        .fill(row.isCleared ? Color.unbound.accent.opacity(0.55) : Color.unbound.border.opacity(0.6))
                        .frame(height: 1)
                        .frame(maxWidth: 24)
                        .offset(y: -10)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func rankMiniDot(_ row: RankPathDisplayRow) -> some View {
        ZStack {
            Circle()
                .fill(row.isCurrent ? Color.unbound.accent.opacity(0.22) : Color.unbound.surfaceElevated)
                .frame(width: row.isCurrent ? 24 : 18, height: row.isCurrent ? 24 : 18)
            if row.isCleared {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color.unbound.accent)
            } else if row.isCurrent {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color.unbound.textTertiary.opacity(0.45))
                    .frame(width: 6, height: 6)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(row.isCurrent ? Color.unbound.accent : Color.unbound.border, lineWidth: row.isCurrent ? 1.4 : 1)
        )
    }

    private func rankPathRow(_ row: RankPathDisplayRow, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                rankBadge(tier: row.tier, isCleared: row.isCleared, isCurrent: row.isCurrent)
                    .frame(width: 34, height: 34)
                if !isLast {
                    Rectangle()
                        .fill(row.isCleared ? Color.unbound.accent.opacity(0.45) : Color.unbound.border.opacity(0.6))
                        .frame(width: 1, height: row.isCurrent ? 44 : 28)
                        .padding(.vertical, 5)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(row.tier.displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(row.isCurrent ? Color.unbound.accent : (row.isFuture || row.isSkipped ? Color.unbound.textSecondary : Color.unbound.textPrimary))
                    statusPill(for: row)
                }

                Text(row.isSkipped ? "Skipped — this skill starts at \(node.rankFloor.displayName)" : row.detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(row.isFuture || row.isSkipped ? Color.unbound.textTertiary : Color.unbound.textSecondary)
                    .lineLimit(row.isCurrent ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if row.isCurrent, let plan = SkillTrainingPlanLibrary.plan(for: node.id) {
                    trainingChips(plan: plan, targetText: row.detail)
                        .padding(.top, 2)
                }

                if !row.unlocks.isEmpty {
                    unlockChips(row.unlocks, prefix: "Unlocks here")
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .opacity(row.isSkipped ? 0.4 : (row.isFuture ? 0.74 : 1))
    }

    private func statusPill(for row: RankPathDisplayRow) -> some View {
        let label = row.isSkipped ? "SKIPPED" : (row.isCleared ? "CLEARED" : (row.isCurrent ? "NEXT" : "LOCKED"))
        let color = (!row.isSkipped && (row.isCleared || row.isCurrent)) ? Color.unbound.accent : Color.unbound.textTertiary
        return Text(label)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    private var shouldShowUnlocksNext: Bool {
        !outgoingUnlocks.isEmpty
    }

    private var unlocksNextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Unlocks Next")

            VStack(spacing: 10) {
                ForEach(outgoingUnlocks.prefix(5)) { unlock in
                    unlockNextRow(unlock)
                }
            }

            if outgoingUnlocks.count > 5 {
                Text("+\(outgoingUnlocks.count - 5) more branches from this skill")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(roundedCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func unlockNextRow(_ unlock: SkillUnlockStandards.OutgoingUnlock) -> some View {
        let required = unlock.requirement.requiredTier
        let current = userSkillTierState.tier(for: node.id)
        let met = current >= required

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(met ? Color.unbound.accent.opacity(0.18) : Color.unbound.surfaceElevated)
                    .frame(width: 34, height: 34)
                Image(systemName: met ? "arrow.up.circle.fill" : "lock.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(unlock.child.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Unlocks when \(node.title) reaches \(required.displayName)")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(met ? "READY" : required.displayName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill((met ? Color.unbound.accent : Color.unbound.textTertiary).opacity(0.14)))
        }
    }

    private func unlockChips(_ unlocks: [SkillUnlockStandards.OutgoingUnlock], prefix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prefix)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unlocks.prefix(4)) { unlock in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .black))
                            Text(unlock.child.title)
                                .font(Font.unbound.captionS.weight(.bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.unbound.accent.opacity(0.28), lineWidth: 1))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rankBadge(tier: SkillTier, isCleared: Bool, isCurrent: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCurrent ? Color.unbound.accent.opacity(0.18) : Color.unbound.surfaceElevated)
            if let img = UIImage(named: tier.assetName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                Text(String(tier.displayName.prefix(1)))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCurrent ? Color.unbound.accent : Color.unbound.textSecondary)
            }

            if isCleared {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Color.unbound.bg)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(isCurrent ? Color.unbound.accent : Color.unbound.border, lineWidth: isCurrent ? 1.5 : 1)
        )
        .saturation(isCleared || isCurrent ? 1.0 : 0.4)
    }

    private func trainingChips(plan: SkillTrainingPlan, targetText: String) -> some View {
        let options = recommendedTrainingOptions(plan: plan, targetText: targetText)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Train this next")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.name) { option in
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(option.name)
                                .font(Font.unbound.captionS.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.unbound.surfaceElevated))
                        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func recommendedTrainingOptions(plan: SkillTrainingPlan, targetText: String) -> [TrainingExercise] {
        let normalizedTarget = targetText.lowercased()
        let candidates = plan.regressions + plan.accessories
        let matching = candidates.filter { exercise in
            let name = exercise.name.lowercased()
            let simplifiedName = name
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "pull-up", with: "pullup")
            return normalizedTarget.contains(name)
                || normalizedTarget.contains(simplifiedName)
        }
        if !matching.isEmpty { return Array(matching.prefix(3)) }
        return Array(candidates.prefix(3))
    }

    private func criterion(for tier: SkillTier) -> TierCriterion? {
        node.tierCriteria[tier]
    }

    private func fallbackRankCriterion(for tier: SkillTier) -> String {
        switch tier {
        case .initiate:
            return "Unlock and begin training this skill"
        case .novice:
            return "First clean exposure"
        case .apprentice:
            return "Build repeatable control"
        case .forged:
            return "Own the core standard"
        case .veteran:
            return "Add volume or difficulty"
        case .master:
            return "High-quality repeatability"
        case .vessel, .unbound, .ascendant:
            return "Advanced standard coming soon"
        }
    }

    // MARK: - 6. Skill guide section

    @ViewBuilder
    private var skillGuideSection: some View {
        if let guide = SkillGuideLibrary.guide(for: node.id) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        sectionHeader("Skill Guide")
                        Text("Open one layer at a time")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Spacer()
                    Text(selectedGuideTab.label.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                guideTabs

                Group {
                    switch selectedGuideTab {
                    case .form:
                        formSection(showHeader: false)
                    case .assist:
                        guideAssistanceSection(guide.assistance)
                    case .tips:
                        guideTipsSection(guide.tips)
                    case .fixes:
                        guideMistakeSection(guide.mistakes)
                    }
                }
                .animation(.easeOut(duration: 0.18), value: selectedGuideTab)
            }
        }
    }

    private var guideTabs: some View {
        HStack(spacing: 6) {
            ForEach(SkillGuideTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedGuideTab = tab
                    }
                    UnboundHaptics.soft()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .bold))
                        Text(tab.label)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selectedGuideTab == tab ? Color.unbound.bg : Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedGuideTab == tab ? Color.unbound.accent : Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selectedGuideTab == tab ? Color.clear : Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.9))
        )
    }

    private func guideAssistanceSection(_ options: [SkillGuideAssistance]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Regressions & Assistance")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(options, id: \.name) { option in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: option.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.accent)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.unbound.accent.opacity(0.14)))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.name)
                                .font(Font.unbound.bodyS.weight(.heavy))
                                .foregroundStyle(Color.unbound.textPrimary)
                            Text(option.detail)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func guideTipsSection(_ tips: [SkillGuideTip]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Technique Notes")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(tips, id: \.title) { tip in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.accent)
                                .frame(width: 22)
                            Text(tip.title)
                                .font(Font.unbound.bodyS.weight(.heavy))
                                .foregroundStyle(Color.unbound.textPrimary)
                        }

                        Text(tip.detail)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func guideMistakeSection(_ mistakes: [SkillGuideMistake]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch For")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(mistakes, id: \.mistake) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.alert)
                                .frame(width: 20)
                            Text(item.mistake)
                                .font(Font.unbound.bodyS.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.accent)
                                .frame(width: 20)
                            Text(item.fix)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 5b. Legacy Next Beat card (kept for reference; not rendered)

    private var nextBeatCard: some View {
        let isTopRank = userSkillTierState.tier(for: node.id) == .ascendant
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NEXT BEAT")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                if isTopRank {
                    topRankBadge
                }
            }

            if isTopRank {
                Text("You've proven this skill at the top rank.")
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Keep training to make progress.")
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    private var topRankBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Top Rank")
                .font(.system(.caption).weight(.semibold))
        }
        .foregroundStyle(Color.unbound.impact)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.unbound.impact.opacity(0.15)))
        .overlay(Capsule().strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 1))
    }

    // MARK: - 6. Form section

    private func formSection(showHeader: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if showHeader {
                HStack(alignment: .firstTextBaseline) {
                    sectionHeader("Form Breakdown")
                    Spacer()
                    Text("\(slideshowPhases.count) STEPS")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            if !slideshowPhases.isEmpty {
                FormPhaseSlideshow(
                    phases: slideshowPhases,
                    skillTitle: node.title
                )
            } else {
                // Fallback: numbered cue list when no per-phase silhouettes exist yet.
                fallbackStepsList
            }
        }
    }

    private func formStandardSummary(_ guide: SkillGuide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                Text("Clean Rep Standard")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.accent)
                Spacer(minLength: 0)
            }

            Text(guide.standard)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let note = guide.scoringNote {
                Text(note)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    /// Per-skill phase slideshow data. V1 hardcodes Pull-Up; future versions
    /// will move this into SkillNode authored content or a JSON resource.
    private var slideshowPhases: [FormPhase] {
        FormPhaseLibrary.phases(for: node.id, fallbackTitle: node.title, formCues: node.formCues)
    }

    /// Numbered cue list — used when no silhouette phases exist for the skill.
    private var fallbackStepsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            let steps = derivedFormSteps()
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                formStepRow(number: idx + 1, step: step, isLast: idx == steps.count - 1)
            }
        }
    }

    /// Single step row: violet circle badge with number, label + cue text,
    /// vertical connector line to the next step (omitted on last row).
    @ViewBuilder
    private func formStepRow(number: Int, step: DerivedFormStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: 28, height: 28)
                    Text("\(number)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.unbound.bg)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.unbound.accent.opacity(0.35))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                if let title = step.title {
                    Text(title.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.accent)
                }
                Text(step.cue)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer(minLength: 0)
        }
    }

    /// Local row model — V1 derives from `formCues`. Future versions will
    /// hydrate this from authored `formSteps: [FormStep]` on SkillNode or
    /// from a JSON resource extracted from the bitmap infographic.
    private struct DerivedFormStep {
        let title: String?
        let cue: String
    }

    /// Splits "TITLE — body" / "TITLE: body" patterns so cue becomes a
    /// numbered step with both a label and a body. Falls back to no title
    /// if the cue is just one phrase.
    private func derivedFormSteps() -> [DerivedFormStep] {
        node.formCues.prefix(4).map { raw -> DerivedFormStep in
            // Try to detect "TITLE — rest" or "TITLE: rest"
            let separators: [String] = [" — ", " - ", ": "]
            for sep in separators {
                if let range = raw.range(of: sep) {
                    let head = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let body = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    // Only split if the head reads as a label (short, mostly capitalizable)
                    if head.count <= 32, !body.isEmpty {
                        return DerivedFormStep(title: head, cue: body)
                    }
                }
            }
            return DerivedFormStep(title: nil, cue: raw)
        }
    }

    // MARK: - 7. Requirements (only when locked)

    private var shouldShowRequirements: Bool {
        let state = nodeStates[node.id] ?? .locked
        guard state == .locked else { return false }
        return !unlockRequirementGroups.isEmpty
    }

    private var unlockRequirementGroups: [SkillUnlockRequirementGroup] {
        SkillUnlockStandards.groups(for: node, in: graph)
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Unlock Standard")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(unlockRequirementGroups.enumerated()), id: \.element.id) { gIdx, group in
                    ForEach(group.requirements) { requirement in
                        prereqRow(requirement)
                    }
                    if gIdx < unlockRequirementGroups.count - 1 {
                        Text("or")
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func prereqRow(_ requirement: SkillUnlockRequirement) -> some View {
        let resolved = graph.node(id: requirement.sourceSkillId)
        let currentTier = userSkillTierState.tier(for: requirement.sourceSkillId)
        // A not-yet feat prereq (one-arm pull-up before its floor) has no real
        // earned rank — show "—" instead of a phantom "Initiate".
        let currentRankLabel = (resolved?.earnedRankIsBelowFloor(currentTier) ?? false)
            ? "—"
            : currentTier.displayName
        let met = SkillUnlockStandards.isSatisfied(
            requirement,
            nodeStates: nodeStates,
            tierState: userSkillTierState
        )
        HStack(spacing: 12) {
            Image(systemName: met ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(resolved?.title ?? requirement.sourceSkillId)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(met ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Reach \(requirement.requiredTier.displayName) · current \(currentRankLabel)")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
                    .lineLimit(2)
                Text(requirement.note)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 8. Sticky bottom action
    //
    // Single-CTA pattern: one big Train button that opens a chooser sheet
    // with the three options (Add Program Focus / Log a Set / Start Session).
    // Replaces the previous 3-stacked-button layout that overlapped scroll
    // content and felt heavy.

    private var stickyAction: some View {
        let isUnlocked = skillProgress.isNodeTrainable(nodeId: node.id)
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let trainTitle = isUnlocked ? (canTrain ? "Train" : "Trained Today") : "Unlock First"
        let trainIcon = isUnlocked ? (canTrain ? "dumbbell.fill" : "checkmark.seal.fill") : "lock.fill"

        return Button {
            UnboundHaptics.medium()
            presentedSheet = .trainChooser
        } label: {
            HStack(spacing: 10) {
                Image(systemName: trainIcon)
                    .font(.system(size: 16, weight: .semibold))
                Text(trainTitle)
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("skillDetail.train")
    }

    // MARK: - Train chooser sheet

    private var trainChooserSheet: some View {
        let isUnlocked = skillProgress.isNodeTrainable(nodeId: node.id)
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let isFocus = skillProgress.isProgramFocus(nodeId: node.id)
        let focusCount = skillProgress.programFocusIds.count
        let atCap = focusCount >= SkillProgressService.programFocusCap
        let focusDisabled = !isUnlocked || (atCap && !isFocus)
        let focusTitle: String = {
            if isFocus { return "Program Focus" }
            if !isUnlocked { return "Unlock Required" }
            if focusDisabled { return "Focus Limit (\(focusCount) / \(SkillProgressService.programFocusCap))" }
            return "Add Program Focus"
        }()
        let focusIcon = !isUnlocked ? "lock.fill" : (isFocus ? "checkmark.circle.fill" : "plus.circle")
        let nextProgramDay = nextProgramDayLabel()

        return VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(isUnlocked ? "TRAIN" : "LOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(isUnlocked ? Color.unbound.accent : Color.unbound.textTertiary)
                Text(node.title)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                if !isUnlocked {
                    Text(primaryUnlockSummary)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 18)
                }
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                trainOptionRow(
                    title: focusTitle,
                    subtitle: isFocus
                        ? "Active as one of your Program Focuses"
                        : (isUnlocked ? "Next focus day: \(nextProgramDay)" : "Meet the unlock standard before scheduling"),
                    icon: focusIcon,
                    isEnabled: !focusDisabled
                ) {
                    Task {
                        await SkillProgressService.shared.toggleProgramFocus(nodeId: node.id)
                        presentedSheet = nil
                    }
                }
                .accessibilityIdentifier("skillDetail.addToProgram")

                trainOptionRow(
                    title: "Log a Set",
                    subtitle: isUnlocked ? "Quick capture — reps, weight, RPE" : "Unlock this skill before logging direct work",
                    icon: isUnlocked ? "plus.circle" : "lock.fill",
                    isEnabled: isUnlocked && canTrain
                ) {
                    presentedSheet = .quickLog
                }
                .accessibilityIdentifier("skillDetail.logSet")

                trainOptionRow(
                    title: "Start Session",
                    subtitle: isUnlocked ? "Full guided workout for this skill" : "Build the prerequisites first",
                    icon: isUnlocked ? "dumbbell.fill" : "lock.fill",
                    isEnabled: isUnlocked && canTrain
                ) {
                    presentedSheet = .session
                }
                .accessibilityIdentifier("skillDetail.startSession")
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private func nextProgramDayLabel() -> String {
        guard let date = ProgramScheduler.shared.nextEligibleDate(forSkillId: node.id) else {
            return "Next matching day"
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private var primaryUnlockSummary: String {
        guard let group = unlockRequirementGroups.first,
              let requirement = group.requirements.first,
              let source = graph.node(id: requirement.sourceSkillId)
        else {
            return "Build the prerequisites before direct training."
        }
        return "Reach \(requirement.requiredTier.displayName) in \(source.title) before training this."
    }

    @ViewBuilder
    private func trainOptionRow(
        title: String,
        subtitle: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard isEnabled else { return }
            UnboundHaptics.medium()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    // MARK: - Shared styling helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline).weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
    }

    private var roundedCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }

    // MARK: - Asset lookup
}

private enum SkillDetailSheet: String, Identifiable {
    case session
    case quickLog
    case trainChooser

    var id: String { rawValue }
}
