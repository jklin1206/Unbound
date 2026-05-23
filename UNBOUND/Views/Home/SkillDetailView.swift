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

    @State private var phase: Bool = false
    @State private var isSessionPresented: Bool = false
    @State private var isFormGuidePresented: Bool = false
    @State private var isQuickLogPresented: Bool = false
    @State private var isTrainChooserPresented: Bool = false
    @State private var isRankPathExpanded: Bool = false
    @State private var recentExerciseHistory: [ExerciseLogEntry] = []
    @State private var readinessHistoryLoaded: Bool = false
    @State private var selectedGuideTab: SkillGuideTab = .form
    @State private var userSkillTierState: UserSkillTierState = .empty

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
        .sheet(isPresented: $isSessionPresented) {
            SkillSessionView(draft: skillSessionDraft)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isFormGuidePresented) {
            formGuideSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.unbound.bg)
        }
        .sheet(isPresented: $isQuickLogPresented) {
            QuickLogSheet(
                skillId: node.id,
                skillTitle: node.title,
                defaultReps: defaultRepsForQuickLog,
                isHoldBased: quickLogIsHoldBased,
                holdTargetSeconds: quickLogHoldTargetSeconds,
                skillRank: node.rank,
                nodeState: nodeStates[node.id] ?? .locked
            )
        }
        .sheet(isPresented: $isTrainChooserPresented) {
            trainChooserSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.unbound.bg)
        }
        .task(id: node.id) {
            loadUserSkillTierState()
            await loadReadinessHistory()
        }
    }

    private var skillSessionDraft: TrainingSessionDraft {
        TrainingSessionAdapters.draft(
            forSkillId: node.id,
            title: node.title,
            userId: AuthService.shared.currentUserId ?? "anonymous",
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

    /// Pull the user's current target from the next level criterion when
    /// possible — falls back to a sane default of 5 reps.
    private var defaultRepsForQuickLog: Int {
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let nextIdx = sp.currentLevel
        if node.levels.indices.contains(nextIdx) {
            // Try to extract a leading integer from the criterion (e.g. "5 strict reps")
            let criterion = node.levels[nextIdx].criterion
            let digits = criterion.prefix { $0.isNumber || $0.isWhitespace }
            let trimmed = digits.trimmingCharacters(in: .whitespaces)
            if let n = Int(trimmed), n > 0 { return n }
        }
        return 5
    }

    /// Full-bleed bitmap infographic fallback for users who want the visual
    /// reference. The native Form Breakdown above is the primary surface.
    private var formGuideSheet: some View {
        let asset = infographicAssetName(node.id)
        return ScrollView {
            VStack(spacing: 16) {
                Text(node.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.top, 24)

                if UIImage(named: asset) != nil {
                    Image(asset)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                } else {
                    Text("Full guide coming soon.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.top, 60)
                }
                Spacer(minLength: 24)
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
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
        let frame1 = iconAssetName(node.id, frame: 1)
        let hasFrame1 = UIImage(named: frame1) != nil

        return ZStack {
            Circle()
                .fill(Color.unbound.accent.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 46)

            if hasFrame1 {
                Image(frame1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.unbound.accent.opacity(0.55), radius: 28)
            } else {
                Image(systemName: node.glyph)
                    .font(.system(size: 140, weight: .regular))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.unbound.accent.opacity(0.55), radius: 28)
            }
        }
        .frame(width: 220, height: 220)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3. Title block

    private var titleBlock: some View {
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let subtitle = "\(node.cluster.displayName) · \(rankDescription(for: node.rank)) · Lv \(sp.currentLevel)"
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

    /// Plain-English label for a rank — kept from the old detail screen.
    private func rankDescription(for rank: SkillRank) -> String {
        switch rank {
        case .e: return "Starter"
        case .d: return "Beginner"
        case .c: return "Intermediate"
        case .b: return "Advanced"
        case .a: return "Elite"
        case .s: return "Mythic"
        }
    }

    // MARK: - 4. Progress strip

    private var progressStrip: some View {
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let fraction: Double = {
            guard sp.xpToNextLevel > 0 else { return 0 }
            return max(0, min(1, Double(sp.xpInLevel) / Double(sp.xpToNextLevel)))
        }()
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

    // MARK: - 5. Rank Path section
    //
    // Replaces the old "NEXT BEAT" card. Shows all 9 ranks for this skill
    // with their badge + criterion + clear/current/locked state. Levels
    // 1-5 in the existing data feed Novice through Honed; Initiate is
    // entry; Vessel/Unbound/Ascendant remain placeholders until per-skill
    // top-tier criteria are authored (Chunk 3 of the rank redesign).

    private var rankPathSection: some View {
        let rows = rankPathRows()
        let active = rows.first(where: { $0.isCurrent }) ?? rows.first
        let clearedCount = rows.filter(\.isCleared).count

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
                    Text("\(clearedCount)/\(rows.count)")
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
                    rankFocusCard(active, rows: rows, clearedCount: clearedCount)
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
        let unlocks: [SkillUnlockStandards.OutgoingUnlock]
    }

    private var outgoingUnlocks: [SkillUnlockStandards.OutgoingUnlock] {
        SkillUnlockStandards.outgoingUnlocks(from: node.id, in: graph)
    }

    private func rankPathRows() -> [RankPathDisplayRow] {
        let tiers = SkillTier.allCases
        let firstUncleared = tiers.first { tier in
            guard let criterion = criterion(for: tier) else { return true }
            return !TierCriterionEvaluator.satisfied(
                criterion: criterion,
                history: recentExerciseHistory,
                bodyweightKg: 70
            )
        }

        return tiers.map { tier in
            let criterion = criterion(for: tier)
            let cleared = criterion.map {
                TierCriterionEvaluator.satisfied(
                    criterion: $0,
                    history: recentExerciseHistory,
                    bodyweightKg: 70
                )
            } ?? false
            let current = firstUncleared == tier
            return RankPathDisplayRow(
                tier: tier,
                detail: criterion.map(criterionSummary) ?? fallbackRankCriterion(for: tier),
                isCleared: cleared,
                isCurrent: current,
                isFuture: !cleared && !current,
                unlocks: outgoingUnlocks.filter { $0.requirement.requiredTier == tier }
            )
        }
    }

    private func visibleRankRows(_ rows: [RankPathDisplayRow]) -> [RankPathDisplayRow] {
        rows.filter { !$0.isCurrent }
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
                        .foregroundStyle(row.isCurrent ? Color.unbound.accent : (row.isFuture ? Color.unbound.textSecondary : Color.unbound.textPrimary))
                    statusPill(for: row)
                }

                Text(row.detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(row.isFuture ? Color.unbound.textTertiary : Color.unbound.textSecondary)
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
        .opacity(row.isFuture ? 0.74 : 1)
    }

    private func statusPill(for row: RankPathDisplayRow) -> some View {
        let label = row.isCleared ? "CLEARED" : (row.isCurrent ? "NEXT" : "LOCKED")
        let color = row.isCleared || row.isCurrent ? Color.unbound.accent : Color.unbound.textTertiary
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
            return node.levels.first(where: { $0.level == 1 })?.criterion ?? "First clean exposure"
        case .apprentice:
            return node.levels.first(where: { $0.level == 2 })?.criterion ?? "Build repeatable control"
        case .forged:
            return node.levels.first(where: { $0.level == 3 })?.criterion ?? "Own the core standard"
        case .veteran:
            return node.levels.first(where: { $0.level == 4 })?.criterion ?? "Add volume or difficulty"
        case .honed:
            return node.levels.first(where: { $0.level == 5 })?.criterion ?? "High-quality repeatability"
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
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let state = nodeStates[node.id] ?? .locked
        let isMastered = (state == .mastered && sp.currentLevel == 5)
        // currentLevel is 1-based; node.levels is 0-indexed.
        // node.levels[currentLevel] therefore points to the NEXT level
        // (currentLevel == 1 -> levels[1] which is level 2). Lv5 capped
        // = no next beat.
        let nextIdx = sp.currentLevel
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NEXT BEAT")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                if isMastered {
                    masteredBadge
                }
            }

            if isMastered {
                Text("You've mastered this skill.")
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if node.levels.indices.contains(nextIdx) {
                Text(node.levels[nextIdx].criterion)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let last = node.levels.last {
                Text(last.criterion)
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

    private var masteredBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Mastered")
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

    /// Infographic asset name lookup — bitmap stored under SkillInfographics/<id>_info.
    private func infographicAssetName(_ id: String) -> String {
        if id == "pp.muscle-up" { return "pp_muscle-up_info_v2" }
        if id == "hs.freestanding-hs-30" { return "hs_freestanding-hs-30_info_v2" }
        if id == "cal.pseudo-planche-pushup" || id == "cal.tuck-planche-pushup" {
            return id.replacingOccurrences(of: ".", with: "_") + "_info"
        }
        let pushAssetIds: Set<String> = [
            "cal.incline-pushup",
            "cal.pushup",
            "cal.decline-pushup",
            "cal.diamond-pushup",
            "cal.sphinx-pushup",
            "cal.archer-pushup",
            "cal.one-arm-pushup",
            "cal.explosive-pushup",
            "cal.clapping-pushup",
            "cal.triple-clap-pushup",
            "cal.pike-pushup",
            "cal.elevated-pike-pushup",
            "cal.floating-pike-pushup",
            "cal.handstand-pushup",
            "cal.ninety-degree-pushup",
            "cal.clapping-handstand-pushup",
            "cal.bench-dip",
            "cal.5-dips",
            "cal.ring-dip",
            "cal.bent-arm-press"
        ]
        if pushAssetIds.contains(id) { return id.replacingOccurrences(of: ".", with: "_") + "_info" }
        return id.replacingOccurrences(of: ".", with: "_") + "_info"
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
                Text("Reach \(requirement.requiredTier.displayName) · current \(currentTier.displayName)")
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
    // with the three options (Add to Program / Log a Set / Start Session).
    // Replaces the previous 3-stacked-button layout that overlapped scroll
    // content and felt heavy.

    private var stickyAction: some View {
        let isUnlocked = skillProgress.isNodeTrainable(nodeId: node.id)
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let trainTitle = isUnlocked ? (canTrain ? "Train" : "Trained Today") : "Unlock First"
        let trainIcon = isUnlocked ? (canTrain ? "dumbbell.fill" : "checkmark.seal.fill") : "lock.fill"

        return Button {
            UnboundHaptics.medium()
            isTrainChooserPresented = true
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
        let isGoal = skillProgress.isActiveGoal(nodeId: node.id)
        let goalCount = skillProgress.activeGoalIds.count
        let atCap = goalCount >= SkillProgressService.activeGoalCap
        let goalDisabled = !isUnlocked || (atCap && !isGoal)
        let goalTitle: String = {
            if isGoal { return "In Program" }
            if !isUnlocked { return "Unlock Required" }
            if goalDisabled { return "Program Full (\(goalCount) / \(SkillProgressService.activeGoalCap))" }
            return "Add to Program"
        }()
        let goalIcon = !isUnlocked ? "lock.fill" : (isGoal ? "checkmark.circle.fill" : "plus.circle")
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
                    title: goalTitle,
                    subtitle: isGoal
                        ? "Active in your weekly program"
                        : (isUnlocked ? "Next program day: \(nextProgramDay)" : "Meet the unlock standard before scheduling"),
                    icon: goalIcon,
                    isEnabled: !goalDisabled
                ) {
                    Task {
                        await SkillProgressService.shared.toggleActiveGoal(nodeId: node.id)
                        isTrainChooserPresented = false
                    }
                }
                .accessibilityIdentifier("skillDetail.addToProgram")

                trainOptionRow(
                    title: "Log a Set",
                    subtitle: isUnlocked ? "Quick capture — reps, weight, RPE" : "Unlock this skill before logging direct work",
                    icon: isUnlocked ? "plus.circle" : "lock.fill",
                    isEnabled: isUnlocked && canTrain
                ) {
                    isTrainChooserPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isQuickLogPresented = true
                    }
                }
                .accessibilityIdentifier("skillDetail.logSet")

                trainOptionRow(
                    title: "Start Session",
                    subtitle: isUnlocked ? "Full guided workout for this skill" : "Build the prerequisites first",
                    icon: isUnlocked ? "dumbbell.fill" : "lock.fill",
                    isEnabled: isUnlocked && canTrain
                ) {
                    isTrainChooserPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isSessionPresented = true
                    }
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

    private func iconAssetName(_ id: String, frame: Int = 1) -> String {
        let safe = id.replacingOccurrences(of: ".", with: "_")
        return frame == 2 ? "\(safe)_f2" : safe
    }
}

// MARK: - SkillGuideLibrary

private struct SkillGuide {
    let standard: String
    let scoringNote: String?
    let assistance: [SkillGuideAssistance]
    var tips: [SkillGuideTip] = []
    let mistakes: [SkillGuideMistake]
}

private struct SkillGuideAssistance {
    let name: String
    let detail: String
    let icon: String
}

private struct SkillGuideTip {
    let title: String
    let detail: String
    let icon: String
}

private struct SkillGuideMistake {
    let mistake: String
    let fix: String
}

private enum SkillGuideTab: CaseIterable {
    case form
    case assist
    case tips
    case fixes

    var label: String {
        switch self {
        case .form: return "Form"
        case .assist: return "Assist"
        case .tips: return "Tips"
        case .fixes: return "Fixes"
        }
    }

    var icon: String {
        switch self {
        case .form: return "rectangle.stack.fill"
        case .assist: return "figure.strengthtraining.functional"
        case .tips: return "lightbulb.fill"
        case .fixes: return "wrench.and.screwdriver.fill"
        }
    }
}

private enum SkillGuideLibrary {
    static func guide(for skillId: String) -> SkillGuide? {
        switch skillId {
        case "pp.dead-hang":
            return SkillGuide(
                standard: "A clean dead hang starts from a secure overhand grip with arms straight, shoulders active enough to stay controlled, ribs down, legs quiet, and no twisting or swinging.",
                scoringNote: "Use this as the grip and shoulder-control root for the Pull branch. Passive hanging is useful, but skill progress should favor a controlled active hang.",
                assistance: [
                    SkillGuideAssistance(name: "Foot-Assisted Hang", detail: "Keep one or both feet lightly on a box so the shoulders and grip learn the position without taking full bodyweight immediately.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "Scapular Pull", detail: "From straight arms, pull the shoulders down away from the ears without bending the elbows. This teaches the active shoulder used before every pull.", icon: "arrow.down.to.line"),
                    SkillGuideAssistance(name: "Towel or Ring Hang", detail: "Use towels or rings only after the standard bar hang is comfortable. The extra grip demand should not make the shoulder position sloppy.", icon: "circle.grid.cross")
                ],
                tips: [
                    SkillGuideTip(title: "Own the bottom", detail: "The bottom of every pull-up is a hang. If the grip, ribs, or shoulders collapse there, the rep starts behind before it starts moving.", icon: "hand.raised.fill"),
                    SkillGuideTip(title: "Shoulders are quiet, not shrugged", detail: "Let the arms reach long, but keep enough shoulder engagement that you are not hanging from irritated soft tissue.", icon: "arrow.down.circle.fill"),
                    SkillGuideTip(title: "Stop before the grip tears apart", detail: "For training, leave a little grip in reserve. White-knuckle max hangs can wreck the next pulling session.", icon: "timer")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Shrugging into the ears.", fix: "Practice short scapular pulls and think shoulders down, neck long before adding longer hang time."),
                    SkillGuideMistake(mistake: "Swinging through the whole hold.", fix: "Start with a still body. Lightly squeeze glutes and keep legs together until the hang stops drifting."),
                    SkillGuideMistake(mistake: "Dropping suddenly at the end.", fix: "Step down or release under control. The finish should not be a fall.")
                ]
            )
        case "pp.pullup", "pp.strict-pullup", "pp.wide-pullup":
            return pullupGuide(
                title: skillId == "pp.wide-pullup" ? "wide pull-up" : (skillId == "pp.strict-pullup" ? "strict pull-up" : "pull-up"),
                grip: skillId == "pp.wide-pullup" ? "overhand grip set wider than shoulder width" : "overhand grip around shoulder width to slightly wider",
                standardDetail: skillId == "pp.wide-pullup" ? "The wider grip increases upper-back and lat demand, but the same rules apply: full extension, no kip, chin clearly over the bar, and controlled descent." : "Start from full arm extension, keep the body quiet, pull until the chin clearly clears the bar, then lower under control back to full extension.",
                extraTip: skillId == "pp.strict-pullup" ? "Strict means no hidden rhythm. If the legs or hips create the rep, it belongs in a different bucket." : nil
            )
        case "pp.chin-up", "pp.strict-chin-up":
            return pullupGuide(
                title: skillId == "pp.strict-chin-up" ? "strict chin-up" : "chin-up",
                grip: "supinated grip around shoulder width or slightly narrower",
                standardDetail: "Use the same full-extension bottom and chin-over-bar top as a pull-up. The supinated grip lets the biceps help more, but the rep still has to stay controlled.",
                extraTip: "If the wrists or elbows complain, narrow the grip or use neutral-grip work while you build tolerance."
            )
        case "pp.weighted-pullup", "pp.weighted-chin-up":
            return weightedPullGuide(isChin: skillId == "pp.weighted-chin-up")
        case "pp.explosive-pullup", "pp.clapping-pullup":
            return explosivePullGuide(isClapping: skillId == "pp.clapping-pullup")
        case "pp.archer-pullup":
            return archerPullGuide()
        case "pp.oap-negative", "pp.one-arm-pullup", "pp.heighted-chin-up", "pp.one-arm-chin-up":
            return soloArmGuide(skillId: skillId)
        case "pp.l-sit-chin-up":
            return lSitChinGuide()
        case "pp.incline-row", "pp.row", "pp.decline-row", "pp.one-arm-row", "pp.tuck-row", "pp.straddle-row", "pp.tuck-front-lever-pullup":
            return rowGuide(skillId: skillId)
        case "pp.muscle-up":
            return SkillGuide(
                standard: "A clean bar muscle-up starts from an active hang, passes through one smooth high pull and turnover, finishes with both elbows locked above the bar, and does not use a chicken-wing catch or uncontrolled bar crash.",
                scoringNote: "This regular muscle-up allows a controlled hollow-to-arch swing and hip drive. A zero-momentum false-grip rep belongs to the later strict muscle-up node.",
                assistance: [
                    SkillGuideAssistance(
                        name: "Banded Muscle-Up",
                        detail: "Loop the band on the bar and place one foot or knee in it. Use enough help to keep the rep smooth, then reduce band thickness over time. Do not rebound out of the bottom.",
                        icon: "point.3.connected.trianglepath.dotted"
                    ),
                    SkillGuideAssistance(
                        name: "Low-Bar Transition",
                        detail: "Use a low bar with feet on the floor. Pull, lean the chest over the bar, and press out while the legs supply only the minimum assistance needed.",
                        icon: "arrow.triangle.branch"
                    ),
                    SkillGuideAssistance(
                        name: "Jumping Negative",
                        detail: "Jump to the top support, lower through the dip and transition slowly, then return to the hang. This teaches the path in reverse without needing a full pull.",
                        icon: "arrow.down.forward"
                    ),
                    SkillGuideAssistance(
                        name: "Explosive Chest-to-Bar Pull-Up",
                        detail: "Build the pull height before full attempts. Aim the bar to the lower chest or upper stomach, not just chin-over-bar.",
                        icon: "arrow.up.forward"
                    ),
                    SkillGuideAssistance(
                        name: "Straight-Bar Dip",
                        detail: "Own the press-out position above a single bar. Muscle-ups often fail because the athlete can pull high but cannot press from the awkward bar-dip bottom.",
                        icon: "figure.strengthtraining.functional"
                    )
                ],
                tips: [
                    SkillGuideTip(
                        title: "False grip is a tool, not a religion",
                        detail: "A stronger false grip makes the turnover easier because the wrist starts partly above the bar. Explosive bar muscle-ups can be done with less false grip, but the more strict and slow the rep becomes, the more the false grip matters.",
                        icon: "hand.raised.fill"
                    ),
                    SkillGuideTip(
                        title: "Legs create timing, not chaos",
                        detail: "Use the legs as one connected lever. In the kip-style rep, the hollow-to-arch rhythm helps send the hips upward and the chest around the bar. Bent-knee kicking can get a rep, but it usually teaches a messy path.",
                        icon: "figure.run"
                    ),
                    SkillGuideTip(
                        title: "The pull is not a normal pull-up",
                        detail: "A pull-up goes mostly vertical. A muscle-up pull has to create height and then rotate the torso around the bar. Think pull the bar toward the lower ribs while the chest moves forward over the hands.",
                        icon: "arrow.up.and.forward"
                    ),
                    SkillGuideTip(
                        title: "Transition practice should be submaximal",
                        detail: "If every attempt is a grind, the nervous system keeps practicing panic. Use bands, a low bar, or jumping negatives so the elbows turn over together and the chest-over-hands timing stays clean.",
                        icon: "speedometer"
                    ),
                    SkillGuideTip(
                        title: "Strict muscle-up is a different standard",
                        detail: "The normal muscle-up can use controlled swing and hip drive. The strict muscle-up asks for a much quieter body, stronger false grip, higher pulling strength, and a slower transition.",
                        icon: "checkmark.seal.fill"
                    )
                ],
                mistakes: [
                    SkillGuideMistake(
                        mistake: "Pulling low and crashing into the bar.",
                        fix: "Build explosive chest-to-bar height and use a band until the bar reaches low chest or upper stomach before the turnover."
                    ),
                    SkillGuideMistake(
                        mistake: "One elbow turns over before the other.",
                        fix: "Stop max attempts. Drill low-bar transitions and banded reps where both elbows roll over together."
                    ),
                    SkillGuideMistake(
                        mistake: "Kicking the knees separately to force the rep.",
                        fix: "Return to hollow-to-arch swings and keep the legs long. If you need leg help, use one connected hip drive."
                    ),
                    SkillGuideMistake(
                        mistake: "Losing the wrist during the turnover.",
                        fix: "Practice false-grip hangs, false-grip rows, and low-bar turnovers so the hands do not need a desperate mid-air regrip."
                    ),
                    SkillGuideMistake(
                        mistake: "Pressing before the chest is over the bar.",
                        fix: "Delay the press until the torso has moved over the hands. Think pull first, lean through, then dip."
                    )
                ]
            )
        case "hs.wall-plank":
            return handstandGuide(
                standard: "A clean wall plank starts in a push-up position with the feet walked up the wall, hands shoulder-width, elbows locked, shoulders pushed tall, ribs tucked, and head between the arms. The angle can be partial, but the brace and shoulder shape must stay honest.",
                scoringNote: "Credit only controlled holds and exits. Bent elbows, collapsed shoulders, rushed wall steps, or a sagging low back stop the clock.",
                assistance: [
                    ("Box Pike Hold", "Put feet on a box and walk the hands back until the hips stack higher. This teaches shoulder loading before the wall adds fear.", "rectangle.3.group.fill"),
                    ("Partial Wall Walk", "Walk only as high as the user can keep elbows locked and ribs down. Height comes after control.", "arrow.up.right"),
                    ("Bear Hold Shoulder Shift", "Hold a bear crawl position and shift weight from hand to hand so the wrists and shoulders learn palm pressure.", "figure.strengthtraining.functional")
                ],
                tips: [
                    ("Push the floor away", "The wall plank is already handstand practice if the shoulders stay elevated and the body gets longer.", "arrow.up.circle.fill"),
                    ("Small wall steps win", "Rushing up the wall usually creates panic and a soft line. Move one foot at a time and keep breathing.", "shoeprints.fill"),
                    ("Exit is part of the rep", "Walk down with the same control used to walk up. Falling out teaches the wrong finish.", "checkmark.seal.fill")
                ],
                mistakes: [
                    ("Elbows bend as the feet climb.", "Lower the feet and shorten the hold until the arms can stay locked."),
                    ("The low back sags.", "Cue ribs in and glutes tight; use a box pike hold if the wall angle is too demanding."),
                    ("Head looks forward.", "Look between the hands so the shoulders can open and the neck stays long.")
                ]
            )
        case "hs.wall-handstand-30":
            return SkillGuide(
                standard: "A clean wall handstand is chest-to-wall, hands roughly shoulder-width, elbows locked, shoulders elevated by the ears, ribs tucked, glutes tight, legs together, and only light toe contact with the wall. The hold should keep its shape while the athlete breathes.",
                scoringNote: "Count only time spent in the stacked shape. If the low back arches hard, elbows soften, shoulders collapse, or the athlete has to hold their breath to survive, stop the clock there.",
                assistance: [
                    SkillGuideAssistance(
                        name: "Box Pike Hold",
                        detail: "Place feet on a box and walk hands back until hips stack over shoulders. This loads the wrists and shoulders without asking for a full vertical wall walk yet.",
                        icon: "rectangle.3.group.fill"
                    ),
                    SkillGuideAssistance(
                        name: "Partial Wall Walk",
                        detail: "Walk the feet only as high as you can keep ribs tucked and elbows locked. Add height before adding duration.",
                        icon: "arrow.up.right"
                    ),
                    SkillGuideAssistance(
                        name: "Back-to-Wall Hold",
                        detail: "Use it for entry confidence, not line practice. Keep ribs down and avoid learning the big banana shape that chest-to-wall work is meant to fix.",
                        icon: "square.dashed"
                    ),
                    SkillGuideAssistance(
                        name: "Wrist Prep Circuit",
                        detail: "Use wrist rocks, palm lifts, fingertip pulses, and gentle extension loading before holds so the hands can actually balance and tolerate pressure.",
                        icon: "hand.raised.fill"
                    )
                ],
                tips: [
                    SkillGuideTip(
                        title: "The wall should feel light",
                        detail: "If the toes are smashed into the wall, the body is leaning on support instead of learning a line. Walk closer, push taller, and make the wall a reference point.",
                        icon: "scope"
                    ),
                    SkillGuideTip(
                        title: "Shoulders go up, not down",
                        detail: "In a handstand, active shoulders mean pushing the floor away until the body gets longer. Collapsed shoulders make the hold feel heavier and shorten the line.",
                        icon: "arrow.up.circle.fill"
                    ),
                    SkillGuideTip(
                        title: "Breathing is the audit",
                        detail: "A position that only exists while holding air is not owned yet. Shorter holds with calm breaths beat longer holds that turn into a survival brace.",
                        icon: "lungs.fill"
                    ),
                    SkillGuideTip(
                        title: "Exit before the shape breaks",
                        detail: "Wall handstands are practice, not punishment. Step down while you still control the arms and wrists so the last rep teaches the right finish.",
                        icon: "checkmark.seal.fill"
                    )
                ],
                mistakes: [
                    SkillGuideMistake(
                        mistake: "Hands too far from the wall, body arched hard.",
                        fix: "Walk hands closer only as far as you can keep ribs down, glutes tight, and shoulders open."
                    ),
                    SkillGuideMistake(
                        mistake: "Soft elbows under fatigue.",
                        fix: "End the set when elbows start bending. Add shorter clusters instead of forcing one long hold."
                    ),
                    SkillGuideMistake(
                        mistake: "Head pokes forward to stare at the floor.",
                        fix: "Look between the hands and keep the ears framed by the arms so the shoulders can open."
                    ),
                    SkillGuideMistake(
                        mistake: "The wall walk becomes a frantic scramble.",
                        fix: "Use partial wall walks and controlled step-downs until each hand step is deliberate."
                    )
                ]
            )
        case "hs.headstand":
            return handstandGuide(
                standard: "A clean headstand uses a stable tripod: hands and head form a triangle, palms press the floor, neck stays long, elbows stay controlled, and the legs rise slowly from tuck to vertical without kicking.",
                scoringNote: "Count only quiet holds with weight shared through the hands. No credit for neck compression, rolling, elbow flare, or a jump into the wall.",
                assistance: [
                    ("Tripod Knee Shelf", "Place knees on the upper arms and practice lifting one foot at a time before extending the legs.", "triangle.fill"),
                    ("Tuck Headstand", "Hold a compact tuck with hips over the base before trying full vertical legs.", "arrow.up.and.down"),
                    ("Wall-Supported Headstand", "Use the wall as a safety target while keeping most balance through the hands and shoulders.", "rectangle.portrait")
                ],
                tips: [
                    ("Hands protect the neck", "Press the palms down and keep the shoulders active so the head is not carrying the whole hold.", "hand.raised.fill"),
                    ("Lift slowly", "A headstand should float up from a tuck. Kicking turns it into a roll waiting to happen.", "tortoise.fill"),
                    ("Triangle first", "If the base is too narrow or too wide, balance gets noisy before the legs even move.", "triangle")
                ],
                mistakes: [
                    ("Too much weight dumps into the head.", "Return to tripod knee shelves and push harder through the palms."),
                    ("Legs kick up fast.", "Use tuck progressions and extend one leg at a time."),
                    ("Elbows flare out.", "Reset hand width and grip the floor before lifting.")
                ]
            )
        case "hs.freestanding-hs-30":
            return SkillGuide(
                standard: "A clean freestanding handstand starts from a controlled entry, stacks hands, shoulders, hips, and ankles, keeps elbows locked and shoulders active, balances mainly through finger and palm pressure, breathes normally, and exits intentionally instead of falling out.",
                scoringNote: "For the 30-second node, do not count walking saves, big banana-back holds, repeated leg scissoring, or time spent collapsing into a bailout. The standard is a repeatable balance, not a lucky fight.",
                assistance: [
                    SkillGuideAssistance(
                        name: "Chest-to-Wall Line Hold",
                        detail: "Use the wall to rehearse the exact body line: hands close enough to stack, shoulders tall, ribs down, glutes on, toes light.",
                        icon: "rectangle.portrait"
                    ),
                    SkillGuideAssistance(
                        name: "Heel Pull",
                        detail: "Start chest-to-wall, gently pull one heel then both heels off the wall, and let the fingers catch overbalance before returning lightly to the wall.",
                        icon: "arrow.left.and.right"
                    ),
                    SkillGuideAssistance(
                        name: "Toe Pull",
                        detail: "From back-to-wall, peel the toes away and find the balance point without kicking through it. This teaches underbalance recovery.",
                        icon: "arrow.up.backward"
                    ),
                    SkillGuideAssistance(
                        name: "Controlled Kick-Up",
                        detail: "Kick with one long lever and stop at the balance point. If every attempt slams past vertical, reduce kick height and use the wall as a quiet target.",
                        icon: "figure.run"
                    ),
                    SkillGuideAssistance(
                        name: "Cartwheel Bail",
                        detail: "Practice turning one hand out and stepping down sideways before max attempts. Confidence with the exit keeps the entry from becoming timid.",
                        icon: "arrow.uturn.down"
                    )
                ],
                tips: [
                    SkillGuideTip(
                        title: "Fingers are the brakes",
                        detail: "When the body tips past vertical, press the fingertips into the floor. When it falls short, shift pressure toward the heel of the hand and reach taller through the shoulders.",
                        icon: "hand.tap.fill"
                    ),
                    SkillGuideTip(
                        title: "Stack first, then hold",
                        detail: "A handstand that begins bent usually stays bent. Spend attempts arriving in the line before worrying about how many seconds you can wrestle out of it.",
                        icon: "line.diagonal"
                    ),
                    SkillGuideTip(
                        title: "The ribs decide the shape",
                        detail: "Ribs down and glutes on put the pelvis under you. If the ribs flare, the legs drift behind and the handstand becomes a heavy banana.",
                        icon: "shield.lefthalf.filled"
                    ),
                    SkillGuideTip(
                        title: "Train quality before fatigue",
                        detail: "Freestanding balance is nervous-system practice. Stop before the shoulders are so tired that every attempt becomes a different skill.",
                        icon: "speedometer"
                    ),
                    SkillGuideTip(
                        title: "Use the wall as a lab",
                        detail: "Heel pulls and toe pulls teach the same hand-pressure corrections you need away from the wall, but with fewer dramatic exits.",
                        icon: "testtube.2"
                    )
                ],
                mistakes: [
                    SkillGuideMistake(
                        mistake: "Kicking past vertical and hoping to save it.",
                        fix: "Lower the kick, aim for a quieter arrival, and use back-to-wall toe pulls to learn the balance point."
                    ),
                    SkillGuideMistake(
                        mistake: "Balancing with big shoulder waves.",
                        fix: "Return to wall heel pulls and practice fingertip pressure as the first correction."
                    ),
                    SkillGuideMistake(
                        mistake: "Banana back becomes the default hold.",
                        fix: "Rebuild chest-to-wall line holds with ribs down, glutes on, and shoulders elevated before free attempts."
                    ),
                    SkillGuideMistake(
                        mistake: "Legs split and bicycle to keep the hold alive.",
                        fix: "Use shorter holds with legs together. Count only the seconds where the lower body stays quiet."
                    ),
                    SkillGuideMistake(
                        mistake: "Fear of falling blocks commitment.",
                        fix: "Practice cartwheel bails separately until stepping out is automatic, then bring that confidence back to kick-ups."
                    )
                ]
            )
        case "hs.tuck-handstand":
            return handstandGuide(
                standard: "A clean tuck handstand keeps hands, locked elbows, and elevated shoulders stacked while the knees draw toward the chest. The hips stay over the hands and the tuck shape is balanced, not collapsed behind the wrists.",
                scoringNote: "Credit only holds where the shoulder stack survives the leg change. Bent elbows, hips dropping behind the hands, or wall collapse do not count as clean tuck time.",
                assistance: [
                    ("Wall Tuck Hold", "From a wall handstand, bend the knees and pull them in only as far as the shoulders stay tall.", "rectangle.portrait"),
                    ("Box Tuck Handstand", "Use a box to support the feet while practicing hips high over hands.", "rectangle.3.group.fill"),
                    ("Tuck Negative", "Lower from a wall line into tuck slowly, then re-extend or step down.", "arrow.down.forward")
                ],
                tips: [
                    ("Press before you tuck", "Set the shoulder push first. Moving the legs before the shoulders are tall makes the hips drop.", "arrow.up.circle.fill"),
                    ("Hips stay high", "Think knees light, hips over hands. The tuck is still a handstand, not a squat on the arms.", "scope"),
                    ("Use it as press prep", "Tuck handstand teaches the compression and hip path needed for tuck press work.", "link")
                ],
                mistakes: [
                    ("Knees pull in and shoulders sink.", "Use a smaller tuck range and rebuild shoulder elevation."),
                    ("Elbows bend to save balance.", "Return to wall tuck negatives and straight-arm support drills."),
                    ("Head pokes forward.", "Look between the hands and keep ears framed by the arms.")
                ]
            )
        case "hs.tuck-press", "hs.straddle-press", "hs.press-to-handstand":
            return pressHandstandGuide(skillId: skillId)
        case "hs.wall-supported-oah":
            return oneArmHandstandGuide(wallSupported: true, full: false)
        case "oah.one-arm-handstand-5s":
            return oneArmHandstandGuide(wallSupported: false, full: false)
        case "oah.full-one-arm-handstand":
            return oneArmHandstandGuide(wallSupported: false, full: true)
        case "pp.ring-muscle-up":
            return ringMuscleUpGuide()
        case "pp.strict-muscle-up":
            return strictMuscleUpGuide()
        case "cal.plank-30":
            return forearmPlankGuide()
        case "cl.hollow-body-30":
            return hollowBodyGuide()
        case "cl.crunch", "cl.reverse-crunch", "cl.levitation-crunch", "cl.inverted-situp", "cl.decline-situp":
            return coreFlexionGuide(skillId: skillId)
        case "cl.bird-dog-plank", "cl.superman-plank", "cl.extended-plank":
            return plankControlGuide(skillId: skillId)
        case "cl.knee-ab-rollout", "cl.standing-ab-rollout":
            return rolloutGuide(skillId: skillId)
        case "cl.knee-raise", "cl.leg-raise", "cl.hanging-knee-raise", "cl.hanging-leg-raise", "cl.toes-to-bar":
            return coreRaiseGuide(skillId: skillId)
        case "cal.l-sit-10", "cl.semi-straddle-l-sit", "cl.straddle-l-sit", "cl.v-sit", "cl.vertical-l-sit":
            return lSitFamilyGuide(skillId: skillId)
        case "cl.tuck-front-lever", "cl.straddle-front-lever", "cl.full-front-lever":
            return frontLeverGuide(skillId: skillId)
        case "cl.german-hang", "cl.skin-the-cat", "cl.straddle-back-lever", "cl.full-back-lever":
            return backLeverGuide(skillId: skillId)
        case "cl.three-sixty-pulls":
            return threeSixtyPullGuide()
        case "cl.dragon-flag-hip-raise", "cl.dragon-flag":
            return dragonFlagGuide(skillId: skillId)
        case "hs.crow-pose", "hs.crane-pose", "hs.flying-crow":
            return crowFamilyGuide(skillId: skillId)
        case "hs.elbow-lever", "hs.one-arm-elbow-lever":
            return elbowLeverGuide(isOneArm: skillId == "hs.one-arm-elbow-lever")
        case "cal.incline-pushup", "cal.pushup", "cal.decline-pushup":
            return pushupGuide(skillId: skillId)
        case "cal.diamond-pushup", "cal.sphinx-pushup":
            return closePushGuide(skillId: skillId)
        case "cal.5-dips", "cal.bench-dip":
            return dipGuide(skillId: skillId)
        case "cal.ring-dip":
            return ringDipGuide()
        case "cal.pike-pushup", "cal.elevated-pike-pushup", "cal.floating-pike-pushup":
            return pikePushGuide(skillId: skillId)
        case "cal.handstand-pushup":
            return handstandPushGuide()
        case "cal.ninety-degree-pushup":
            return ninetyDegreePushGuide()
        case "cal.clapping-handstand-pushup":
            return clappingHandstandPushGuide()
        case "cal.pseudo-planche-pushup", "cal.tuck-planche-pushup":
            return planchePushGuide(skillId: skillId)
        case "pl.tuck-planche", "pl.straddle-planche", "pl.half-lay-planche", "pl.full-planche", "pl.bent-arm-planche":
            return plancheHoldGuide(skillId: skillId)
        case "cal.archer-pushup", "cal.one-arm-pushup":
            return unilateralPushGuide(skillId: skillId)
        case "cal.explosive-pushup", "cal.clapping-pushup", "cal.triple-clap-pushup":
            return explosivePushGuide(skillId: skillId)
        case "cal.bent-arm-press":
            return bentArmPressGuide()
        case let id where id.hasPrefix("ld."):
            return legGuide(skillId: id)
        case let id where id.hasPrefix("co."):
            return conditioningGuide(skillId: id)
        default:
            return nil
        }
    }

    private static func handstandGuide(
        standard: String,
        scoringNote: String,
        assistance: [(String, String, String)],
        tips: [(String, String, String)],
        mistakes: [(String, String)]
    ) -> SkillGuide {
        SkillGuide(
            standard: standard,
            scoringNote: scoringNote,
            assistance: assistance.map { SkillGuideAssistance(name: $0.0, detail: $0.1, icon: $0.2) },
            tips: tips.map { SkillGuideTip(title: $0.0, detail: $0.1, icon: $0.2) },
            mistakes: mistakes.map { SkillGuideMistake(mistake: $0.0, fix: $0.1) }
        )
    }

    private static func pressHandstandGuide(skillId: String) -> SkillGuide {
        let isTuck = skillId == "hs.tuck-press"
        let isStraddle = skillId == "hs.straddle-press"
        let standard = isTuck
            ? "A clean tuck press shifts shoulders past wrists, keeps arms straight, compresses knees tightly, floats the feet without a jump, then lifts hips over hands into a controlled tuck handstand or full handstand finish."
            : (isStraddle
                ? "A clean straddle press starts from a folded straddle shape, leans shoulders over the hands, lifts the feet without momentum, keeps legs wide while the hips rise, then closes the legs only after the handstand is stacked."
                : "A clean press to handstand is a momentum-free straight-arm entry. Hands root into the floor, shoulders elevate, legs compress toward the torso, hips travel over the wrists, and the rep finishes in a stable handstand.")

        return handstandGuide(
            standard: standard,
            scoringNote: "Count only presses with no hop or kick. Bent elbows, shoulder collapse, feet leaving from momentum, or an uncontrolled top position move the work back to regressions.",
            assistance: [
                ("Elevated Hands", "Use blocks or parallettes to reduce compression demand while keeping the same straight-arm press path.", "square.stack.3d.up.fill"),
                ("Wall Negative", "Lower from a wall handstand through the press shape slowly. Negatives teach the path without needing the full lift yet.", "arrow.down.forward"),
                (isTuck ? "Crow to Tuck Float" : "Compression Lift", isTuck ? "Float from crow-style compression into a small tuck so the feet learn to leave quietly." : "Lift the heels from a pike or straddle fold to build active compression.", "arrow.up.circle.fill")
            ],
            tips: [
                ("Press down to go up", "The floor push and shoulder elevation are what let the hips rise. Do not think about yanking the legs first.", "hand.raised.fill"),
                ("Lean is required", "The shoulders must move forward enough for the hips to pass over the wrists. Fear of lean usually turns into a hop.", "arrow.forward.circle.fill"),
                ("Shape decides difficulty", isStraddle ? "Keep the legs wide until the hips are stacked; closing early makes the lever heavier." : "The tighter the compression, the less brute strength the press demands.", "scope")
            ],
            mistakes: [
                ("The feet jump off the floor.", "Use slow negatives and elevated hands until the feet can float quietly."),
                ("Elbows bend during the lift.", "Regress to straight-arm lean holds and shorten the range."),
                ("The top handstand is unstable.", "Finish toward a wall target and pause before counting the rep.")
            ]
        )
    }

    private static func oneArmHandstandGuide(wallSupported: Bool, full: Bool) -> SkillGuide {
        let standard = wallSupported
            ? "A clean wall-supported one-arm handstand starts from a tight wall handstand, opens the legs enough to manage balance, shifts weight into one straight working arm, keeps that shoulder elevated by the ear, and reduces the free hand to light fingertips or a brief hover."
            : (full
                ? "A clean full one-arm handstand is a freestanding one-hand balance with straight support arm, elevated shoulder, active hand, controlled straddle or full line, hips centered over the support hand, steady breath, and an intentional exit."
                : "A clean one-arm handstand starts from a stable freestanding straddle handstand, shifts weight into one straight support arm, keeps the support shoulder tall, lifts the free hand, and balances with active fingers, wrist, shoulder, and small hip corrections.")
        return handstandGuide(
            standard: standard,
            scoringNote: wallSupported
                ? "For the assisted standard, count only time where the working arm carries the load and the free hand is visibly light. Heavy leaning into the wall or a sinking shoulder does not count."
                : "Count only quiet holds. Bent support arm, shoulder collapse, major walking, leg chaos, or an uncontrolled fall means the attempt is not clean.",
            assistance: [
                ("Two-Hand Wall Line", "Own a tall two-hand handstand first: ribs controlled, shoulders elevated, and hands active.", "rectangle.portrait"),
                ("Weight Shifts", "Move weight side to side before lifting the hand. The working shoulder stays tall rather than dumping sideways.", "arrow.left.and.right"),
                ("Fingertip Support", "Reduce the free hand from full palm to fingertips to one finger before hovering.", "hand.point.up.left.fill")
            ],
            tips: [
                ("Push tall before lifting", "The free hand comes off only after the working shoulder has already taken the stack.", "arrow.up.circle.fill"),
                ("Straddle gives time", "Opening the legs gives more balance options while the hand and shoulder learn the new center.", "figure.flexibility"),
                ("The hand is still steering", "Finger pressure and heel-of-hand pressure stay active. One-arm balance is not passive stacking.", "hand.tap.fill")
            ],
            mistakes: [
                ("The working shoulder sinks.", "Return to wall shifts and one-arm shoulder-elevation holds."),
                ("The free hand is secretly heavy.", "Use fewer fingers and shorter holds instead of pretending the shift is complete."),
                ("The hips dump sideways.", "Think shoulder tall first, then move the hips only enough to center over the hand.")
            ]
        )
    }

    private static func hollowBodyGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean hollow body hold keeps the low back sealed to the floor, ribs pulled down toward the pelvis, shoulders lifted, arms and legs long, and breathing controlled without losing posterior pelvic tilt.",
            scoringNote: "The set ends the moment the low back arches. Shorter clean holds beat longer holds that turn into hip-flexor leg lifts.",
            assistance: [
                SkillGuideAssistance(name: "Bent-Knee Hollow", detail: "Keep knees bent and arms by the sides until the pelvis can stay tucked with normal breathing.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Dead Bug", detail: "Alternate arm and leg reaches while the low back stays down. This teaches the same brace with less lever length.", icon: "arrow.up.left.and.arrow.down.right"),
                SkillGuideAssistance(name: "One-Leg Lower", detail: "Lower one leg at a time only as far as the spine stays glued to the floor.", icon: "arrow.down")
            ],
            tips: [
                SkillGuideTip(title: "Ribs meet hips", detail: "Think of shortening the front of the torso before lifting the limbs. The hollow is a trunk shape first, not a leg height contest.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Reach long after you brace", detail: "Arms overhead and low legs are progressions. Earn them by keeping the same pelvis position.", icon: "arrow.up.left.and.arrow.down.right"),
                SkillGuideTip(title: "Use it everywhere", detail: "Front lever, toes-to-bar, dragon flag, handstand work, and muscle-up swing all borrow this ribs-down body line.", icon: "link")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Low back lifts off the floor.", fix: "Bend knees, bring arms forward, or shorten the set until lumbar contact stays unbroken."),
                SkillGuideMistake(mistake: "Holding the breath.", fix: "Use easier leverage and breathe behind the brace. If breathing breaks the shape, the shape is too hard."),
                SkillGuideMistake(mistake: "Chasing low legs too early.", fix: "Keep legs higher or tucked until the pelvis stays posteriorly tilted.")
            ]
        )
    }

    private static func forearmPlankGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean forearm plank holds a straight line from head to heels with elbows under shoulders, forearms rooted, ribs down, glutes and quads lightly squeezed, and steady breathing for the full target time.",
            scoringNote: "The timer stops when the low back sags, hips pike, shoulders collapse, elbows drift forward, or the athlete has to hold breath to survive.",
            assistance: [
                SkillGuideAssistance(name: "Knee Plank", detail: "Drop to the knees while keeping the same ribs-down trunk line. Build clean time before returning to full legs.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Incline Forearm Plank", detail: "Raise the forearms on a bench or box to reduce the anti-extension load while preserving the plank shape.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Short Hold Clusters", detail: "Use repeated 5-15 second holds with clean exits instead of one long sagging hold.", icon: "timer")
            ],
            tips: [
                SkillGuideTip(title: "Push the floor away", detail: "Root the forearms and gently spread the shoulder blades so the upper back does not sink.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Zip ribs to hips", detail: "A slight posterior pelvic tuck keeps the low back from arching. The plank should feel like a hollow body turned face down.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Breathe behind the brace", detail: "Quiet nasal or controlled mouth breaths prove the position is owned, not just tolerated.", icon: "lungs.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Low back sags.", fix: "Squeeze glutes, tuck ribs down, widen feet, or regress to knees."),
                SkillGuideMistake(mistake: "Hips pike too high.", fix: "Lower hips until shoulders, ribs, and pelvis form one line."),
                SkillGuideMistake(mistake: "Neck cranes forward.", fix: "Look slightly ahead of the hands and keep the back of the neck long.")
            ]
        )
    }

    private static func coreFlexionGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "cl.reverse-crunch":
            return SkillGuide(
                standard: "A clean reverse crunch starts with knees bent around tabletop, ribs down, and shoulders grounded. The pelvis curls toward the rib cage so the tailbone peels up, then returns slowly without leg swing.",
                scoringNote: "The rep is small by design. Throwing knees toward the face, rocking onto the shoulders, or arching on the return turns it into momentum.",
                assistance: [
                    SkillGuideAssistance(name: "Hands Pressed Down", detail: "Press the floor lightly for stability while learning the pelvic curl.", icon: "hand.raised.fill"),
                    SkillGuideAssistance(name: "Smaller Curl", detail: "Lift only the tailbone at first. Add range after the pelvis moves without a swing.", icon: "slider.horizontal.3"),
                    SkillGuideAssistance(name: "Foot Tap Reset", detail: "Tap feet down between reps to remove momentum before the next curl.", icon: "shoeprints.fill")
                ],
                tips: [
                    SkillGuideTip(title: "Curl the pelvis", detail: "Think tailbone toward ribs, not knees to face. The pelvis movement is what makes it abdominal work.", icon: "arrow.up.circle.fill"),
                    SkillGuideTip(title: "Make it small and heavy", detail: "A controlled inch of pelvic curl beats a big swing that rolls the whole body.", icon: "scope"),
                    SkillGuideTip(title: "Lower without reload", detail: "Return slowly enough that the legs do not swing into the next rep.", icon: "metronome")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Legs kick for momentum.", fix: "Bend knees tighter, use smaller range, and pause between reps."),
                    SkillGuideMistake(mistake: "Rocking onto shoulders.", fix: "Keep mid-back grounded and stop at a small tailbone lift."),
                    SkillGuideMistake(mistake: "Low back arches on the return.", fix: "Reset ribs down before lowering the feet or knees.")
                ]
            )
        case "cl.levitation-crunch":
            return SkillGuide(
                standard: "A clean levitation crunch starts in a hollow hover with low back pressed down, shoulders and legs off the floor, folds ribs and knees toward center, then reopens to a quiet hover without touching down.",
                scoringNote: "Count only reps where the hollow survives both directions. If the low back pops off the floor, shorten the lever or rest between reps.",
                assistance: [
                    SkillGuideAssistance(name: "Bent-Knee Hollow", detail: "Hold a short hollow with knees bent before adding the crunch motion.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Arms Forward", detail: "Reach arms toward the feet instead of overhead to reduce lever length.", icon: "arrow.forward"),
                    SkillGuideAssistance(name: "One-Leg Extension", detail: "Extend one leg at a time while the spine stays sealed down.", icon: "arrow.left.and.right")
                ],
                tips: [
                    SkillGuideTip(title: "Own hollow first", detail: "The crunch starts from a stable hollow. If the setup leaks, the rep has nowhere clean to go.", icon: "circle.hexagongrid.fill"),
                    SkillGuideTip(title: "Fold from both ends", detail: "Ribs and knees travel toward each other; do not yank only with the neck or only with the legs.", icon: "rectangle.compress.vertical"),
                    SkillGuideTip(title: "Return to a hover", detail: "The last inch matters. Reopen quietly instead of dropping shoulders or heels.", icon: "pause.circle.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Low back leaves the floor.", fix: "Bend knees, raise legs higher, or bring arms forward."),
                    SkillGuideMistake(mistake: "Neck strains forward.", fix: "Keep chin softly tucked and lift from the ribs."),
                    SkillGuideMistake(mistake: "Turns into a loose V-up.", fix: "Slow down and finish each rep in a controlled hollow hover.")
                ]
            )
        case "cl.inverted-situp":
            return SkillGuide(
                standard: "A clean inverted sit-up starts from a secure inverted hook or hang, braces first, curls the trunk toward the legs or bar without swing, then lowers under control while the anchor stays locked.",
                scoringNote: "Safety owns the standard. Do not count reps where the hook slips, the body swings, or the athlete overextends at the bottom.",
                assistance: [
                    SkillGuideAssistance(name: "Decline Sit-Up", detail: "Build the same trunk flexion on a stable bench before going inverted.", icon: "rectangle.inset.filled"),
                    SkillGuideAssistance(name: "Inverted Hold", detail: "Practice only the secure upside-down anchor and calm breathing before adding reps.", icon: "figure.gymnastics"),
                    SkillGuideAssistance(name: "Partial Curl", detail: "Use a small range or spotter support until the anchor and descent are reliable.", icon: "slider.horizontal.3")
                ],
                tips: [
                    SkillGuideTip(title: "Secure first", detail: "The hook, grip, or leg anchor must feel boring before the first rep starts.", icon: "lock.fill"),
                    SkillGuideTip(title: "Curl, do not swing", detail: "Move like a strict crunch upside down. Momentum makes the setup less safe and less useful.", icon: "metronome"),
                    SkillGuideTip(title: "Lower with brakes", detail: "The descent should not whip the spine or shift the anchor.", icon: "arrow.down.circle.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Swinging for height.", fix: "Return to decline work or partial inverted curls."),
                    SkillGuideMistake(mistake: "Anchor shifts mid-rep.", fix: "Stop immediately and rebuild the setup before loading reps."),
                    SkillGuideMistake(mistake: "Overextending at the bottom.", fix: "Stop the descent where ribs and pelvis can stay controlled.")
                ]
            )
        case "cl.decline-situp":
            return SkillGuide(
                standard: "A clean decline sit-up uses a modest bench angle, secured feet, bent knees, and controlled spinal flexion. Curl up before sitting tall, then lower slowly without flopping or arching.",
                scoringNote: "Steeper is not better if control vanishes. Add decline, range, and load only after flat sit-ups and crunches stay clean.",
                assistance: [
                    SkillGuideAssistance(name: "Flat Crunch", detail: "Use small rib-to-pelvis curls until neck and hip-flexor cheating disappear.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Low Decline", detail: "Start at the lowest useful angle and increase only when the lower stays controlled.", icon: "slider.horizontal.3"),
                    SkillGuideAssistance(name: "Arms Forward", detail: "Reach arms forward to reduce leverage before using hands behind head or added load.", icon: "arrow.forward")
                ],
                tips: [
                    SkillGuideTip(title: "Curl before sit", detail: "Start by rolling ribs toward pelvis. Sitting up without the curl shifts the work into hip flexors.", icon: "rectangle.compress.vertical"),
                    SkillGuideTip(title: "Ribs down on the way back", detail: "The lower should stay braced instead of turning into a backward flop.", icon: "arrow.down"),
                    SkillGuideTip(title: "Earn load last", detail: "Weight belongs after angle, range, and tempo are all repeatable.", icon: "scalemass.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Bench angle too steep.", fix: "Lower the decline until the whole rep can be controlled."),
                    SkillGuideMistake(mistake: "Yanking the head.", fix: "Move hands across chest or support the head lightly without pulling."),
                    SkillGuideMistake(mistake: "Flopping into lumbar extension.", fix: "Slow the eccentric and stop before the brace disappears.")
                ]
            )
        default:
            return SkillGuide(
                standard: "A clean crunch starts supine with knees bent and feet planted, then curls the upper back off the floor by drawing ribs toward pelvis. The neck stays relaxed, low back controlled, and the lower is slow.",
                scoringNote: "This is a small spinal-flexion rep. Pulling the head, throwing the arms, or turning it into a hip-flexor sit-up does not count.",
                assistance: [
                    SkillGuideAssistance(name: "Hands Across Chest", detail: "Remove the temptation to pull the neck while learning the rib curl.", icon: "xmark"),
                    SkillGuideAssistance(name: "Small Curl", detail: "Lift only the shoulder blades at first. Range grows after the neck stays quiet.", icon: "slider.horizontal.3"),
                    SkillGuideAssistance(name: "Feet Supported", detail: "Place feet on a bench if it helps keep the pelvis and low back quiet.", icon: "rectangle.inset.filled")
                ],
                tips: [
                    SkillGuideTip(title: "Ribs to pelvis", detail: "Do not chase head to knees. The useful motion is the ribs shortening toward the hips.", icon: "rectangle.compress.vertical"),
                    SkillGuideTip(title: "Exhale to lift", detail: "A smooth exhale helps the ribs soften down before the curl.", icon: "wind"),
                    SkillGuideTip(title: "Hands only support", detail: "If hands are behind the head, they cradle. They do not pull.", icon: "hand.raised.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Pulling on the neck.", fix: "Move hands to chest and keep chin softly tucked."),
                    SkillGuideMistake(mistake: "Feet lift or hips rock.", fix: "Use a smaller curl and slow the tempo."),
                    SkillGuideMistake(mistake: "Rushing the lower.", fix: "Uncurl slowly until shoulder blades touch down.")
                ]
            )
        }
    }

    private static func plankControlGuide(skillId: String) -> SkillGuide {
        let name = skillId == "cl.bird-dog-plank" ? "bird dog plank" : (skillId == "cl.superman-plank" ? "superman plank" : "extended plank")
        return SkillGuide(
            standard: "A clean \(name) keeps ribs stacked over pelvis, glutes lightly squeezed, shoulders active, and the spine quiet while the lever changes. The body should not sag, pike, twist, or shrug.",
            scoringNote: "Anti-rotation is the point. If the hips roll or the shoulder line opens, shorten the hold or use an easier plank variation.",
            assistance: [
                SkillGuideAssistance(name: "Incline Plank", detail: "Raise the hands until the trunk can stay stacked without low-back sag.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Quadruped Reach", detail: "Practice opposite arm and leg reaches from hands and knees before loading the full plank.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Short Holds", detail: "Use 5-10 second perfect holds per side instead of one long collapse.", icon: "timer")
            ],
            tips: [
                SkillGuideTip(title: "Move limbs without moving spine", detail: "The best rep looks boring from the trunk. Only the arm or leg changes.", icon: "scope"),
                SkillGuideTip(title: "Push the floor away", detail: "Active shoulders keep the upper back from sinking and make the brace easier to keep.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Hips tell the truth", detail: "A small hip hike usually means the anti-rotation demand is winning. Regress before adding time.", icon: "line.diagonal")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips sag under fatigue.", fix: "Shorten the lever, raise the hands, or stop the set earlier."),
                SkillGuideMistake(mistake: "Free leg lifts too high.", fix: "Keep the leg near hip height so the trunk does not arch and rotate."),
                SkillGuideMistake(mistake: "Shoulders rotate open.", fix: "Press evenly through the support hand and reduce reach distance.")
            ]
        )
    }

    private static func rolloutGuide(skillId: String) -> SkillGuide {
        let standing = skillId == "cl.standing-ab-rollout"
        return SkillGuide(
            standard: standing
                ? "A clean standing ab rollout starts from standing with a braced hinge to the wheel, rolls forward through a hollow body line, reaches only the range the spine can control, then returns without hip snapping or lumbar sag."
                : "A clean knee ab rollout starts kneeling with the wheel under shoulders, ribs down, glutes on, and arms long. Roll forward only as far as the hollow shape survives, then pull back without bending the elbows to escape.",
            scoringNote: "Rollouts are anti-extension. The rep ends when the low back arches, shoulders collapse, elbows bend to shorten the lever, or the return becomes a hip pike.",
            assistance: [
                SkillGuideAssistance(name: standing ? "Wall-Stop Standing Rollout" : "Wall-Stop Rollout", detail: "Use a wall as a hard range limit so the body learns a clean endpoint before max range.", icon: "rectangle.portrait"),
                SkillGuideAssistance(name: standing ? "Knee Rollout" : "Short Range Rollout", detail: standing ? "Own strict knee rollouts before standing range." : "Use a shorter rollout and gradually move the wall farther away.", icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Elevated Rollout", detail: "Roll to a bench, barbell, or box to reduce the lever while keeping the same brace.", icon: "arrow.up.to.line")
            ],
            tips: [
                SkillGuideTip(title: "Hollow before motion", detail: "Set ribs down and glutes on before the wheel moves. The spine position is the skill.", icon: "circle.hexagongrid.fill"),
                SkillGuideTip(title: "Stop before the arch", detail: "The clean endpoint is one inch before the low back wants to sag.", icon: "exclamationmark.triangle.fill"),
                SkillGuideTip(title: "Pull back with abs and lats", detail: "Return by keeping the body long and drawing the wheel back, not by folding the hips first.", icon: "arrow.backward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Low back arches near end range.", fix: "Shorten the range with a wall stop and squeeze glutes harder."),
                SkillGuideMistake(mistake: "Elbows bend to return.", fix: "Regress range or elevation until arms can stay long."),
                SkillGuideMistake(mistake: "Hips snap back first.", fix: "Slow the return and think ribs pull the wheel home.")
            ]
        )
    }

    private static func coreRaiseGuide(skillId: String) -> SkillGuide {
        let hanging = skillId.contains("hanging") || skillId == "cl.toes-to-bar"
        let name = skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: hanging
                ? "A clean \(name) starts from an active hang, uses a quiet shoulder position, curls the pelvis instead of swinging the legs, reaches the required height, and lowers under control without building momentum."
                : "A clean \(name) starts with the low back controlled, raises from the pelvis with no bounce, reaches the target range, then lowers slower than it lifted.",
            scoringNote: "Count strict reps only. If the descent creates the next rep's swing or the knees bend to steal leverage, use an easier raise.",
            assistance: [
                SkillGuideAssistance(name: "Bent-Knee Raise", detail: "Shorten the lever so the pelvis can curl and the shoulders stay quiet.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Eccentric Lower", detail: "Start near the top and lower for 2-4 seconds. This builds control without needing a perfect concentric yet.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Captain's Chair", detail: "Use supported elbows or dip bars when grip or swing control blocks clean abdominal work.", icon: "rectangle.on.rectangle")
            ],
            tips: [
                SkillGuideTip(title: "Start with the pelvis", detail: "The rep becomes an ab skill when the tailbone curls up. Throwing the feet mostly trains momentum.", icon: "arrow.up.circle.fill"),
                SkillGuideTip(title: "Quiet bar, quiet body", detail: "A strict raise should not turn the hang into a pendulum. Reset between reps if needed.", icon: "pause.circle.fill"),
                SkillGuideTip(title: "Lower like brakes", detail: "The eccentric should be slower than the lift. Dropping the legs reloads the next cheat.", icon: "metronome")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Swinging through reps.", fix: "Pause at the bottom, reduce reps, or regress to bent-knee raises until the body stays still."),
                SkillGuideMistake(mistake: "Only lifting to waist height.", fix: "Use knee raises and finish by curling knees toward chest before extending the lever."),
                SkillGuideMistake(mistake: "Loose shoulders in the hang.", fix: "Practice active hangs and scapular depression before adding higher raises.")
            ]
        )
    }

    private static func lSitFamilyGuide(skillId: String) -> SkillGuide {
        let name = skillId == "cal.l-sit-10" ? "L-sit" : skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: "A clean \(name) has hands pressing down, elbows locked, shoulders depressed, hips lifted, legs held in the target shape, knees straight, and toes pointed without shrugging or dragging the heels.",
            scoringNote: "Use parallettes, blocks, or tucked variations if mobility limits the floor version. The hold only counts while hips and legs stay lifted.",
            assistance: [
                SkillGuideAssistance(name: "Tuck L-Sit", detail: "Keep knees bent and lift the hips first. This builds support strength before hamstring mobility becomes the bottleneck.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "One-Leg L-Sit", detail: "Alternate one straight leg and one tucked leg to bridge between tuck and full L.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Compression Lifts", detail: "Sit tall and lift straight legs or heels from the floor for short reps to train active hip compression.", icon: "arrow.up.to.line")
            ],
            tips: [
                SkillGuideTip(title: "Push before you lift", detail: "Shoulders down and elbows locked create space for the hips. Without the press, the legs have nowhere to go.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Quads stay on", detail: "Locked knees are active. Pointed toes and squeezed quads make the lever cleaner and easier to judge.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Blocks are not cheating", detail: "Extra hand height lets more athletes train the correct shape while compression and hamstrings catch up.", icon: "square.stack.3d.up")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Shoulders shrug toward ears.", fix: "Return to support holds and think push the floor away."),
                SkillGuideMistake(mistake: "Knees bend as fatigue hits.", fix: "Use shorter holds, one-leg variations, or a tuck until legs can stay locked."),
                SkillGuideMistake(mistake: "Hips stay on the floor.", fix: "Raise the hands on parallettes or blocks and prioritize lifting the hips before extending legs.")
            ]
        )
    }

    private static func frontLeverGuide(skillId: String) -> SkillGuide {
        let name = skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: "A clean \(name) hangs face-up under the bar or rings with elbows locked, shoulders depressed, ribs down, pelvis tucked, and hips level with shoulders. The chosen lever shape must stay still for the full hold.",
            scoringNote: "Front lever is straight-arm lat strength plus trunk position. Bent elbows, shrugging, piking, or a banana back move the set back to an easier progression.",
            assistance: [
                SkillGuideAssistance(name: "Tuck Lever Hold", detail: "Shorten the lever aggressively. Own 10-15 second clean tucks before opening the hips.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Band-Assisted Lever", detail: "Use a band at the hips or feet so the horizontal line can be practiced without collapse.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Lever Row or Negative", detail: "Rows and slow lowers build the same shoulder extension strength while exposing hip drop.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Hands toward hips", detail: "Think straight-arm pulldown: drive the bar toward your hips while the shoulders stay down.", icon: "arrow.down.backward"),
                SkillGuideTip(title: "Lengthen one lever at a time", detail: "Tuck, open tuck, one-leg, straddle, and full are not ego labels. Pick the shape you can keep horizontal.", icon: "slider.horizontal.3"),
                SkillGuideTip(title: "Accumulate clean seconds", detail: "Several crisp 6-10 second holds beat one max attempt that changes shape halfway through.", icon: "timer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Bending the elbows.", fix: "Regress the lever or use a band until the arms can stay locked."),
                SkillGuideMistake(mistake: "Hips drop below shoulder line.", fix: "Return to tuck or open tuck and squeeze glutes with ribs closed."),
                SkillGuideMistake(mistake: "Shrugging toward the ears.", fix: "Add active hangs, scapular pulls, and shorter lever holds with shoulders depressed.")
            ]
        )
    }

    private static func backLeverGuide(skillId: String) -> SkillGuide {
        if skillId == "cl.german-hang" {
            return SkillGuide(
                standard: "A clean German hang is entered slowly through a skin-the-cat path, held pain-free with straight arms behind the body, quiet rings, calm breathing, and an exit through the same route.",
                scoringNote: "This is shoulder-extension capacity, not a courage test. Sharp anterior shoulder pain, bent arms, panic breathing, or dropping into range ends the attempt.",
                assistance: [
                    SkillGuideAssistance(name: "Feet-Assisted German Hang", detail: "Set the rings low and keep toes on the floor so you can dose the stretch and practice the exit before full bodyweight.", icon: "shoeprints.fill"),
                    SkillGuideAssistance(name: "Box-Assisted Skin the Cat", detail: "Use a box to guide the pass-through instead of free-falling into the bottom position.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "Ring Support and Reverse Plank", detail: "Prepare shoulder extension with supports, reverse planks, and short assisted holds before full hangs.", icon: "figure.strengthtraining.functional")
                ],
                tips: [
                    SkillGuideTip(title: "Depth is earned", detail: "Start shallow and add range only when the shoulders stay warm, quiet, and pain-free.", icon: "slider.horizontal.3"),
                    SkillGuideTip(title: "Straight arms, soft intent", detail: "The elbows stay locked, but the shoulders should not be jammed. Think long arms and controlled chest opening.", icon: "checkmark.seal.fill"),
                    SkillGuideTip(title: "Exit proves ownership", detail: "If you cannot reverse the path, the hang was too deep or too heavy for today.", icon: "arrow.uturn.backward")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Dropping into the bottom.", fix: "Lower the rings, use foot assistance, and slow the pass-through before adding depth."),
                    SkillGuideMistake(mistake: "Holding through sharp pain.", fix: "Stop immediately and rebuild shoulder extension with assisted range."),
                    SkillGuideMistake(mistake: "Bending elbows to survive.", fix: "Regress the load. Bent elbows hide the shoulder position and change the stress.")
                ]
            )
        }

        if skillId == "cl.skin-the-cat" {
            return SkillGuide(
                standard: "A clean skin-the-cat starts from a quiet ring hang, moves through tuck or pike to inverted hang, passes under control into German hang, then reverses back to the starting hang without dropping or bending the elbows.",
                scoringNote: "Count only reps with a controlled bottom and a controlled return. If the athlete can enter but cannot reverse out, it is a partial progression.",
                assistance: [
                    SkillGuideAssistance(name: "Tuck Pass-Through", detail: "Keep the knees tight to shorten the lever while learning the shoulder route.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Low-Ring Foot Assist", detail: "Use toes on the floor at the bottom so the shoulders never absorb a sudden drop.", icon: "shoeprints.fill"),
                    SkillGuideAssistance(name: "German Hang Holds", detail: "Build short, calm holds at the bottom before asking for full repeated reps.", icon: "figure.gymnastics")
                ],
                tips: [
                    SkillGuideTip(title: "The bottom is not a fall", detail: "Lower into shoulder extension slowly enough that you could stop at any point.", icon: "arrow.down.circle.fill"),
                    SkillGuideTip(title: "Reverse the movie", detail: "Come out by retracing the same path: German hang, inverted tuck, then quiet hang.", icon: "arrow.triangle.2.circlepath"),
                    SkillGuideTip(title: "Rings should stay boring", detail: "Swinging rings usually mean the hips kicked instead of the shoulders and core controlling the rotation.", icon: "circle.grid.cross")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Dropping into German hang.", fix: "Use low rings and feet assistance until the descent is slow."),
                    SkillGuideMistake(mistake: "Bending arms during the pass-through.", fix: "Return to tighter tuck reps and straight-arm active hangs."),
                    SkillGuideMistake(mistake: "Going deeper than can be reversed.", fix: "Limit range to the deepest point you can exit cleanly.")
                ]
            )
        }

        let name = skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: "A clean \(name) uses straight arms, controlled shoulder extension, a rigid ribs-down body line, and a slow entry and exit. Full back lever standards require a face-down horizontal line with legs straight and together.",
            scoringNote: "Back lever loads shoulders and elbow tendons hard. No hold counts through pain, bent arms, or a rushed drop into German hang.",
            assistance: [
                SkillGuideAssistance(name: "German Hang", detail: "Build pain-free shoulder extension tolerance first. Enter and exit slowly every time.", icon: "figure.gymnastics"),
                SkillGuideAssistance(name: "Skin the Cat", detail: "Use controlled pass-throughs to learn the route before pausing in harder lever shapes.", icon: "arrow.triangle.2.circlepath"),
                SkillGuideAssistance(name: "Tuck Back Lever", detail: "Keep knees tight and elbows locked. This is the safest first horizontal pause.", icon: "figure.core.training")
            ],
            tips: [
                SkillGuideTip(title: "Mobility before intensity", detail: "If German hang feels sharp or panicked, the back lever is not ready yet.", icon: "exclamationmark.triangle.fill"),
                SkillGuideTip(title: "Elbows stay honest", detail: "Bent arms make the hold easier and put ugly load into the wrong tissues.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Exit the same path", detail: "A controlled return protects the shoulders and proves the position was owned.", icon: "arrow.uturn.backward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Dropping into shoulder extension.", fix: "Use feet assistance, lower rings, or smaller range until entry speed is controlled."),
                SkillGuideMistake(mistake: "Ignoring anterior shoulder pain.", fix: "Stop the set and rebuild German hang tolerance. Pain is not a progression."),
                SkillGuideMistake(mistake: "Arching the low back to fake horizontal.", fix: "Squeeze glutes, close ribs, and use a wider straddle or tuck.")
            ]
        )
    }

    private static func threeSixtyPullGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean 360-degree pull starts from an active hang, pulls high enough to release safely, tucks and rotates one full turn, spots the bar, re-catches with active shoulders, and absorbs into control instead of slamming into a dead hang.",
            scoringNote: "This is an elite release skill. It should be trained only with safe landing space, mats, and prerequisite high pulls. Missed catches, blind reaches, or uncontrolled shoulder shock do not count.",
            assistance: [
                SkillGuideAssistance(name: "Explosive Chest-to-Bar", detail: "Build the height first. The release needs more than chin-over-bar strength.", icon: "arrow.up.forward"),
                SkillGuideAssistance(name: "Bar Release Drill", detail: "Practice small releases and re-grips without rotation so the catch stays calm.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Tuck Rotation Practice", detail: "Use floor, trampoline, or supervised progressions to own the fast tuck and spot before combining it with a bar.", icon: "arrow.triangle.2.circlepath")
            ],
            tips: [
                SkillGuideTip(title: "Height buys time", detail: "A low release makes the catch desperate. Build pull height before adding rotation.", icon: "arrow.up.circle.fill"),
                SkillGuideTip(title: "Tuck after release", detail: "Pull tall first, then snap into the tuck to rotate. Tucking too early steals height.", icon: "figure.core.training"),
                SkillGuideTip(title: "Catch active", detail: "Reach with shoulders ready and lats on so the re-catch absorbs instead of yanking the joints.", icon: "checkmark.seal.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Under-rotating and reaching sideways.", fix: "Return to rotation drills and do not combine the skill until the spot is consistent."),
                SkillGuideMistake(mistake: "Re-catching in a dead hang shock.", fix: "Practice release re-grips and active-hang catches before full attempts."),
                SkillGuideMistake(mistake: "Trying it without enough pull height.", fix: "Build explosive pulls to lower chest or higher first.")
            ]
        )
    }

    private static func dragonFlagGuide(skillId: String) -> SkillGuide {
        let full = skillId == "cl.dragon-flag"
        return SkillGuide(
            standard: full
                ? "A clean dragon flag anchors the shoulders, lifts the body as one rigid unit, lowers under control without hip pike or lumbar arch, and avoids bouncing between reps."
                : "A clean dragon flag hip raise anchors the shoulders and drives the hips up into one straight line without kipping the legs or folding at the waist.",
            scoringNote: "This is a long-lever anti-extension skill. Stop when the body line breaks; do not grind through back extension.",
            assistance: [
                SkillGuideAssistance(name: "Reverse Crunch", detail: "Curl the pelvis first so the hip raise is abdominal, not just leg momentum.", icon: "arrow.up.circle.fill"),
                SkillGuideAssistance(name: "Tuck Dragon Flag", detail: "Shorten the lever by bending knees while keeping shoulders anchored and hips extended.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Negative Only", detail: "Start high and lower for 3-5 seconds. Reset at the top instead of bouncing from the bottom.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Anchor hard", detail: "Hands and lats pin the upper body so the trunk can move as one piece.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "One line, not a pike", detail: "The harder the lever gets, the more tempting it is to fold at the hips. That changes the skill.", icon: "line.diagonal"),
                SkillGuideTip(title: "Own the negative", detail: "Controlled lowers build the dragon flag faster than sloppy full reps.", icon: "metronome")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Piking at the hips.", fix: "Use tuck or one-leg flags until the body can stay rigid."),
                SkillGuideMistake(mistake: "Swinging from the bottom.", fix: "Reset each rep and slow the eccentric."),
                SkillGuideMistake(mistake: "Shrugging or neck strain.", fix: "Re-anchor the shoulders and reduce range if the upper body cannot stay pinned.")
            ]
        )
    }

    private static func crowFamilyGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "hs.crane-pose":
            return SkillGuide(
                standard: "A clean crane pose is a straight-arm arm balance: hands planted shoulder-width, knees high on the upper arms, elbows locked or very close to locked, upper back rounded, hips lifted, and feet floating without a hop.",
                scoringNote: "Crow does not count as crane. Count only holds where the elbows stay straight and the knees remain high on the arms instead of sliding down toward the elbows.",
                assistance: [
                    SkillGuideAssistance(name: "Crow Hold", detail: "Own 15-30 seconds of calm crow first so balance is not the limiter when the elbows begin to straighten.", icon: "timer"),
                    SkillGuideAssistance(name: "Block Under Feet", detail: "Start with toes on a yoga block or low step while practicing the press into straighter arms.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "Crane Toe Taps", detail: "Press tall, lightly tap one toe down, then float again without rebending the elbows.", icon: "shoeprints.fill")
                ],
                tips: [
                    SkillGuideTip(title: "Hips rise as arms straighten", detail: "Crane is not just crow with strained elbows. Press the floor away and let the hips climb so the balance point stays over the hands.", icon: "arrow.up.circle.fill"),
                    SkillGuideTip(title: "Knees stay high", detail: "Keep the knee contact near the triceps or upper arm. Sliding toward the elbows usually forces a collapse back into crow.", icon: "scope"),
                    SkillGuideTip(title: "Fingers are the brakes", detail: "Use fingertip pressure to stop tipping forward. Do not fix every wobble by bending the arms.", icon: "hand.tap.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Calling bent elbows crane.", fix: "Regress to crow-to-crane presses and count only the seconds where elbows stay straight."),
                    SkillGuideMistake(mistake: "Knees slide down the arms.", fix: "Reset the knees higher before the press and keep the upper back rounded."),
                    SkillGuideMistake(mistake: "Hopping into the hold.", fix: "Lean and press until the feet float. Hops hide the balance point.")
                ]
            )
        case "hs.flying-crow":
            return SkillGuide(
                standard: "A clean flying crow holds one knee high on the upper arm while the opposite leg extends long behind the body, toe pointed, shoulders active, fingers steering, and the pelvis controlled instead of twisting open.",
                scoringNote: "Count holds only when the support knee stays connected and the back leg extends from balance, not from a fast kick that throws the body forward.",
                assistance: [
                    SkillGuideAssistance(name: "Crow Knee Anchor", detail: "Practice one-knee crow holds where one knee carries more contact before the opposite leg leaves.", icon: "1.circle.fill"),
                    SkillGuideAssistance(name: "Back-Leg Slides", detail: "From crow, slide one toe back on the floor until the body learns the longer lever.", icon: "arrow.right"),
                    SkillGuideAssistance(name: "Wall Toe Reach", detail: "Reach the back toe toward a wall or block so the extension has a target and does not swing sideways.", icon: "scope")
                ],
                tips: [
                    SkillGuideTip(title: "Shift before extending", detail: "The long leg changes the balance. Move the shoulders and hand pressure first, then lengthen the leg.", icon: "arrow.up.forward"),
                    SkillGuideTip(title: "Anchor knee, long opposite leg", detail: "The support knee is the shelf. The back leg is a lever. If either disappears, the pose turns into a fall.", icon: "line.diagonal"),
                    SkillGuideTip(title: "Keep the kick quiet", detail: "Point the toe and extend smoothly. A whip-like kick usually pulls the hands past their braking power.", icon: "metronome")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Back leg swings sideways.", fix: "Use a wall target and extend straight behind the hip before trying longer holds."),
                    SkillGuideMistake(mistake: "Support knee slips off the arm.", fix: "Return to crow and keep the knee higher before shifting."),
                    SkillGuideMistake(mistake: "Dumping into wrists.", fix: "Warm wrists, spread fingers, and reduce hold time until pressure corrections stay small.")
                ]
            )
        default:
            return SkillGuide(
                standard: "A clean crow pose balances on the hands with elbows bent, knees high on the upper arms, hips lifted, upper back rounded, feet off the floor, and gaze slightly forward without collapsing into the wrists.",
                scoringNote: "The feet must float from a controlled forward lean. Do not count knee-resting squats, toe drags, or hops that land in a panic balance.",
                assistance: [
                    SkillGuideAssistance(name: "Tripod Toe Taps", detail: "Keep toes light on the floor while shifting shoulders forward and learning finger pressure.", icon: "shoeprints.fill"),
                    SkillGuideAssistance(name: "Block Under Feet", detail: "Start from a block so the hips are already high and the knees can land higher on the arms.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "One-Foot Float", detail: "Lift one foot at a time until both feet can float without a jump.", icon: "1.circle.fill")
                ],
                tips: [
                    SkillGuideTip(title: "Build the shelf first", detail: "Elbows bend and knees press high into the arms. Without that shelf, the pose becomes wrist strength and hope.", icon: "scope"),
                    SkillGuideTip(title: "Lean until feet get light", detail: "Shift shoulders forward of the wrists slowly. The feet should peel up because the center of mass moved.", icon: "arrow.forward.circle.fill"),
                    SkillGuideTip(title: "Round the upper back", detail: "Push the floor away and keep the chest from dropping between the shoulders.", icon: "rectangle.compress.vertical")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Jumping both feet up.", fix: "Practice one-foot floats and stop once fingertip pressure can control the lean."),
                    SkillGuideMistake(mistake: "Knees too low on the arms.", fix: "Squat deeper, lift hips higher, and place knees closer to the triceps."),
                    SkillGuideMistake(mistake: "Looking straight down.", fix: "Look slightly ahead of the hands so the body can counterbalance instead of tipping forward.")
                ]
            )
        }
    }

    private static func elbowLeverGuide(isOneArm: Bool) -> SkillGuide {
        SkillGuide(
            standard: isOneArm
                ? "A clean one-arm elbow lever balances the body horizontal on one anchored elbow with the free arm controlled, wrists stable, glutes tight, and no collapsing through the shoulder."
                : "A clean elbow lever balances the body horizontal with elbows anchored into the lower abdomen or hip crease, hands close enough to support the lean, wrists active, and legs squeezed into one rigid line.",
            scoringNote: "Elbow lever is placement and balance as much as strength. Count holds only when the body floats instead of being kicked up and caught.",
            assistance: [
                SkillGuideAssistance(name: "Frog Stand", detail: "Use a compact balance to learn finger pressure and forward lean before extending the body.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Tuck Elbow Lever", detail: "Keep knees tucked and find the elbow shelf before lengthening the legs.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Parallette Lever", detail: "Use parallettes if wrist extension on the floor blocks clean practice.", icon: "rectangle.on.rectangle")
            ],
            tips: [
                SkillGuideTip(title: "Elbows are kickstands", detail: "Place them low enough on the abdomen or hip crease that the torso can rest on the shelf.", icon: "scope"),
                SkillGuideTip(title: "Lean until feet float", detail: "Do not jump the legs up. Shift forward and let the balance point lift them.", icon: "arrow.up.forward"),
                SkillGuideTip(title: "Fingers steer", detail: "Press fingertips into the floor to stop tipping forward and heel of hand to shift back.", icon: "hand.tap.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Elbows slide wide or too high.", fix: "Reset hand width and wedge elbows into the lower abdomen before leaning."),
                SkillGuideMistake(mistake: "Trying to lift legs before balance point.", fix: "Lean forward gradually until the feet become light."),
                SkillGuideMistake(mistake: "Wrists collapse.", fix: "Warm up wrists, use parallettes, or reduce hold duration.")
            ]
        )
    }

    private static func pullupGuide(title: String, grip: String, standardDetail: String, extraTip: String?) -> SkillGuide {
        var tips = [
            SkillGuideTip(title: "Start from an honest bottom", detail: "Arms reach full extension before each rep. Brace ribs and glutes before pulling so the body does not turn into a swing.", icon: "arrow.down.to.line"),
            SkillGuideTip(title: "Pull elbows toward the ribs", detail: "Think shoulder blades down and back, then elbows driving to the sides. The chin clears because the body rises, not because the neck reaches.", icon: "arrow.down.backward"),
            SkillGuideTip(title: "Stop sets before reps slow badly", detail: "For skill progress, crisp submaximal sets usually beat grinding until every rep changes shape.", icon: "speedometer")
        ]
        if let extraTip {
            tips.append(SkillGuideTip(title: "Respect the variation", detail: extraTip, icon: "checkmark.seal.fill"))
        }

        return SkillGuide(
            standard: "A clean \(title) uses a \(grip). \(standardDetail)",
            scoringNote: "Count only reps with a still lower body, clear top position, and controlled return to full extension.",
            assistance: [
                SkillGuideAssistance(name: "Band-Assisted Pull-Up", detail: "Use a band that lets every rep finish cleanly. Reduce band help only when the top and bottom positions stay identical.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Negative Pull-Up", detail: "Jump or step to the top, then lower for 3-5 seconds through the full range. Keep shoulders down instead of dropping loose.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Inverted Row", detail: "Build pulling volume with rows when full vertical reps are not ready. Keep the body rigid and pull the chest to the bar or rings.", icon: "figure.strengthtraining.functional")
            ],
            tips: tips,
            mistakes: [
                SkillGuideMistake(mistake: "Craning the chin to fake the finish.", fix: "Keep the neck neutral and pull the chest up. The chin clears after the torso rises."),
                SkillGuideMistake(mistake: "Kicking or swinging into the rep.", fix: "Reset to a still hang between reps. Use band assistance if stillness makes the rep disappear."),
                SkillGuideMistake(mistake: "Dropping out of the eccentric.", fix: "Lower under control until the arms are straight. Own the descent before adding reps.")
            ]
        )
    }

    private static func weightedPullGuide(isChin: Bool) -> SkillGuide {
        let name = isChin ? "weighted chin-up" : "weighted pull-up"
        let grip = isChin ? "supinated chin-up grip" : "overhand pull-up grip"
        let chinGripDetail = " For the chin-up version, think in two viewpoints: from the athlete's perspective, the knuckles wrap over the far side of the bar; from a front camera, the knuckle side of both hands is visible. Thumbs stay underneath and the wrist never rolls into an overhand pull-up shape."
        return SkillGuide(
            standard: "A clean \(name) is the same strict rep with external load added by belt, vest, or dumbbell. Use a \(grip), brace before the first pull, clear the bar, and control the plate through the descent.\(isChin ? chinGripDetail : "")",
            scoringNote: "Do not count loaded reps that shorten the bottom, swing the weight, or trade range of motion for heavier numbers.",
            assistance: [
                SkillGuideAssistance(name: "Tempo Bodyweight Reps", detail: "Use slow 3-second lowers and pauses at the top before adding load. The weighted rep should inherit this control.", icon: "metronome"),
                SkillGuideAssistance(name: "Light Vest Loading", detail: "Start with a vest or tiny belt load so the rep pattern stays quiet before using heavier hanging plates.", icon: "shippingbox.fill"),
                SkillGuideAssistance(name: "Weighted Negative", detail: "Use very small load and a controlled lower when full weighted reps are not ready. Keep volume low to protect elbows.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Step into the first rep", detail: "Do not jump into a swinging plate. Set the load still, brace, then pull.", icon: "pause.circle.fill"),
                isChin
                    ? SkillGuideTip(title: "Run the knuckle check", detail: "Before every set, confirm a front view would see the knuckle side of both hands. From your perspective, those knuckles wrap over the far side of the bar.", icon: "hand.raised.fill")
                    : SkillGuideTip(title: "Keep the overhand shape", detail: "The loaded pull-up should keep the same pronated hand position from bottom to top instead of drifting into a mixed or half-chin grip.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Small jumps win", detail: "Add load in small increments. A clean 2.5-5 lb jump beats a bigger jump that changes the rep.", icon: "plus.circle.fill"),
                SkillGuideTip(title: "Keep bodyweight reps alive", detail: "Weighted work builds strength, but clean unweighted volume keeps the pattern and elbows happier.", icon: "repeat")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Adding weight before clean bodyweight reps.", fix: "Build several strict reps with full range first. Load should amplify the pattern, not replace it."),
                isChin
                    ? SkillGuideMistake(mistake: "Hands flip into a pull-up.", fix: "Reset the grip so a front camera sees knuckles, thumbs stay underneath, and the wrists stay stacked. Reduce load if the wrist cannot hold that orientation.")
                    : SkillGuideMistake(mistake: "Grip changes under load.", fix: "Lower the weight and keep both hands in the same overhand position for the full rep."),
                SkillGuideMistake(mistake: "Letting the plate swing.", fix: "Start still, keep legs quiet, and pause between reps if the load drifts."),
                SkillGuideMistake(mistake: "Cutting range to lift more.", fix: "Use less load until the chin-over-bar top and full-extension bottom both return.")
            ]
        )
    }

    private static func explosivePullGuide(isClapping: Bool) -> SkillGuide {
        SkillGuide(
            standard: isClapping
                ? "A clean clapping pull-up starts from a controlled hang, pulls explosively high enough for both hands to leave the bar, claps once, then re-grips and absorbs under control."
                : "A clean explosive pull-up starts from a dead stop, keeps hollow tension, and pulls as high as possible without kipping. The set ends when height or speed drops.",
            scoringNote: "Power reps are quality reps. Count low, crisp attempts; do not turn the set into sloppy conditioning.",
            assistance: [
                SkillGuideAssistance(name: "Fast Assisted Pull-Up", detail: "Use a light band to practice speed while keeping the same strict start and controlled lower.", icon: "bolt.fill"),
                SkillGuideAssistance(name: "Chest-to-Bar Pull-Up", detail: "Build height before release skills. Aim the bar to upper chest, then lower under control.", icon: "arrow.up.forward"),
                SkillGuideAssistance(name: "Jumping Pull + Negative", detail: "Jump to the high position, then own the descent. This trains the landing side of power work without needing max pull height yet.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Power comes early", detail: "Do explosive work near the start of training after warm-up, before fatigue turns speed into grinding.", icon: "flame.fill"),
                SkillGuideTip(title: "Stop when height drops", detail: "If the bar no longer reaches the same target, the nervous system is practicing slower reps.", icon: "chart.line.downtrend.xyaxis"),
                SkillGuideTip(title: "Strict first, speed second", detail: "Explosive pulling should sit on top of strict control, not replace it.", icon: "checkmark.seal.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Kipping to fake height.", fix: "Return to strict explosive singles or use assistance until the body stays tight."),
                SkillGuideMistake(mistake: "Doing too many reps per set.", fix: "Use short sets of 1-3 reps with full rest. Power fades quickly."),
                SkillGuideMistake(mistake: "Catching loose after release.", fix: "Re-grip with bent elbows and active shoulders, then lower under control.")
            ]
        )
    }

    private static func archerPullGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean archer pull-up uses a wide grip, pulls the chest toward one hand, keeps the opposite arm long, then lowers under control to a full hang before switching or repeating sides.",
            scoringNote: "The working side must clearly do the pull. If both elbows bend equally, it is a wide pull-up, not an archer rep.",
            assistance: [
                SkillGuideAssistance(name: "Archer Ring Row", detail: "Practice the same side-to-side pull on rings with feet on the floor before taking it vertical.", icon: "circle.grid.cross"),
                SkillGuideAssistance(name: "Band-Assisted Archer", detail: "Use a band so the working arm can finish while the assisting arm stays long.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Typewriter Hold", detail: "Pull to the top, shift slightly toward one side, then lower. Build control before full side travel.", icon: "arrow.left.and.right")
            ],
            tips: [
                SkillGuideTip(title: "One arm works, one arm guides", detail: "The straight arm is a support rail. The bent arm should feel like the main pull.", icon: "arrow.left.arrow.right"),
                SkillGuideTip(title: "Keep the chest square-ish", detail: "Some rotation is natural, but spinning open to finish hides missing unilateral strength.", icon: "scope"),
                SkillGuideTip(title: "Train both sides honestly", detail: "Start each set with the weaker side or match its reps so asymmetry does not quietly grow.", icon: "equal.circle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Both arms bend the same amount.", fix: "Widen the grip, use assistance, and keep the non-working arm longer."),
                SkillGuideMistake(mistake: "Cutting the bottom short.", fix: "Return to a full hang each rep so the shoulder learns the whole range."),
                SkillGuideMistake(mistake: "Yanking sideways with no control.", fix: "Slow the eccentric and use ring-row archers until the path is smooth.")
            ]
        )
    }

    private static func soloArmGuide(skillId: String) -> SkillGuide {
        let isChin = skillId.contains("chin")
        let isNegative = skillId == "pp.oap-negative"
        let isHeighted = skillId == "pp.heighted-chin-up"
        let name = isHeighted ? "heighted chin-up" : (isNegative ? "one-arm pull-up negative" : (isChin ? "one-arm chin-up" : "one-arm pull-up"))
        let chinStandard = " For chin-up variants, the working hand must stay supinated: from the athlete's perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Thumb stays underneath and the elbow tracks down and slightly forward."
        return SkillGuide(
            standard: isNegative
                ? "A clean one-arm negative starts at the top with one hand, shoulder packed, torso quiet, and lowers slowly through the full range without dropping or twisting out."
                : "A clean \(name) starts from an active one-arm hang, initiates with scapular depression, pulls the elbow toward the ribs or hip, clears the bar, and lowers under control.\(isChin || isHeighted ? chinStandard : "")",
            scoringNote: "This is tendon-heavy work. Low volume, long rest, and perfect control matter more than chasing daily max attempts.",
            assistance: [
                SkillGuideAssistance(name: "Assisted One-Arm Pull", detail: "Hold a towel, band, ring, or lower strap with the free hand. Move the assist lower over time so it contributes less.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Archer Pull-Up", detail: "Use archers to shift more load to one arm while the other arm stays as a guide.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "One-Arm Isometric", detail: "Hold top, middle, or lower positions for short clean efforts before trying full reps.", icon: "pause.circle.fill")
            ],
            tips: [
                SkillGuideTip(title: "Scap first", detail: "Begin by pulling the shoulder down away from the ear. Bending the elbow before the shoulder is set makes the rep weaker and rougher.", icon: "arrow.down.circle.fill"),
                isChin || isHeighted
                    ? SkillGuideTip(title: "Keep knuckles visible", detail: "On the working hand, a front view should see knuckles through the whole rep. If the palm opens toward the camera, the wrist has flipped out of the chin-up position.", icon: "hand.raised.fill")
                    : SkillGuideTip(title: "Own the working hand", detail: "The working hand stays fixed on the bar while the shoulder and torso organize around it. Do not let the wrist twist to escape the hard range.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Fight rotation quietly", detail: "Some rotation is unavoidable, but the torso should not spin wildly to manufacture height.", icon: "rotate.3d"),
                SkillGuideTip(title: "Protect the elbows", detail: "Hard negatives and assisted singles need recovery. Stop if tendon pain rises during the session.", icon: "cross.case.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Jumping straight to max attempts.", fix: "Use assisted reps, isometrics, and negatives so the shoulder and elbow adapt gradually."),
                isChin || isHeighted
                    ? SkillGuideMistake(mistake: "Working hand turns overhand.", fix: "Reset before continuing: visible knuckles from the front, thumb under, elbow slightly forward. Add assistance if that position cannot stay.")
                    : SkillGuideMistake(mistake: "Wrist twists to find leverage.", fix: "Use more assistance and keep the working hand stable through the whole range."),
                SkillGuideMistake(mistake: "Dropping through the negative.", fix: "Shorten the range or add assistance until every inch is controlled."),
                SkillGuideMistake(mistake: "Shrugging at the bottom.", fix: "Rebuild active one-arm hangs and scapular depression before full attempts.")
            ]
        )
    }

    private static func lSitChinGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean L-sit chin-up holds a true supinated grip, keeps legs straight near horizontal, pulls from full extension until the chin clears the bar, and lowers without letting the legs drop or swing. From the athlete's perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Thumbs wrap underneath and the wrists do not roll into overhand.",
            scoringNote: "The pull and the compression both count. If the legs fold or drop, regress the L position before adding reps.",
            assistance: [
                SkillGuideAssistance(name: "Tuck Chin-Up", detail: "Pull with knees tucked high. Keep the same hollow trunk before extending one or both legs.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Hanging Knee Raise", detail: "Build the compression and hip-flexor endurance needed to keep the legs up during the pull.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "One-Leg L Pull", detail: "Hold one leg straight and one leg tucked to bridge from tuck work to the full L shape.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "Ribs down before the pull", detail: "Set the hollow/compressed shape first. If the trunk opens, the legs will drop as soon as the pull gets hard.", icon: "circle.hexagongrid.fill"),
                SkillGuideTip(title: "Grip can help", detail: "The chin-up grip lets the biceps help, but only if it stays readable: visible knuckles from the front, thumb underneath, wrist stacked. Use that help to keep the L position cleaner, not to rush reps.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Own the bottom", detail: "Return to full arm extension while the legs stay lifted. That bottom position is where most reps leak.", icon: "arrow.down.to.line")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Legs drop during the pull.", fix: "Use tuck or one-leg variations until the trunk can hold position through the full rep."),
                SkillGuideMistake(mistake: "Grip turns into a pull-up.", fix: "Reset the hands before the next rep. A front view should see the knuckle side, with thumbs underneath and wrists stacked."),
                SkillGuideMistake(mistake: "Swinging into the first rep.", fix: "Pause in a still L hang before pulling."),
                SkillGuideMistake(mistake: "Partial pull range.", fix: "Lower the leg difficulty so the chin-up can still reach a clear top.")
            ]
        )
    }

    private static func rowGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "pp.incline-row":
            return baseRowGuide(
                name: "incline row",
                standard: "Set the bar or rings high enough that the body is angled, start with arms straight, keep a plank line, and pull lower chest or ribs to the hands without reaching the neck.",
                assistance: "Raise the bar or rings, bend the knees, or walk the feet back until every rep reaches the same top position.",
                progression: "Lower the handles, walk the feet forward, straighten the legs, then progress toward decline rows."
            )
        case "pp.row":
            return baseRowGuide(
                name: "inverted row",
                standard: "Set a low bar or rings so the body is close to horizontal with heels grounded. Start from straight arms, keep ribs down and glutes on, pull lower chest or ribs to the hands, then return to the same straight-arm bottom.",
                assistance: "Raise the bar or rings, bend the knees, or step the feet back until the torso reaches the implement without hips sagging.",
                progression: "Lower the handles, straighten the legs fully, add a top pause, then elevate the feet for decline rows."
            )
        case "pp.decline-row":
            return baseRowGuide(
                name: "decline row",
                standard: "Use a near-horizontal body with feet elevated or handles low, keep head-to-heel tension, pull middle or lower chest to the bar, then lower to straight arms.",
                assistance: "Remove foot elevation, bend the knees, or raise the handles until the hips stop sagging.",
                progression: "Add foot height, rings, pauses, wider grips, or load only after each rep reaches the same top."
            )
        case "pp.one-arm-row":
            return baseRowGuide(
                name: "one-arm row",
                standard: "Pull with one arm while the torso stays square and quiet. The free hand may hover or lightly assist at easier levels, but it cannot twist the rep into place.",
                assistance: "Use a higher ring, wider feet, band help, or an assisted one-arm row with the free hand lightly on the strap.",
                progression: "Lower the rings, narrow the feet, elevate the feet, add pauses, then reduce free-hand assistance."
            )
        case "pp.tuck-row":
            return leverRowGuide(name: "tuck row", shape: "tucked front-lever shape", assistance: "Use tuck front-lever holds, feet-supported arc rows, band assistance, or shorter partial reps.")
        case "pp.straddle-row":
            return leverRowGuide(name: "straddle row", shape: "straddle front-lever shape with hips level and legs open", assistance: "Use advanced tuck rows, one-leg rows, half-straddle rows, band assistance, or controlled negatives.")
        default:
            return leverRowGuide(name: "tuck front lever pull-up", shape: "controlled tuck front lever", assistance: "Use tuck front-lever holds, partial-ROM reps, eccentric-only reps, band assistance, and front-lever rows.")
        }
    }

    private static func baseRowGuide(name: String, standard: String, assistance: String, progression: String) -> SkillGuide {
        SkillGuide(
            standard: "A clean \(name) keeps the body as one rigid line. \(standard)",
            scoringNote: "Progress by changing one variable at a time: body angle, foot support, range, tempo, unilateral load, or external load.",
            assistance: [
                SkillGuideAssistance(name: "Raise the Handles", detail: assistance, icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Scapular Row", detail: "With straight arms, squeeze and release the shoulder blades before bending the elbows. This teaches the start of the pull.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Tempo Row", detail: "Use a 2-1-2 rhythm: pull, pause at the top, lower under control. Tempo exposes hips and neck cheating fast.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Make the body a plank", detail: "Ribs down, glutes on, and hips level. The row gets harder because the body angle changes, not because the shape falls apart.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Chest moves, chin does not", detail: "Reach the target with the torso. Neck reaching is usually a sign the rep is too hard.", icon: "scope"),
                SkillGuideTip(title: "Progress one lever at a time", detail: progression, icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips sag or pike mid-rep.", fix: "Raise the handles or bend the knees until the body line stays consistent."),
                SkillGuideMistake(mistake: "Pulling to the throat with a forward head.", fix: "Aim lower chest or ribs to the bar and keep the neck neutral."),
                SkillGuideMistake(mistake: "Bouncing through the top.", fix: "Pause briefly at the top before lowering.")
            ]
        )
    }

    private static func leverRowGuide(name: String, shape: String, assistance: String) -> SkillGuide {
        SkillGuide(
            standard: "A clean \(name) begins in a \(shape), keeps shoulders depressed, rows without changing the lever, and lowers back to the same shape under control.",
            scoringNote: "The lever counts as much as the row. Do not progress if the hips drop, knees open unintentionally, or the rep turns into a regular pull-up.",
            assistance: [
                SkillGuideAssistance(name: "Static Lever Hold", detail: "Own the lever shape for short clean holds before adding bent-arm pulling.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Band-Assisted Lever Row", detail: assistance, icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Eccentric Lever Row", detail: "Start near the top and lower slowly while keeping the same lever shape.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Set the lever first", detail: "Do not start rowing from a loose hang. Depress the shoulders, set the trunk, then bend the arms.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Hips tell the truth", detail: "If the hips fall below the line, the lever is too long for the current strength.", icon: "line.diagonal"),
                SkillGuideTip(title: "Use leverage, not panic", detail: "Tuck, advanced tuck, one-leg, straddle, and full are leverage steps. Pick the shape you can keep.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Opening the tuck to gain momentum.", fix: "Use a shorter set, more assistance, or a simpler lever shape."),
                SkillGuideMistake(mistake: "Shrugging during the pull.", fix: "Return to scapular pulls and static lever holds with shoulders depressed."),
                SkillGuideMistake(mistake: "No controlled eccentric.", fix: "Lower back into the same lever. If you cannot, reduce range or assistance.")
            ]
        )
    }

    private static func ringMuscleUpGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean ring muscle-up starts in a secure false grip, pulls rings close toward the lower chest, rolls the chest over the rings with elbows close, then presses to a stable ring support.",
            scoringNote: "Ring muscle-ups demand false grip, transition control, and ring dip strength. Do not count reps where the rings drift wide or the false grip disappears before transition.",
            assistance: [
                SkillGuideAssistance(name: "False-Grip Ring Row", detail: "Row with the wrist already over the ring. This builds the grip and wrist path used in the transition.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Low-Ring Transition", detail: "Keep feet on the floor, pull rings to the chest, then roll forward into the bottom of a ring dip.", icon: "arrow.triangle.branch"),
                SkillGuideAssistance(name: "Ring Dip Negative", detail: "Build the press-out and bottom support so the transition has somewhere stable to land.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "False grip buys the turnover", detail: "The wrist starts above the ring so you do not need a desperate regrip in the hardest part.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Rings stay close", detail: "Pull the rings down the body. If they drift away, the transition becomes a shoulder fight.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Transition low and forward", detail: "Move the chest over the rings, elbows back, then press. It is not a normal pull-up followed by a pause.", icon: "arrow.up.and.forward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Losing false grip mid-rep.", fix: "Spend more time on false-grip hangs, rows, and low-ring transitions."),
                SkillGuideMistake(mistake: "Rings flare away from the body.", fix: "Use feet assistance and keep the rings brushing close through the pull."),
                SkillGuideMistake(mistake: "Trying to transition too low.", fix: "Build stricter high pulls and use assistance until the rings reach lower chest.")
            ]
        )
    }

    private static func strictMuscleUpGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean strict muscle-up starts from a dead or active hang, uses no kip or hip drive, pulls high enough to transition smoothly, keeps elbows close, then presses to full support.",
            scoringNote: "This is stricter than the regular muscle-up node. If swing or hip drive creates the turnover, log it under regular muscle-up work.",
            assistance: [
                SkillGuideAssistance(name: "High Strict Pull", detail: "Train strict pulls toward lower chest or upper stomach so the transition has enough height.", icon: "arrow.up.forward"),
                SkillGuideAssistance(name: "Slow Transition Negative", detail: "Start in top support and lower through the transition slowly, keeping wrists and elbows close.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Straight-Bar or Ring Dip", detail: "Own the press-out position so the turnover does not collapse once the chest gets over the hands.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "It is one continuous skill", detail: "Strict muscle-up is not pull-up, pause, then dip. The pull must feed the transition before momentum dies.", icon: "link"),
                SkillGuideTip(title: "False grip can help", detail: "A higher wrist shortens the turnover, especially on rings or slower strict reps.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Negatives are potent", detail: "Use low volume and clean control. Hard transition negatives can beat up elbows if stacked too often.", icon: "exclamationmark.triangle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Pulling only to chin height.", fix: "Build high-pull strength before expecting a strict turnover."),
                SkillGuideMistake(mistake: "Flaring elbows wide in transition.", fix: "Use assisted transitions and keep elbows close as the chest comes over."),
                SkillGuideMistake(mistake: "Calling a quiet kip strict.", fix: "Reset the standard: no swing, no hip pop, no leg kick.")
            ]
        )
    }

    private static func pushupGuide(skillId: String) -> SkillGuide {
        let isIncline = skillId == "cal.incline-pushup"
        let isDecline = skillId == "cal.decline-pushup"
        let name = isIncline ? "incline push-up" : (isDecline ? "decline push-up" : "push-up")
        let surface = isIncline ? "hands elevated on a stable bench or box" : (isDecline ? "feet elevated on a stable bench or box" : "hands on the floor")
        let depth = isIncline ? "chest touches the bench" : "chest reaches the floor or a fist-width above it"
        return SkillGuide(
            standard: "A clean \(name) starts in a rigid plank with \(surface), hands around shoulder width, ribs tucked, glutes squeezed, and legs quiet. Lower until \(depth), keep elbows about 30-45 degrees from the ribs, then press to a full elbow lockout without losing the body line.",
            scoringNote: "Count only full-range reps with one straight head-to-heel line. If the hips sag, the head dives first, or the elbows flare wide, regress the angle before chasing more reps.",
            assistance: [
                SkillGuideAssistance(name: "Wall Push-Up", detail: "Use a wall when floor strength is not there yet. Keep the same plank line and elbow path instead of treating it like a casual lean.", icon: "rectangle.portrait"),
                SkillGuideAssistance(name: "Higher Incline", detail: "Raise the hands until every rep reaches honest depth. Lower the surface over time: wall, counter, bench, low box, floor.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Negative Push-Up", detail: "Lower for 3-5 seconds, then reset from knees or a high plank. Slow eccentrics teach depth without turning the press into a grind.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Knee Push-Up", detail: "Use knees only if the trunk stays straight from head to knees. It is a strength step, not permission to fold at the hips.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "Make it a moving plank", detail: "Set ribs down, glutes on, and quads tight before the first rep. The chest and hips should travel together.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Hands under the chest, not the face", detail: "At the bottom, forearms should look roughly vertical from the side. Hands too high turn the rep into a shoulder-crank.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Use the right angle", detail: "Incline builds the first strict rep. Decline increases shoulder and upper-chest load after regular push-ups are clean.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Sagging hips or piking up.", fix: "Regress to a higher incline and add hollow holds until the body line stays locked."),
                SkillGuideMistake(mistake: "Elbows flare to 90 degrees.", fix: "Turn the elbow pits slightly forward, screw the hands into the floor, and aim elbows diagonally back."),
                SkillGuideMistake(mistake: "Partial reps that never reach depth.", fix: "Use a target at chest height or raise the hands until full range is repeatable."),
                SkillGuideMistake(mistake: "Head reaches the floor first.", fix: "Keep the neck neutral and lower the whole torso as one piece.")
            ]
        )
    }

    private static func closePushGuide(skillId: String) -> SkillGuide {
        let isSphinx = skillId == "cal.sphinx-pushup"
        return SkillGuide(
            standard: isSphinx
                ? "A clean sphinx push-up starts in a forearm plank, presses through the forearms until the elbows fully extend, then returns under control without the hips rising or sagging."
                : "A clean diamond push-up uses close hands under the sternum, elbows tracking back near the ribs, chest reaching the hands, and a full lockout while the trunk stays in one plank line.",
            scoringNote: "This is close-grip pressing. Count it only if the elbow path and lockout stay strict; if the hands drift wide or the hips pike, it is no longer the intended skill.",
            assistance: [
                SkillGuideAssistance(name: "Close-Grip Incline Push-Up", detail: "Raise the hands and keep the same close elbow path. Lower the surface as the triceps catch up.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Eccentric Close-Grip Rep", detail: "Use a slow 3-5 second lower through the close-grip path, then reset from knees if needed.", icon: "metronome"),
                SkillGuideAssistance(name: "Triceps Extension", detail: "Band or dumbbell extensions add direct elbow-extension volume without more wrist-loaded push-ups.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "Elbows go back", detail: "Think triceps brushing the ribs. Flaring turns the movement into an awkward regular push-up.", icon: "arrow.down.backward"),
                SkillGuideTip(title: "Lockout matters", detail: "Finish with elbows straight and shoulders active. The last inch is the point of close-grip work.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Protect the wrists", detail: "Use push-up handles, parallettes, or a slightly wider hand shape if the classic diamond bothers the wrists.", icon: "cross.case.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hands too far forward.", fix: "Set the hands under the lower chest or sternum so the forearms can stack."),
                SkillGuideMistake(mistake: "Hips shoot up to finish.", fix: "Regress the angle and keep glutes squeezed through the press."),
                SkillGuideMistake(mistake: "Half lockout.", fix: "End every rep with straight elbows before starting the next descent.")
            ]
        )
    }

    private static func dipGuide(skillId: String) -> SkillGuide {
        let isBench = skillId == "cal.bench-dip"
        return SkillGuide(
            standard: isBench
                ? "A clean bench dip keeps hands on a stable bench behind the hips, elbows tracking back, shoulders controlled, hips close to the bench, and presses to full elbow lockout without bouncing."
                : "A clean parallel-bar dip starts in a locked support, shoulders depressed, torso controlled, lowers until the shoulders are at least level with or slightly below the elbows if mobility allows, then presses to a full stable lockout.",
            scoringNote: "Shoulder comfort sets the depth ceiling. Deeper is not better if the shoulder rolls forward or pinches; use the deepest controlled pain-free range.",
            assistance: [
                SkillGuideAssistance(name: "Support Hold", detail: "Hold the top position with elbows locked, shoulders down, and body still. This teaches the support you must return to after every rep.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Negative Dip", detail: "Lower for 3-5 seconds, step down, and reset. Keep shoulders packed instead of collapsing into the bottom.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Band-Assisted Dip", detail: "Use a band between the bars under the knees or feet so the range stays full and the shoulder position stays clean.", icon: "point.3.connected.trianglepath.dotted")
            ],
            tips: [
                SkillGuideTip(title: "Own support first", detail: "If the top support shakes or shoulders shrug, full dips will leak power and irritate joints.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Lean is a dial", detail: "A slight forward lean biases chest. A more upright torso biases triceps. Both still need controlled shoulders.", icon: "slider.horizontal.3"),
                SkillGuideTip(title: "Press the bars down", detail: "Think of pushing the bars toward the floor rather than lifting the body. It keeps shoulders active at lockout.", icon: "arrow.down.to.line")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Shrugging or sinking at the bottom.", fix: "Shorten range and practice support holds plus slow negatives until shoulders stay packed."),
                SkillGuideMistake(mistake: "Swinging the legs to escape the bottom.", fix: "Use band assistance and reset still between reps."),
                SkillGuideMistake(mistake: "Soft top position.", fix: "Pause one second at lockout on every rep.")
            ]
        )
    }

    private static func ringDipGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean ring dip starts in a still support with elbows locked, rings close to the body, and rings turned out at the top. Lower under control with rings tracking close, reach a controlled dip bottom, then press to a stable turned-out support without swinging or letting the rings flare wide.",
            scoringNote: "Ring dips are not just harder bar dips. The support position counts. If the rings drift wide, the top is unstable, or the turn-out disappears entirely, regress to support work.",
            assistance: [
                SkillGuideAssistance(name: "RTO Support Hold", detail: "Build 15-30 second rings-turned-out support holds before full reps. Palms rotate forward while elbows stay locked.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Foot-Assisted Ring Dip", detail: "Set rings low and keep toes lightly on the floor. Use the legs only enough to keep the rings close and the rep smooth.", icon: "figure.strengthtraining.functional"),
                SkillGuideAssistance(name: "Ring Dip Negative", detail: "Start in support, lower slowly, step down, and reset. Do not grind out ugly presses from a flared bottom.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Strict Bar Dip", detail: "Own stable bar dips first. Rings add instability; they should not be the first place you learn pressing depth.", icon: "rectangle.split.2x1")
            ],
            tips: [
                SkillGuideTip(title: "Rings brush the body", detail: "Keep rings close to the ribs through the descent and press. Wide rings turn the rep into a shoulder fight.", icon: "arrow.left.and.right"),
                SkillGuideTip(title: "Turn out at the top", detail: "The top support should finish with the rings turned out and elbows locked. That is the ring-specific standard.", icon: "rotate.right.fill"),
                SkillGuideTip(title: "Low reps, high quality", detail: "Ring dips degrade fast. Use small sets and longer rest so every rep teaches stability.", icon: "speedometer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Rings flare away from the torso.", fix: "Return to RTO support holds, foot-assisted reps, and slower negatives."),
                SkillGuideMistake(mistake: "Skipping the turn-out.", fix: "Pause at the top and rotate palms forward before each descent."),
                SkillGuideMistake(mistake: "Swinging through the set.", fix: "Reset to a dead-still support between reps or lower the rings for foot assistance.")
            ]
        )
    }

    private static func pikePushGuide(skillId: String) -> SkillGuide {
        let isElevated = skillId == "cal.elevated-pike-pushup"
        let isFloating = skillId == "cal.floating-pike-pushup"
        let name = isFloating ? "floating pike push-up" : (isElevated ? "elevated pike push-up" : "pike push-up")
        return SkillGuide(
            standard: "A clean \(name) stacks the hips high, keeps shoulders active, lowers the head between the hands into a tripod-like path, then presses back up by driving the floor away. The rep should feel like vertical pressing, not a regular push-up with hips slightly raised.",
            scoringNote: "Count reps only while the hips stay high and the head travels between the hands. If the body drifts backward or the elbows flare wide, the handstand-push-up pattern is not being trained.",
            assistance: [
                SkillGuideAssistance(name: "Box Pike Hold", detail: "Hold the pike shape with hips high and shoulders stacked before adding reps.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Partial Pike Push-Up", detail: "Use a shallow range first, then increase depth as the head path and elbow angle stay clean.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Elevated Pike", detail: "Raise the feet only after floor pike reps are clean. More height adds shoulder load fast.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Wall HSPU Negative", detail: "For advanced athletes, slow wall negatives teach the next vertical press without requiring a full press yet.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Push up, not back", detail: "Imagine pressing toward a handstand. If the hips shoot backward, the shoulders are escaping the load.", icon: "arrow.up"),
                SkillGuideTip(title: "Tripod bottom", detail: "Hands and head form a triangle at the bottom. Head landing in line with the hands usually means the path is too cramped.", icon: "triangle.fill"),
                SkillGuideTip(title: "Elevate slowly", detail: "Small increases in foot height can be a large jump in shoulder demand. Keep reps clean before chasing height.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips too low.", fix: "Walk the feet closer or use an elevated surface that lets the hips stack."),
                SkillGuideMistake(mistake: "Head drops in front of the hands.", fix: "Aim the crown between the hands and slightly forward into a tripod."),
                SkillGuideMistake(mistake: "Elbows flare wide.", fix: "Turn the elbow pits forward and track elbows diagonally back.")
            ]
        )
    }

    private static func handstandPushGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean handstand push-up starts from a stable handstand or wall handstand, hands around shoulder width, ribs tucked, lowers under control until the head lightly contacts the floor or pad, then presses to full lockout with the shoulders elevated and body line controlled.",
            scoringNote: "Wall-supported reps count for early progress. Freestanding reps are a separate mastery standard. Do not count kipping, crashing to the head, banana-back lockouts, or partial-range presses.",
            assistance: [
                SkillGuideAssistance(name: "Pike Push-Up", detail: "Build the vertical pressing path on the floor before taking the body upside down.", icon: "figure.strengthtraining.functional"),
                SkillGuideAssistance(name: "Elevated Pike Push-Up", detail: "Feet elevated increases shoulder load and bridges toward wall HSPU strength.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Wall Negative", detail: "Kick or wall-walk up, lower for 3-5 seconds to the head target, then come down safely.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Partial ROM HSPU", detail: "Use pads or ab mats to shorten range, then remove height gradually as full-range strength appears.", icon: "rectangle.stack.fill")
            ],
            tips: [
                SkillGuideTip(title: "Tripod, then press", detail: "At the bottom, hands and head form a triangle. This gives the shoulders room to press instead of folding straight down.", icon: "triangle.fill"),
                SkillGuideTip(title: "Toes point to the wall", detail: "In chest-to-wall work, the toes point toward the wall as a light line reference. Do not plant the heels or turn the feet away to prop up the rep.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Ribs stay tucked", detail: "The wall makes arching tempting. Keep glutes tight and ribs down so the lockout is a handstand, not a backbend.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Use strict volume carefully", detail: "HSPU overloads wrists, neck, and shoulders. Use low crisp sets and stop before reps become head-bounces.", icon: "cross.case.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Kipping off the wall.", fix: "Log it separately. For strict progress, use partial range or negatives until the press is honest."),
                SkillGuideMistake(mistake: "Crashing onto the head.", fix: "Add a pad, lower slower, and reduce range until the bottom is controlled."),
                SkillGuideMistake(mistake: "Banana-back lockout.", fix: "Practice chest-to-wall holds, hollow body work, and glute squeeze at the top.")
            ]
        )
    }

    private static func ninetyDegreePushGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean 90-degree push-up starts from a controlled handstand, leans forward into a bent-arm horizontal body line with elbows around 90 degrees, then presses back to handstand without kicking, piking, or losing shoulder control.",
            scoringNote: "This is not a deep handstand push-up. Count it only when the body reaches a clear horizontal bent-arm line and returns by pressing, not by throwing the legs.",
            assistance: [
                SkillGuideAssistance(name: "Deep HSPU Negative", detail: "Lower slowly past the normal head-touch range toward a bent-arm planche angle, then step down before collapse.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Bent-Arm Planche Hold", detail: "Build the horizontal bottom shape separately so the press has somewhere real to pass through.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Wall-Assisted 90-Degree Negative", detail: "Use a wall or spotter to control the line while learning the forward lean and shoulder load.", icon: "rectangle.portrait")
            ],
            tips: [
                SkillGuideTip(title: "Lean before you bend", detail: "The shoulders must travel forward past the wrists before the elbows bend. That shift moves the center of mass over the hands instead of turning the rep into a deep handstand push-up.", icon: "arrow.forward.circle.fill"),
                SkillGuideTip(title: "Hands under the balance point", detail: "At the 90-degree point, the hands sit near the body's center of mass with shoulders far forward. Feet, knees, hips, chest, and head stay off the floor.", icon: "arrow.up.forward"),
                SkillGuideTip(title: "Keep the body one piece", detail: "Ribs down, glutes on, legs together. Piking the hips turns the skill into a different press.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Use tiny volume", detail: "This is high-load wrist, elbow, and shoulder work. A few pristine attempts beat fatigued grinding.", icon: "speedometer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Only doing a deeper HSPU.", fix: "Add the forward shoulder lean and move the balance point over the hands before counting it as 90-degree work."),
                SkillGuideMistake(mistake: "Feet touch the floor in the bottom.", fix: "Regress to bent-arm planche holds or negatives until the legs can hover without piking."),
                SkillGuideMistake(mistake: "Kicking back to handstand.", fix: "Regress to negatives, bent-arm holds, or wall assistance until the press does the work."),
                SkillGuideMistake(mistake: "Hips fold in the bottom.", fix: "Shorten range and rebuild hollow tension through bent-arm planche progressions.")
            ]
        )
    }

    private static func clappingHandstandPushGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean clapping handstand push-up starts from a stable strict handstand push-up, presses explosively enough for both hands to leave the floor, claps once, catches under control, and returns to a tall handstand line.",
            scoringNote: "Release work only counts when the catch is safe and controlled. Do not count wall kicks, head bounces, partial claps, or catches that collapse the elbows or neck.",
            assistance: [
                SkillGuideAssistance(name: "Explosive Pike Push-Up", detail: "Practice fast pressing with the feet on the floor before taking release work upside down.", icon: "bolt.fill"),
                SkillGuideAssistance(name: "Partial ROM Power HSPU", detail: "Use pads to reduce range and train speed while keeping the same handstand line.", icon: "rectangle.stack.fill"),
                SkillGuideAssistance(name: "Handstand Pop-Off", detail: "From a short range, pop both hands lightly off the floor without clapping, then absorb cleanly.", icon: "arrow.up.forward")
            ],
            tips: [
                SkillGuideTip(title: "Strict strength first", detail: "A clap is a speed expression of strict HSPU strength. If strict reps are unstable, release reps are not ready.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Use the HSPU line", detail: "Practice from the same chest-to-wall position as the strict handstand push-up. Toes stay light on the wall, but the wall is only a line reference.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Clap near the support line", detail: "The hands pop just off the floor and meet close under the head and shoulders. Reaching forward turns the catch into a dive instead of a press.", icon: "hands.clap.fill"),
                SkillGuideTip(title: "Catch soft, then tall", detail: "Land with enough elbow bend to absorb, then push tall through the shoulders before the next attempt.", icon: "arrow.down.forward.circle.fill"),
                SkillGuideTip(title: "Singles are enough", detail: "Use crisp singles with long rest. Fatigue makes upside-down catches ugly fast.", icon: "timer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Using the wall as a launch kick.", fix: "Reduce range and keep the same chest-to-wall HSPU line. The clap comes from the press, not from flipping or kicking off the wall."),
                SkillGuideMistake(mistake: "Reaching the clap forward.", fix: "Keep the clap close to the original hand path, under the head and shoulders, so the catch lands back under the body."),
                SkillGuideMistake(mistake: "Catching stiff-armed.", fix: "Practice pop-offs and absorb with active shoulders before adding the clap."),
                SkillGuideMistake(mistake: "Clapping too low.", fix: "Train more launch height first. The hands need time to return safely.")
            ]
        )
    }

    private static func bentArmPressGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean bent-arm press starts from a controlled tripod, tuck, or straddle setup, shifts shoulders forward, floats the hips, then presses smoothly to handstand without jumping the legs or collapsing onto the head.",
            scoringNote: "Count only presses that move through shoulder strength and balance. A kick-up, headstand jump, or uncontrolled roll-through is not the same skill.",
            assistance: [
                SkillGuideAssistance(name: "Tripod Press Negative", detail: "Start in handstand, lower slowly through a bent-arm path to tripod or tuck, and step down cleanly.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Wall-Assisted Press", detail: "Use the wall as a light line guide while practicing the hip lift and shoulder press.", icon: "rectangle.portrait"),
                SkillGuideAssistance(name: "Tuck Press Drill", detail: "Float the knees tight to the chest before opening into handstand. A shorter lever makes the press teachable.", icon: "figure.core.training")
            ],
            tips: [
                SkillGuideTip(title: "Hips rise before legs", detail: "If the feet kick first, the press becomes a disguised kick-up. Lift the hips over the shoulders first.", icon: "arrow.up"),
                SkillGuideTip(title: "Head is light", detail: "The head can guide the tripod, but the arms and shoulders must carry the press.", icon: "scope"),
                SkillGuideTip(title: "Open late", detail: "Keep the tuck or straddle compact until the hips stack, then extend into the final handstand.", icon: "arrow.up.forward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Jumping off the feet.", fix: "Use a higher start, wall assistance, or negatives until the hips can float without a kick."),
                SkillGuideMistake(mistake: "Dumping weight into the head.", fix: "Push harder through the hands and reduce range until the neck stays unloaded."),
                SkillGuideMistake(mistake: "Arching into the finish.", fix: "Keep ribs tucked and arrive in a real handstand line before counting the rep.")
            ]
        )
    }

    private static func planchePushGuide(skillId: String) -> SkillGuide {
        let isTuck = skillId == "cal.tuck-planche-pushup"
        return SkillGuide(
            standard: isTuck
                ? "A clean tuck planche push-up starts from a real tuck planche, lowers without the feet touching, then presses back to locked elbows while the tuck, protraction, and forward shoulder lean stay intact."
                : "A clean pseudo-planche push-up keeps the body in one rigid hollow line while the hands sit near the hips, shoulders stay clearly forward of the wrists, elbows track back, and the shoulder blades stay pushed apart through the whole rep.",
            scoringNote: isTuck
                ? "Do not count reps that begin from a bent-arm planche, tap the feet on the floor, or press into a different top shape than the start."
                : "This is not a hard push-up with the hands a little low. Count reps only when the forward lean stays present at the bottom and top.",
            assistance: [
                SkillGuideAssistance(name: isTuck ? "Tuck Planche Negative" : "Planche Lean", detail: isTuck ? "Start in the hold and lower slowly to a bent-arm tuck position. Step down before form collapses, then rebuild the press separately." : "Hold locked elbows, protracted shoulders, posterior pelvic tilt, and a measurable forward lean before adding a push-up.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: isTuck ? "Band-Assisted Reps" : "Feet-Elevated Lean", detail: isTuck ? "Use hip assistance to keep the feet floating and elbows tracking back through the press." : "Elevating feet can make the shoulder angle more planche-specific, but only if protraction and hollow shape stay clean.", icon: isTuck ? "point.3.connected.trianglepath.dotted" : "arrow.up.to.line"),
                SkillGuideAssistance(name: "Partial ROM Lean Push-Up", detail: "Use a shallow range and keep the same shoulder lean. Increase depth only when lean survives the whole rep.", icon: "slider.horizontal.3")
            ],
            tips: [
                SkillGuideTip(title: "Protraction is non-negotiable", detail: "Spread the shoulder blades and push the floor away. Planche pressing collapses when the upper back relaxes.", icon: "arrow.left.and.right"),
                SkillGuideTip(title: "Lean is progressive load", detail: "Mark hand or shoulder position and move the shoulders farther forward over months, not random max attempts.", icon: "ruler.fill"),
                SkillGuideTip(title: "Wrists need prep", detail: "Turn fingers slightly out or back, warm wrists before heavy lean work, and use parallettes if flat palms become the limiter.", icon: "hand.raised.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Losing forward lean during the press.", fix: "Shorten the range or reduce lean until the shoulder position stays fixed."),
                SkillGuideMistake(mistake: isTuck ? "Feet brush the floor at the bottom." : "Piking hips to reduce load.", fix: isTuck ? "Use a band, parallettes, or less depth until the whole rep floats." : "Squeeze glutes, tuck ribs down, and return to a plank or hollow body line."),
                SkillGuideMistake(mistake: "Elbows flare wide.", fix: "Turn the elbow pits forward, bend elbows back, and reduce lean until the shoulders can control the path.")
            ]
        )
    }

    private static func plancheHoldGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "pl.tuck-planche":
            return SkillGuide(
                standard: "A clean tuck planche is held on locked elbows with shoulders forward of the hands, scapulae protracted and depressed, hips near shoulder height, knees tight to the chest, heels close to the glutes, and no knee support on the arms.",
                scoringNote: "Crow, crane, and frog stand do not count. The knees must float free, the elbows stay straight, and the hips cannot sink into a tucked L-sit.",
                assistance: [
                    SkillGuideAssistance(name: "Raised Planche Lean", detail: "Use a box or bench under the feet, lean forward with locked arms, and practice the exact shoulder and scapular position before trying to float.", icon: "arrow.up.right"),
                    SkillGuideAssistance(name: "One-Knee Float", detail: "From crane or supported tuck, lift one knee off the arm at a time. This teaches the no-knee-support standard without jumping straight to both legs.", icon: "1.circle.fill"),
                    SkillGuideAssistance(name: "Band-Assisted Tuck", detail: "Loop a band around the hips so you can hold the right shape longer without dumping into bent arms or low hips.", icon: "point.3.connected.trianglepath.dotted")
                ],
                tips: [
                    SkillGuideTip(title: "Push the bars away", detail: "Round the upper back by protracting hard. If the shoulder blades collapse together, the hold usually drops immediately.", icon: "arrow.left.and.right.circle.fill"),
                    SkillGuideTip(title: "Shoulders pass the hands", detail: "If the shoulders stack directly over the wrists, the feet cannot float without cheating somewhere else.", icon: "arrow.forward.circle.fill"),
                    SkillGuideTip(title: "Tuck tight before opening", detail: "A compact tuck shortens the lever. Open the knees only after the basic tuck is repeatable with the same shoulder position.", icon: "lock.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Bent elbows turn it into a bent-arm balance.", fix: "Regress to planche leans or one-knee floats. Straight-arm strength is the point of this node."),
                    SkillGuideMistake(mistake: "Hips hang below the shoulders.", fix: "Pull knees closer, posteriorly tilt the pelvis, and push harder through the shoulders before counting the hold."),
                    SkillGuideMistake(mistake: "Neck cranes up to find balance.", fix: "Look slightly ahead or between the hands and keep the head neutral so the trunk can stay rounded.")
                ]
            )
        case "pl.straddle-planche":
            return advancedPlancheGuide(
                name: "straddle planche",
                standard: "A clean straddle planche holds locked elbows, protracted shoulders, hips level with the shoulders, legs straight and wide, toes pointed, and a slightly hollow body line parallel to the floor.",
                scoring: "A wide straddle can be a valid bridge, but the body still has to stay horizontal. Do not count holds where the legs droop or the back arches to fake length.",
                bridge: "Advanced Tuck Planche",
                bridgeDetail: "Open the knees away from the chest while keeping the back controlled. This is the main bridge between tuck and straddle."
            )
        case "pl.half-lay-planche":
            return advancedPlancheGuide(
                name: "half-lay planche",
                standard: "A clean half-lay planche keeps the same locked-arm, protracted, horizontal planche line as the straddle while the legs move partway toward parallel, narrowing the lever without letting the hips drop.",
                scoring: "This is a bridge from straddle to full planche. Count it only when the legs narrow intentionally and the torso line remains unchanged.",
                bridge: "Narrow-Straddle Holds",
                bridgeDetail: "Start from a wide straddle and close the legs a few inches while preserving height and protraction."
            )
        case "pl.full-planche":
            return SkillGuide(
                standard: "A clean full planche is a straight-arm horizontal hold with hands as the only contact point, shoulders forward of the hands, scapulae strongly protracted and depressed, ribs down, pelvis tucked, glutes and quads squeezed, legs together, toes pointed, and the body roughly parallel to the floor.",
                scoringNote: "This node is the strict standard. Bent elbows, dropped hips, a banana back, or a brief uncontrolled float should not be counted as a full planche hold.",
                assistance: [
                    SkillGuideAssistance(name: "Band-Assisted Full Planche", detail: "Set the band at hip height and use only enough help to keep the real full-planche line. The band should teach shape, not hide collapse.", icon: "point.3.connected.trianglepath.dotted"),
                    SkillGuideAssistance(name: "Box-Supported Full Line", detail: "Place feet on a box at body-line height, lean shoulders forward, and press down as if trying to lift the feet.", icon: "shippingbox.fill"),
                    SkillGuideAssistance(name: "Straddle or Half-Lay Holds", detail: "Use the hardest prior lever you can hold cleanly for volume, then test the full line in short fresh attempts.", icon: "slider.horizontal.3")
                ],
                tips: [
                    SkillGuideTip(title: "The shoulders carry the skill", detail: "Full planche is not just core tension. The shoulders must stay forward, depressed, and protracted while the elbows remain locked.", icon: "arrow.forward.circle.fill"),
                    SkillGuideTip(title: "Hollow beats banana", detail: "Posterior pelvic tilt, ribs down, glutes tight, and quads locked keep the body from folding into a low-back arch.", icon: "circle.hexagongrid.fill"),
                    SkillGuideTip(title: "Train it fresh", detail: "High-skill straight-arm work belongs early in the session with long rests. Once the line changes, stop or regress.", icon: "speedometer")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Hips drop while the chest stays high.", fix: "Return to half-lay, straddle, or band assistance and rebuild the hollow line."),
                    SkillGuideMistake(mistake: "Elbows soften under load.", fix: "Reduce lever length and add straight-arm planche lean volume. Do not practice bent elbows as full planche."),
                    SkillGuideMistake(mistake: "Maxing the same hold every day.", fix: "Use two or three focused sessions per week with wrist prep, long rest, and lower-intensity support work between.")
                ]
            )
        default:
            return SkillGuide(
                standard: "A clean bent-arm planche keeps the body horizontal with legs extended, elbows bent around a strong dip angle, shoulders protracted, chest forward, and no elbow shelf wedged into the hips.",
                scoringNote: "This is a useful planche-adjacent strength skill, but it is not a substitute for straight-arm tuck, straddle, or full planche progress.",
                assistance: [
                    SkillGuideAssistance(name: "Elbow Lever", detail: "Use elbow lever work only as a body-line and balance bridge. The bent-arm planche gradually removes the hip shelf.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Planche Lean Push-Up", detail: "Build the forward shoulder pressure and bent-arm pressing strength before trying to float the legs.", icon: "arrow.forward.circle.fill"),
                    SkillGuideAssistance(name: "Band-Assisted Bent-Arm Hold", detail: "Use assistance at the hips so the body can stay horizontal while the shoulders learn the position.", icon: "point.3.connected.trianglepath.dotted")
                ],
                tips: [
                    SkillGuideTip(title: "Keep the line horizontal", detail: "The rep should look like a low flying plank, not a deep push-up with the legs dragging behind.", icon: "line.diagonal"),
                    SkillGuideTip(title: "Do not confuse paths", detail: "Bent-arm work builds pressing power, but straight-arm planche still needs locked-elbow leans and holds.", icon: "arrow.triangle.branch"),
                    SkillGuideTip(title: "Exit before collapse", detail: "Step down when hips start falling. A clean short hold teaches more than a long wrestle.", icon: "checkmark.seal.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Elbows wedge into the hips like an elbow lever.", fix: "Shift shoulders forward and let the arms support the body instead of using the hip shelf."),
                    SkillGuideMistake(mistake: "Bending so deep it becomes a paused push-up.", fix: "Use a stronger elbow angle and band assistance until the body floats."),
                    SkillGuideMistake(mistake: "Calling bent-arm progress full-planche progress.", fix: "Keep it as accessory strength while the straight-arm planche ladder remains the main measure.")
                ]
            )
        }
    }

    private static func advancedPlancheGuide(name: String, standard: String, scoring: String, bridge: String, bridgeDetail: String) -> SkillGuide {
        SkillGuide(
            standard: standard,
            scoringNote: scoring,
            assistance: [
                SkillGuideAssistance(name: bridge, detail: bridgeDetail, icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Tuck Push-Back", detail: "From tuck planche, push the knees back toward open tuck, half straddle, or one-leg planche for short controlled pulses.", icon: "arrow.backward.circle.fill"),
                SkillGuideAssistance(name: "Band-Assisted \(name.capitalized)", detail: "Use hip assistance to practice the real line without losing scapular protraction.", icon: "point.3.connected.trianglepath.dotted")
            ],
            tips: [
                SkillGuideTip(title: "Open gradually", detail: "Use intermediate lever steps rather than gambling on max holds. The jump between planche shapes is larger than it looks.", icon: "slider.horizontal.3"),
                SkillGuideTip(title: "Same shoulders, harder legs", detail: "The shoulder position should stay depressed, protracted, and forward while the legs make the lever harder.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Hips tell the truth", detail: "If hips drop below shoulder level, the lever is too long for today. Regress before the body learns a banana line.", icon: "line.diagonal")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Arching the lower back.", fix: "Posteriorly tilt the pelvis, squeeze glutes, and return to an easier lever if the hollow line disappears."),
                SkillGuideMistake(mistake: "Scapulae retract as the lever lengthens.", fix: "Add protraction holds and banded practice before unassisted attempts."),
                SkillGuideMistake(mistake: "Chasing long holds with a broken line.", fix: "Use two to five clean seconds, then accumulate volume at the prior progression.")
            ]
        )
    }

    private static func unilateralPushGuide(skillId: String) -> SkillGuide {
        let isOneArm = skillId == "cal.one-arm-pushup"
        return SkillGuide(
            standard: isOneArm
                ? "A clean one-arm push-up uses one hand under the shoulder or slightly inside, feet wide enough for balance, free hand off the floor, body controlled as one unit, chest reaches full depth, then the working arm presses to lockout without wild hip rotation."
                : "A clean archer push-up starts with wide hands, shifts bodyweight over one working arm, keeps the opposite arm long as a guide, reaches full depth on the working side, and presses back without both arms sharing the load equally.",
            scoringNote: "Unilateral pressing is about load shift plus anti-rotation. If the assisting arm does half the work or the torso spins open, regress the variation.",
            assistance: [
                SkillGuideAssistance(name: "Incline One-Arm Push-Up", detail: "Raise the working hand to reduce load while keeping the one-arm line honest.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Archer Push-Up", detail: "Use archers to bridge from bilateral reps to one-arm reps. The straight arm should guide, not press hard.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Eccentric One-Arm Rep", detail: "Lower slowly with one arm, then use both arms or knees to return. Keep rotation quiet.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Wide-Stance Plank Shift", detail: "Shift weight from side to side in a plank to build wrist, shoulder, and trunk tolerance.", icon: "figure.core.training")
            ],
            tips: [
                SkillGuideTip(title: "Wide feet are allowed", detail: "A wider base lets strength be the limiter instead of balance noise. Narrow later for mastery.", icon: "arrow.left.and.right"),
                SkillGuideTip(title: "Press through the floor", detail: "Drive the working palm down and slightly inward so the shoulder stays centered instead of dumping forward.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Train the weaker side first", detail: "Match the strong side to the weak side's clean reps. This skill exposes asymmetry fast.", icon: "equal.circle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips twist open to escape the bottom.", fix: "Raise the hand, widen the feet, and add slow eccentrics until rotation quiets down."),
                SkillGuideMistake(mistake: "Assisting arm secretly presses.", fix: "Use fingertips or a slider for the guide arm, or regress to incline archers."),
                SkillGuideMistake(mistake: "Partial depth.", fix: "Use an incline and a clear chest target until full range returns.")
            ]
        )
    }

    private static func explosivePushGuide(skillId: String) -> SkillGuide {
        let isClap = skillId == "cal.clapping-pushup"
        let isTriple = skillId == "cal.triple-clap-pushup"
        let name = isTriple ? "triple-clap push-up" : (isClap ? "clapping push-up" : "explosive push-up")
        return SkillGuide(
            standard: "A clean \(name) starts as a strict push-up, descends under control, then presses explosively enough for the hands to leave the floor. Land with soft elbows, return to the same plank line, and reset if the rhythm breaks.",
            scoringNote: "Power reps are neurological quality work. Count only reps with clear airtime, safe landing, and no hip-snap cheat.",
            assistance: [
                SkillGuideAssistance(name: "Incline Plyo Push-Up", detail: "Use hands on a box so you can learn fast intent and soft landing before floor-level power.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Explosive Push-Up", detail: "Hands leave the floor without a clap. Build consistent airtime before adding clap demands.", icon: "bolt.fill"),
                SkillGuideAssistance(name: "Eccentric + Fast Press", detail: "Lower for 2-3 seconds, pause, then press fast without leaving the floor. This builds the launch pattern.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Do power fresh", detail: "Train explosive reps early after warm-up. Fatigue turns power into slow sloppy pressing.", icon: "flame.fill"),
                SkillGuideTip(title: "Catch like a spring", detail: "Land with elbows slightly bent and shoulders active. Locked-arm catches are not worth the risk.", icon: "arrow.down.forward.circle.fill"),
                SkillGuideTip(title: "Small sets only", detail: "Use sets of 1-5. Stop when airtime, clap height, or landing quality drops.", icon: "speedometer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hip buck for fake airtime.", fix: "Return to incline plyo reps and keep the body as one plank."),
                SkillGuideMistake(mistake: "Stiff locked-elbow landing.", fix: "Practice lower-intensity releases and absorb with soft elbows."),
                SkillGuideMistake(mistake: "Too many reps after power fades.", fix: "End the set when the hands barely leave the floor.")
            ]
        )
    }

    private static func conditioningGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "co.bw-farmer-carry", "co.1.5x-farmer-carry", "co.2x-farmer-carry":
            let load = skillId == "co.2x-farmer-carry" ? "2x bodyweight" : (skillId == "co.1.5x-farmer-carry" ? "1.5x bodyweight" : "bodyweight")
            let heavy = skillId != "co.bw-farmer-carry"
            return SkillGuide(
                standard: "A clean farmer carry uses \(load) total load split evenly between hands unless the test states otherwise. Pick the implements from a braced hinge, stand tall, shoulders level, arms long, handles quiet, and walk without leaning, resting the load, or dropping early.",
                scoringNote: "Conditioning does not erase posture. Stop or regress if the spine rounds, shoulders tilt, grip opens unsafely, or the load starts swinging into the legs.",
                assistance: [
                    SkillGuideAssistance(name: heavy ? "Lighter Carry" : "Half-Bodyweight Carry", detail: heavy ? "Build from the previous carry standard with shorter courses before testing this load." : "Start around half to three-quarter bodyweight and add load after posture stays tall.", icon: "scalemass.fill"),
                    SkillGuideAssistance(name: "Farmer Hold", detail: "Stand with the load for 10-20 seconds before walking so grip and bracing learn the demand.", icon: "pause.circle.fill"),
                    SkillGuideAssistance(name: "Trap Bar Carry", detail: "Use a trap bar when available to keep loading symmetrical while building heavy carry tolerance.", icon: "rectangle.compress.vertical")
                ],
                tips: [
                    SkillGuideTip(title: "Brace before the pick", detail: "Wedge, grip, breathe, then stand. The carry starts before the first step.", icon: "lock.fill"),
                    SkillGuideTip(title: "Small fast steps", detail: "Short steps keep the load quiet and reduce side-to-side sway.", icon: "shoeprints.fill"),
                    SkillGuideTip(title: "Set down cleanly", detail: "The finish is not a crash. Hinge down and place the implements where they cannot hit the feet.", icon: "arrow.down.to.line")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Rounding to lift the handles.", fix: "Reduce load and treat the pickup like a strict deadlift."),
                    SkillGuideMistake(mistake: "Leaning or side-bending while walking.", fix: "Shorten the distance, lower load, and keep shoulders level."),
                    SkillGuideMistake(mistake: "Overstriding and swinging the load.", fix: "Use shorter steps and keep hands close to the sides.")
                ]
            )
        case "co.dead-hang-45", "co.dead-hang-60":
            let seconds = skillId == "co.dead-hang-60" ? 60 : 45
            return SkillGuide(
                standard: "A clean \(seconds)-second dead hang supports full bodyweight from the bar with arms fully extended, thumbs wrapped when possible, body quiet, feet off the floor, and no elbow bend or shoulder pain.",
                scoringNote: "Passive hang can count if shoulders tolerate it, but active shoulder control is preferred. Swinging, kicking, foot taps, or sharp pain end the test.",
                assistance: [
                    SkillGuideAssistance(name: "Feet-Assisted Hang", detail: "Keep toes lightly on a box to practice grip and shoulder position before full bodyweight time.", icon: "shoeprints.fill"),
                    SkillGuideAssistance(name: "Cluster Holds", detail: "Accumulate the target in smaller chunks, such as 3 x 20 seconds, before testing unbroken.", icon: "timer"),
                    SkillGuideAssistance(name: "Active Scap Hang", detail: "Practice pulling shoulders slightly down from the ears without bending the elbows.", icon: "arrow.down.circle.fill")
                ],
                tips: [
                    SkillGuideTip(title: "Wrap and settle", detail: "Set the grip before the clock starts and let the body become still.", icon: "hand.raised.fill"),
                    SkillGuideTip(title: "Long arms, quiet ribs", detail: "Reach long through the elbows while keeping enough trunk control to prevent swinging.", icon: "figure.hanging"),
                    SkillGuideTip(title: "Step down", detail: "Finish by stepping to support if possible. Do not turn the end into a hard drop.", icon: "arrow.down.to.line")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Over-gripping and burning out early.", fix: "Use a firm wrap without death-gripping the first seconds."),
                    SkillGuideMistake(mistake: "Swinging to survive.", fix: "Reset with shorter clean holds and lightly squeeze legs together."),
                    SkillGuideMistake(mistake: "Hanging through shoulder pain.", fix: "Use feet assistance and active hang work until the shoulder position is pain-free.")
                ]
            )
        case "co.sled-push":
            return SkillGuide(
                standard: "A clean sled push keeps a strong forward body angle, neutral spine, braced trunk, hands set on the sled, and short powerful steps that drive the floor backward. The sled should move continuously without twisting or upright collapse.",
                scoringNote: "The benchmark counts forward progress with posture. If the spine rounds, arms pump like a sprint, or the athlete stands upright to survive, reduce load or distance.",
                assistance: [
                    SkillGuideAssistance(name: "Light Sled March", detail: "Use a load that allows smooth first steps and a consistent body angle.", icon: "arrow.forward"),
                    SkillGuideAssistance(name: "Wall Lean March", detail: "Practice the forward lean and leg drive against a wall before loading the sled.", icon: "rectangle.portrait"),
                    SkillGuideAssistance(name: "Short Intervals", detail: "Break the course into shorter pushes so cadence and posture stay intact.", icon: "timer")
                ],
                tips: [
                    SkillGuideTip(title: "Push the floor behind you", detail: "Leg drive moves the sled. The arms connect you to it; they do not do the whole job.", icon: "bolt.fill"),
                    SkillGuideTip(title: "Build speed after movement", detail: "Get the sled rolling smoothly before trying to accelerate.", icon: "speedometer"),
                    SkillGuideTip(title: "Stay low late", detail: "Fatigue tries to pull you upright. Keep the lean and shorten steps instead.", icon: "line.diagonal")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Standing too upright.", fix: "Lower the load and rebuild the lean line."),
                    SkillGuideMistake(mistake: "Bouncing vertically.", fix: "Shorten steps and push backward through the floor."),
                    SkillGuideMistake(mistake: "Rounding the back.", fix: "Brace ribs and pelvis together before the sled moves.")
                ]
            )
        case "co.400m-row":
            return SkillGuide(
                standard: "A clean 400m row starts with straps snug, monitor set, damper or drag familiar, and full strokes: legs drive first, torso swings, arms finish; recovery returns arms, body, then legs. Finish without stopping or turning into frantic half-strokes.",
                scoringNote: "Damper at 10 is not a badge. Use a setting that lets power and stroke sequence stay clean for the whole sprint.",
                assistance: [
                    SkillGuideAssistance(name: "Technique Row", detail: "Row at 20-24 strokes per minute to rehearse legs-body-arms before sprinting.", icon: "metronome"),
                    SkillGuideAssistance(name: "100m Repeats", detail: "Use 4 x 100m or 2 x 200m to build sprint rhythm without form collapse.", icon: "timer"),
                    SkillGuideAssistance(name: "Rate Cap", detail: "Limit stroke rate until each drive stays connected and long.", icon: "speedometer")
                ],
                tips: [
                    SkillGuideTip(title: "Legs, body, arms", detail: "The drive starts with the legs. Pulling early with the arms wastes the strongest part of the stroke.", icon: "arrow.right"),
                    SkillGuideTip(title: "Recover in reverse", detail: "Hands away, body forward, then knees bend. This keeps the handle from crashing around the knees.", icon: "arrow.uturn.backward"),
                    SkillGuideTip(title: "Last 100 with shape", detail: "Lift rate near the finish without shortening into panic strokes.", icon: "flag.checkered")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Damper set too high by default.", fix: "Use a familiar drag and focus on force through the drive."),
                    SkillGuideMistake(mistake: "Arms pull before legs finish.", fix: "Pause-drill the sequence: legs, body, arms."),
                    SkillGuideMistake(mistake: "Rushing the slide.", fix: "Let the recovery be quick but organized: arms, body, legs.")
                ]
            )
        case "co.mile-sub-7", "co.5k-sub-22":
            let is5k = skillId == "co.5k-sub-22"
            return SkillGuide(
                standard: is5k
                    ? "A clean sub-22 5K covers 5 kilometers in 21:59 or faster, averaging slightly faster than 4:24 per kilometer or 7:05 per mile, with pacing controlled enough that the middle kilometers do not collapse."
                    : "A clean sub-7 mile covers one mile in 6:59 or faster, averaging faster than 1:45 per 400m lap or faster than 8.57 mph on a treadmill.",
                scoringNote: "Course, treadmill, and GPS differences matter. Use a measured route or calibrated treadmill when possible, and pace the whole effort instead of relying on one desperate finish.",
                assistance: [
                    SkillGuideAssistance(name: is5k ? "Goal-Pace 1K Repeats" : "Goal-Pace 400s", detail: is5k ? "Run 5 x 1K near goal pace with rest before attempting the full 5K." : "Run 4 x 400m around 1:45 with recovery before testing the mile.", icon: "timer"),
                    SkillGuideAssistance(name: "Tempo Run", detail: "Build the ability to hold uncomfortable but controlled pace without sprint mechanics breaking.", icon: "waveform.path.ecg"),
                    SkillGuideAssistance(name: "Relaxed Fast Strides", detail: "Use short fast strides to practice cadence, posture, and relaxed speed.", icon: "figure.run")
                ],
                tips: [
                    SkillGuideTip(title: "Start controlled", detail: is5k ? "The first kilometer should feel strong, not heroic. Protect the middle of the race." : "First lap around goal pace beats a panicked opening that ruins lap three.", icon: "speedometer"),
                    SkillGuideTip(title: "Run tall", detail: "Relax shoulders, keep arms driving forward and back, and land under the body instead of reaching.", icon: "figure.run"),
                    SkillGuideTip(title: "Commit before the end", detail: is5k ? "The move starts before the final kilometer, not only in the last straight." : "The third lap decides whether the kick has anything to work with.", icon: "flag.checkered")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Opening too fast.", fix: "Use split targets and let the first segment feel controlled."),
                    SkillGuideMistake(mistake: "Overstriding under fatigue.", fix: "Think quick feet under hips and relaxed shoulders."),
                    SkillGuideMistake(mistake: "Saving all effort for the finish.", fix: is5k ? "Hold focus through kilometers 3 and 4." : "Press lap three so lap four is a close, not a rescue.")
                ]
            )
        default:
            return SkillGuide(
                standard: "A clean 30-calorie Assault Bike effort starts with the seat adjusted so the knee has a soft bend at the bottom, torso tall, hands working the handles in sync with the legs, and calories earned continuously without coasting.",
                scoringNote: "The bike rewards power and rhythm. A wild opening sprint that collapses into coasting is not a better benchmark than a hard sustainable effort.",
                assistance: [
                    SkillGuideAssistance(name: "10-Cal Repeats", detail: "Use 3 x 10 calories with rest to practice output without dying in the first attempt.", icon: "timer"),
                    SkillGuideAssistance(name: "Smooth RPM Ride", detail: "Hold a steady cadence and learn how arms and legs share work before all-out testing.", icon: "speedometer"),
                    SkillGuideAssistance(name: "Arms/Legs Practice", detail: "Brief legs-only and arms-only segments teach the push-pull rhythm.", icon: "arrow.left.arrow.right")
                ],
                tips: [
                    SkillGuideTip(title: "Fit first", detail: "Set the seat before the clock. A cramped knee or rocking hip wastes power fast.", icon: "slider.horizontal.3"),
                    SkillGuideTip(title: "Settle after launch", detail: "Accelerate for a few seconds, then hold a hard pace you can finish.", icon: "bolt.fill"),
                    SkillGuideTip(title: "No coast finish", detail: "Push through the final calories until the monitor gives the result.", icon: "flag.checkered")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "All-out first 15 seconds.", fix: "Open hard but controlled, then settle before the fade starts."),
                    SkillGuideMistake(mistake: "Loose torso rocking.", fix: "Brace tall and let the limbs move around a stable trunk."),
                    SkillGuideMistake(mistake: "Arms only pull.", fix: "Push and pull the handles in rhythm with the pedal stroke.")
                ]
            )
        }
    }

    private static func legGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "ld.step-up":
            return stepUpGuide()
        case "ld.deep-squat":
            return deepSquatGuide()
        case "ld.glute-bridge", "ld.single-leg-glute-bridge":
            return gluteBridgeGuide(singleLeg: skillId == "ld.single-leg-glute-bridge")
        case "ld.split-squat", "ld.weighted-split-squat", "ld.bulgarian-split-squat", "ld.weighted-bss":
            return splitSquatGuide(skillId: skillId)
        case "ld.shrimp-squat", "ld.pistol-squat", "ld.weighted-pistol":
            return pistolPathGuide(skillId: skillId)
        case "ld.calf-raise", "ld.weighted-sl-calf":
            return calfGuide(weighted: skillId == "ld.weighted-sl-calf")
        case "ld.jumping-squat", "ld.box-jump":
            return legPowerGuide(boxJump: skillId == "ld.box-jump")
        case "ld.leg-extensions", "ld.sissy-squat":
            return quadIsolationGuide(sissy: skillId == "ld.sissy-squat")
        case "ld.flying-kickback", "ld.fire-hydrant":
            return hipAccessoryGuide(abduction: skillId == "ld.fire-hydrant")
        case "ld.nordic-hip-hinge", "ld.advancing-nordic-curl", "ld.nordic-curl":
            return nordicGuide(skillId: skillId)
        case "ld.floor-to-ceiling-squat":
            return floorToCeilingGuide()
        default:
            return squatBaseGuide()
        }
    }

    private static func squatBaseGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean squat base rep keeps the whole foot rooted, knees tracking with the toes, ribs stacked over the pelvis, and a controlled descent to the target depth before standing without knee cave or bounce.",
            scoringNote: "Depth only counts if foot pressure, knee tracking, and trunk control stay together. Use a box, counterweight, or smaller range before forcing ugly reps.",
            assistance: [
                SkillGuideAssistance(name: "Box Squat", detail: "Sit to a box or bench, pause, then stand without rocking. Lower the box over time as control improves.", icon: "square.fill"),
                SkillGuideAssistance(name: "Counterbalance Squat", detail: "Hold a light plate or kettlebell forward so the torso can stay upright while ankles and hips learn the bottom.", icon: "scalemass.fill"),
                SkillGuideAssistance(name: "Tempo Squat", detail: "Use a 3-second descent and 1-second pause. Tempo exposes heel lift and knee cave fast.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Tripod foot", detail: "Keep pressure through heel, big toe, and little toe. If one edge peels off the floor, the knee usually follows.", icon: "scope"),
                SkillGuideTip(title: "Knees follow toes", detail: "Let the knees travel in the same direction the toes point. Caving inward is a strength and control leak.", icon: "arrow.up.left.and.arrow.down.right"),
                SkillGuideTip(title: "Depth is earned", detail: "Use the deepest range you can control without heel lift, pelvic tuck, or pain, then expand it gradually.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Heels lift at the bottom.", fix: "Widen or slightly turn out the stance, use counterbalance work, and add ankle dorsiflexion drills."),
                SkillGuideMistake(mistake: "Knees collapse inward.", fix: "Slow the eccentric and push knees over the second or third toe."),
                SkillGuideMistake(mistake: "Bouncing out of range.", fix: "Pause in the bottom and use fewer reps until the position is owned.")
            ]
        )
    }

    private static func stepUpGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean step-up plants the whole lead foot on a stable box, drives mostly through that lead leg, stands fully tall on top, then steps down under control without dropping or pushing hard from the floor leg.",
            scoringNote: "Start with a lower box if form changes. The box is useful only when the lead leg, knee line, and controlled descent stay honest.",
            assistance: [
                SkillGuideAssistance(name: "Low Step", detail: "Use a low stair or box and make every rep smooth before raising the height.", icon: "arrow.down.to.line"),
                SkillGuideAssistance(name: "Hand-Supported Step-Up", detail: "Lightly touch a wall or rack for balance while the lead leg still supplies the strength.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Eccentric Step-Down", detail: "Stand on the box and lower the free foot slowly to the floor. This builds the control side of the rep.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Whole foot on the box", detail: "A half-foot plant turns the rep into a calf and balance scramble. Set the foot first, then drive.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Stand tall before stepping down", detail: "Finish the hip and knee extension on top. Do not rush the descent while still folded over.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Height follows control", detail: "A knee-height box is enough for most training. Higher is not better if the pelvis twists or the trail leg kicks.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Springing off the floor leg.", fix: "Lift the trailing toes or slow the start so the lead leg has to do the work."),
                SkillGuideMistake(mistake: "Knee dives inward on the box.", fix: "Lower the height and track the knee over the second toe."),
                SkillGuideMistake(mistake: "Dropping off the box.", fix: "Step down quietly. If you cannot control the descent, the height or fatigue is too high.")
            ]
        )
    }

    private static func deepSquatGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean deep squat hold keeps both feet flat, hips below knees, knees tracking with toes, spine long enough to breathe, and balance centered without grabbing the floor or collapsing into the joints.",
            scoringNote: "This is active mobility. Count the hold only while the position stays pain-free, foot-flat, and breathable.",
            assistance: [
                SkillGuideAssistance(name: "Heel-Elevated Hold", detail: "Use a small wedge or plate under the heels while ankle mobility catches up. Reduce elevation over time.", icon: "triangle.fill"),
                SkillGuideAssistance(name: "Counterbalance Hold", detail: "Hold a light weight in front to keep the torso upright and explore depth without falling backward.", icon: "scalemass.fill"),
                SkillGuideAssistance(name: "Squat Pry", detail: "At the bottom, gently shift side to side and use elbows inside knees to open hips without forcing pain.", icon: "arrow.left.and.right")
            ],
            tips: [
                SkillGuideTip(title: "Breathe in the bottom", detail: "If you cannot take slow breaths, the body sees the position as a threat instead of a usable range.", icon: "wind"),
                SkillGuideTip(title: "Feet tell the story", detail: "Heels, big toes, and little toes stay grounded. Rocking to one edge shows the missing mobility or balance line.", icon: "scope"),
                SkillGuideTip(title: "Use short daily doses", detail: "Frequent 30-60 second quality holds usually beat rare max-duration suffering.", icon: "calendar")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Forcing depth with heels up.", fix: "Elevate the heels temporarily and work ankle mobility instead of pretending the range is clean."),
                SkillGuideMistake(mistake: "Relaxing into a rounded slump.", fix: "Stay active: chest open, knees out, feet rooted, slow breathing."),
                SkillGuideMistake(mistake: "Holding through knee or hip pain.", fix: "Adjust stance, reduce depth, or use support. Mobility work should feel loaded, not sharp.")
            ]
        )
    }

    private static func gluteBridgeGuide(singleLeg: Bool) -> SkillGuide {
        let name = singleLeg ? "single-leg glute bridge" : "glute bridge"
        return SkillGuide(
            standard: "A clean \(name) drives through the heel, reaches full hip extension with ribs down, pauses in a glute squeeze, then lowers without arching the lumbar spine.",
            scoringNote: singleLeg ? "Both hips must rise level. If the pelvis twists or the hamstring cramps instantly, return to two-leg bridges and shorter holds." : "Do not count reps where the lower back creates the height instead of the glutes.",
            assistance: [
                SkillGuideAssistance(name: "Short-Lever Bridge", detail: "Bring heels closer to the hips and use a smaller range while learning the glute squeeze.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Top-Hold Bridge", detail: "Hold the top for 3-5 seconds with ribs down. This teaches lockout without lumbar extension.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Marching Bridge", detail: "Alternate lifting one foot briefly while hips stay level before committing to full single-leg reps.", icon: "figure.walk")
            ],
            tips: [
                SkillGuideTip(title: "Ribs down, hips up", detail: "The top position should feel like glutes closing the hip, not the spine bending backward.", icon: "figure.core.training"),
                SkillGuideTip(title: "Heel pressure matters", detail: "Driving through toes usually shifts work away from the glutes. Keep the foot planted and heel heavy.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Pause every rep", detail: "A one-second top squeeze makes the bridge honest and keeps it from becoming a momentum drill.", icon: "metronome")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Lower back arches at the top.", fix: "Tuck ribs down, squeeze glutes, and stop the rep at true hip extension."),
                SkillGuideMistake(mistake: "Hamstrings cramp immediately.", fix: "Move the foot slightly closer, reduce range, and practice top holds."),
                SkillGuideMistake(mistake: "Hips rotate in single-leg reps.", fix: "Use marching bridges or shorter single-leg holds until the pelvis stays level.")
            ]
        )
    }

    private static func splitSquatGuide(skillId: String) -> SkillGuide {
        let isBulgarian = skillId.contains("bss") || skillId.contains("bulgarian")
        let isWeighted = skillId.contains("weighted")
        let name = isBulgarian ? "Bulgarian split squat" : "split squat"
        return SkillGuide(
            standard: "A clean \(isWeighted ? "weighted " : "")\(name) uses a stable hip-width stance, front foot rooted, knee tracking over toes, controlled descent, and a front-leg drive to stand without bouncing off the rear leg.",
            scoringNote: "Single-leg work is only useful when both sides match depth and control. Let the weaker side set the load, height, and reps.",
            assistance: [
                SkillGuideAssistance(name: "Supported Split Squat", detail: "Use a wall, rack, or pole lightly for balance so strength work is not limited by wobble.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Short Range Split Squat", detail: "Start with a smaller depth and add range as the knee and hip tolerate it.", icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Front-Foot Elevated", detail: "Elevate the front foot slightly when you need more clean depth without folding forward.", icon: "arrow.up.to.line")
            ],
            tips: [
                SkillGuideTip(title: "Train-track stance", detail: "Feet should be hip-width apart, not on one tight line. The wider rail gives the pelvis somewhere stable to work from.", icon: "lines.measurement.horizontal"),
                SkillGuideTip(title: "Rear leg balances", detail: "The back leg is a kickstand, not the engine. If it pushes hard, lower load or use support.", icon: "scope"),
                SkillGuideTip(title: "Load after symmetry", detail: "Add dumbbells only after left and right reps have the same depth, tempo, and knee path.", icon: "scalemass.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Stance too narrow, balance all over the place.", fix: "Set feet on parallel rails and widen before adding reps."),
                SkillGuideMistake(mistake: "Rear foot drives the rep.", fix: "Slow down and think front heel through the floor."),
                SkillGuideMistake(mistake: "Load shortens depth.", fix: "Reduce weight until the bottom position matches the bodyweight version.")
            ]
        )
    }

    private static func pistolPathGuide(skillId: String) -> SkillGuide {
        let isShrimp = skillId == "ld.shrimp-squat"
        let isWeighted = skillId == "ld.weighted-pistol"
        let name = isShrimp ? "shrimp squat" : (isWeighted ? "weighted pistol squat" : "pistol squat")
        return SkillGuide(
            standard: isShrimp
                ? "A clean shrimp squat lowers on one leg until the rear knee lightly touches the floor, keeps the working heel planted, then stands without bouncing, twisting, or pushing from the rear leg."
                : "A clean \(name) lowers on one leg to full depth with the free leg off the floor, working foot flat, knee tracking over toes, then stands without bounce or hand assist.",
            scoringNote: "Do not chase the full variation before strength, ankle mobility, and balance are present. Box and assisted reps count as training, not as the full node.",
            assistance: [
                SkillGuideAssistance(name: "Box Pistol", detail: "Sit to a box, pause fully, then stand on one leg. Lower the box over weeks as control improves.", icon: "square.fill"),
                SkillGuideAssistance(name: "Counterweight", detail: "Hold a light plate or kettlebell forward to balance the torso while the leg builds range.", icon: "scalemass.fill"),
                SkillGuideAssistance(name: "Assisted Rail Rep", detail: "Use a strap, rack, or doorframe with minimal arm help. The arms guide balance; the leg still works.", icon: "hand.raised.fill")
            ],
            tips: [
                SkillGuideTip(title: "Control beats depth theater", detail: "A slightly higher controlled rep is more useful than collapsing into a low position you cannot leave.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "The ankle is part of the skill", detail: "If the heel lifts, train ankle range and use box pistols instead of forcing reps.", icon: "scope"),
                SkillGuideTip(title: "Use the free leg deliberately", detail: "Keep the free leg active and off the floor. If it drops, regress the range or use assistance.", icon: "figure.walk")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Bouncing out of the bottom.", fix: "Use paused box pistols and 3-second eccentrics until the bottom has strength."),
                SkillGuideMistake(mistake: "Heel rises or foot collapses.", fix: "Regress to assisted work and add ankle mobility before full-depth reps."),
                SkillGuideMistake(mistake: "Twisting to escape the hard point.", fix: "Use a higher box or counterweight and keep hips square.")
            ]
        )
    }

    private static func calfGuide(weighted: Bool) -> SkillGuide {
        SkillGuide(
            standard: weighted
                ? "A clean weighted single-leg calf raise starts from a controlled stretch, rises to the highest plantar-flexed position, pauses, and lowers slowly without the free leg assisting."
                : "A clean calf raise uses full range: heels lower under control, ankles rise as high as possible, top pauses briefly, and knees stay steady instead of bouncing.",
            scoringNote: "Calf reps are easy to fake. Count only full-range reps with a pause at the top and a controlled lower.",
            assistance: [
                SkillGuideAssistance(name: "Wall Balance", detail: "Lightly touch a wall so balance does not steal range from the ankle.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Tempo Calf Raise", detail: "Use a 2-second rise, 1-second top pause, and 3-second lower.", icon: "metronome"),
                SkillGuideAssistance(name: "Two-Up One-Down", detail: "Rise with both feet, shift to one foot, then lower slowly on one side.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Own both ends", detail: "The stretched bottom and high top both matter. Middle-range bouncing is mostly noise.", icon: "arrow.up.and.down"),
                SkillGuideTip(title: "Keep the ankle vertical", detail: "Avoid rolling toward the big toe or little toe as fatigue climbs.", icon: "scope"),
                SkillGuideTip(title: "Load slowly", detail: "Achilles and calf tissue like gradual jumps. Add load only after range stays full.", icon: "plus.circle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Bouncing short reps.", fix: "Add a top pause and slow lower. Reduce reps if range disappears."),
                SkillGuideMistake(mistake: "Rolling the ankle outward.", fix: "Use wall balance and keep pressure through the big toe mound."),
                SkillGuideMistake(mistake: "Adding load before single-leg control.", fix: "Build bodyweight single-leg reps first, then load in small steps.")
            ]
        )
    }

    private static func legPowerGuide(boxJump: Bool) -> SkillGuide {
        SkillGuide(
            standard: boxJump
                ? "A clean box jump starts from a balanced dip, extends hips, knees, and ankles together, lands softly on the box with full foot contact, stands tall, then steps down."
                : "A clean jumping squat hits a controlled squat depth, explodes straight up, lands softly with knees tracking toes, and absorbs into the next rep without collapsing.",
            scoringNote: "Power work ends when height, landing, or alignment drops. Do not turn sloppy jumps into conditioning reps.",
            assistance: [
                SkillGuideAssistance(name: "Snap-Down Landing", detail: "Practice landing in a soft quarter squat with knees tracking toes before adding height.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Low Box Jump", detail: "Use a box you can land on quietly without tucking knees desperately high.", icon: "square.fill"),
                SkillGuideAssistance(name: "Paused Squat Jump", detail: "Pause in the squat for one second, then jump. This removes bounce and builds true concentric power.", icon: "pause.circle.fill")
            ],
            tips: [
                SkillGuideTip(title: "Land like a loaded spring", detail: "Soft knees, full foot, quiet contact. Loud landings usually mean the joints absorbed what the muscles missed.", icon: "waveform.path.ecg"),
                SkillGuideTip(title: "Step down from boxes", detail: "Jumping down adds avoidable ankle and knee impact. Save elastic landings for drills that need them.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Full rest keeps power honest", detail: "Use short sets and enough rest. If the next jump is lower, the set is done.", icon: "timer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Choosing a box too high.", fix: "Use a lower box and land tall instead of winning height by folding into a deep tuck."),
                SkillGuideMistake(mistake: "Knees cave on landing.", fix: "Reduce height or reps and practice snap-downs with knees over toes."),
                SkillGuideMistake(mistake: "Turning jumps into fatigue work.", fix: "Keep sets small and stop when speed changes.")
            ]
        )
    }

    private static func quadIsolationGuide(sissy: Bool) -> SkillGuide {
        SkillGuide(
            standard: sissy
                ? "A clean sissy squat keeps hips extended, body long from knees to shoulders, heels lifted, knees traveling forward, and quads controlling the descent and return."
                : "A clean leg extension isolates knee extension: thigh stays still, lower leg reaches full lockout, quads squeeze, then the eccentric returns slowly.",
            scoringNote: "Quad-isolation work should feel controlled at the knee. Sharp pain, hip hinging, or bouncing means the range is too aggressive.",
            assistance: [
                SkillGuideAssistance(name: "Support Pole", detail: "Hold a rack or pole for balance so the quads, not fear, limit the set.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Short Range Reps", detail: "Use the pain-free arc first, then extend range over time.", icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Slow Eccentric", detail: "Lower for 3-5 seconds and return with control. Tendons adapt better to gradual loading.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Hips stay open", detail: "For sissy squats, do not sit back. The whole point is knee extension demand with the hip extended.", icon: "line.diagonal"),
                SkillGuideTip(title: "Earn knee travel", detail: "Forward knee travel is not the enemy, but it has to be progressed and controlled.", icon: "arrow.forward"),
                SkillGuideTip(title: "Use this as accessory work", detail: "Place hard quad isolation after main squats or single-leg work so it does not wreck skill quality.", icon: "list.bullet.clipboard")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hinging at the hips.", fix: "Use support and shorter range. Keep shoulders, hips, and knees in one long line."),
                SkillGuideMistake(mistake: "Dropping into the bottom.", fix: "Slow the eccentric and stop before control disappears."),
                SkillGuideMistake(mistake: "Training through sharp knee pain.", fix: "Reduce range, load, and volume. Quad burn is fine; joint pain is not the target.")
            ]
        )
    }

    private static func hipAccessoryGuide(abduction: Bool) -> SkillGuide {
        SkillGuide(
            standard: abduction
                ? "A clean fire hydrant keeps hands and knees stable, spine quiet, hips mostly square, and lifts the bent leg out to the side from the glute rather than rotating the whole trunk."
                : "A clean kickback keeps the trunk braced, extends the hip from the glute, reaches the leg back without lumbar arch, then returns under control.",
            scoringNote: "These are control accessories. Count reps only while the pelvis stays quiet and the target glute is doing the work.",
            assistance: [
                SkillGuideAssistance(name: "Quadruped Hold", detail: "Hold the top position for 2-3 seconds to learn the glute line before adding reps.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Mini-Band Rep", detail: "Add a light band only after the pelvis stays square without it.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Wall-Supported Standing Rep", detail: "Use standing hip abduction or extension when wrists dislike the quadruped setup.", icon: "figure.walk")
            ],
            tips: [
                SkillGuideTip(title: "Small range can be enough", detail: "Chasing height often turns into spine motion. Stop where the glute can still own it.", icon: "scope"),
                SkillGuideTip(title: "Brace before lifting", detail: "Set ribs and pelvis first, then move the leg. The torso should not get dragged around.", icon: "figure.core.training"),
                SkillGuideTip(title: "Use it to clean bigger lifts", detail: "These drills help knee tracking and hip control for step-ups, split squats, and pistols.", icon: "link")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Rotating the body for more height.", fix: "Lower the leg and pause where the pelvis stays still."),
                SkillGuideMistake(mistake: "Arching the lower back.", fix: "Brace ribs down and think glute squeeze, not foot to ceiling."),
                SkillGuideMistake(mistake: "Rushing activation work.", fix: "Use slow reps and top pauses. Speed hides whether the right muscle is working.")
            ]
        )
    }

    private static func nordicGuide(skillId: String) -> SkillGuide {
        let isFull = skillId == "ld.nordic-curl"
        let isAdvanced = skillId == "ld.advancing-nordic-curl"
        return SkillGuide(
            standard: isFull
                ? "A clean Nordic curl anchors the ankles, keeps a rigid line from knees to head, lowers under hamstring control, and returns without pushing off the hands."
                : "A clean \(isAdvanced ? "advanced " : "")Nordic hip hinge anchors the ankles, keeps the trunk braced, hinges forward under control, and returns without falling or using the hands as a crutch.",
            scoringNote: "Nordics create high eccentric hamstring load. Use low volume, long rest, and regress before the last inches turn into a fall.",
            assistance: [
                SkillGuideAssistance(name: "Band-Assisted Nordic", detail: "Anchor a band in front or overhead so it helps through the hardest range while you keep the same body line.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Eccentric Only", detail: "Lower slowly, catch with the hands, then push back to start. Over time, reduce the hand catch.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Hip-Hinge Regression", detail: "Break at the hips slightly to shorten the lever before returning to a straighter body line.", icon: "slider.horizontal.3")
            ],
            tips: [
                SkillGuideTip(title: "Anchor must be boring", detail: "If the feet shift, the nervous system will protect you by cutting power. Secure the ankles first.", icon: "lock.fill"),
                SkillGuideTip(title: "Hamstrings like gradual exposure", detail: "Start with a few quality reps. Soreness can be intense when volume jumps too fast.", icon: "exclamationmark.triangle.fill"),
                SkillGuideTip(title: "Keep the hips honest", detail: "A tiny hinge can be a planned regression. A sudden pike is the body escaping the load.", icon: "scope")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Falling through the bottom range.", fix: "Use a band, shorter range, or eccentric-only reps until every inch is controlled."),
                SkillGuideMistake(mistake: "Piking hard at the hips.", fix: "Choose a regression deliberately instead of letting the hips bail out mid-rep."),
                SkillGuideMistake(mistake: "Doing high volume too soon.", fix: "Keep early work to low-rep sets with recovery. This is potent eccentric work.")
            ]
        )
    }

    private static func floorToCeilingGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean floor-to-ceiling squat starts lying flat, rises to the feet without hand push-off, finds a squat base, then jumps vertically to touch a true overhead target before landing under control.",
            scoringNote: "This is a mythic power-and-coordination node. Count only reps with no side roll, no hand assist, clear jump target, and safe landing.",
            assistance: [
                SkillGuideAssistance(name: "No-Hands Stand-Up", detail: "Cross-legged or squat stand-ups build the transition without the ceiling-touch demand.", icon: "figure.stand"),
                SkillGuideAssistance(name: "Deck Squat", detail: "Roll to the upper back, return to the feet, and stand before trying the no-hands version.", icon: "arrow.triangle.2.circlepath"),
                SkillGuideAssistance(name: "Vertical Jump", detail: "Train separate high-quality jumps so the final touch is power, not panic.", icon: "arrow.up")
            ],
            tips: [
                SkillGuideTip(title: "Separate the pieces first", detail: "Floor rise, squat catch, jump, and landing all need ownership before linking them.", icon: "square.stack.3d.up"),
                SkillGuideTip(title: "Use a real target", detail: "Touching a measured mark keeps the rep honest and avoids vague almost-jumps.", icon: "scope"),
                SkillGuideTip(title: "Land before celebrating", detail: "The rep finishes when the landing is controlled. Wild landings do not count.", icon: "checkmark.seal.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Rolling sideways to stand.", fix: "Regress to no-hands stand-ups until the rise is symmetrical."),
                SkillGuideMistake(mistake: "Using hands on the floor.", fix: "Slow the transition and build mobility instead of turning it into a burpee."),
                SkillGuideMistake(mistake: "Jumping to an unmeasured target.", fix: "Set a clear mark and count only clean touches with controlled landings.")
            ]
        )
    }
}

// MARK: - QuickLogSheet
//
// Lightweight "I did some reps" capture path. Used when the user just wants
// to log a single set (e.g., "8 pull-ups in the gym") without launching a
// structured session. Awards 10 XP — smaller than a full session — and the
// 24h cap still gates it via SkillProgressService.canTrain on the parent.

private struct QuickLogSheet: View {
    let skillId: String
    let skillTitle: String
    let defaultReps: Int
    var isHoldBased: Bool = false
    var holdTargetSeconds: Int = 30
    var skillRank: SkillRank = .d
    var nodeState: NodeState = .locked

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    @State private var reps: Int = 0
    @State private var holdSeconds: Int = 0
    @State private var weightKg: Double = 0
    @State private var rpe: Int = 0
    @State private var isSubmitting: Bool = false
    @State private var submitErrorMessage: String? = nil
    @State private var isTimerRunning: Bool = false
    @State private var holdTimer: Timer?
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State private var presentationDetent: PresentationDetent = .medium

    private static let quickLogXP: Int = 10

    var body: some View {
        quickLogForm
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
        .fullScreenCover(item: $rewardSequence) { sequence in
            WorkoutRewardSequenceView(summary: sequence) {
                rewardSequence = nil
                dismiss()
            }
            .interactiveDismissDisabled(true)
        }
        .onDisappear { stopTimer() }
        .alert("Couldn't save set", isPresented: Binding(
            get: { submitErrorMessage != nil },
            set: { if !$0 { submitErrorMessage = nil } }
        )) {
            Button("Retry") { Task { await submit() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(submitErrorMessage ?? "Your set is still here. Try again when the connection is stable.")
        }
    }

    private var quickLogForm: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("QUICK LOG")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(skillTitle)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Log one set. \(QuickLogSheet.quickLogXP) XP.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 12) {
                    if isHoldBased {
                        holdCard
                    } else {
                        repsCard
                        weightCard
                    }
                    rpeCard
                }
                .padding(.horizontal, 4)
            }

            UnboundButton(
                title: isSubmitting ? "Saving Set" : "Log Set",
                icon: "checkmark",
                isEnabled: canSubmit && !isSubmitting
            ) {
                Task { await submit() }
            }
            .accessibilityIdentifier("skillQuickLog.submit")

            Button("Cancel") {
                stopTimer()
                dismiss()
            }
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textTertiary)
                .accessibilityIdentifier("skillQuickLog.cancel")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear {
            if !isHoldBased, reps == 0 { reps = defaultReps }
        }
    }

    private var canSubmit: Bool {
        isHoldBased ? holdSeconds > 0 : reps > 0
    }

    // MARK: - Hold (timer) card

    private var holdCard: some View {
        let progress: Double = holdTargetSeconds > 0
            ? min(1.0, Double(holdSeconds) / Double(holdTargetSeconds))
            : 0
        let met = holdSeconds >= holdTargetSeconds && holdTargetSeconds > 0

        return VStack(spacing: 14) {
            Text("HOLD")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            ZStack {
                Circle()
                    .stroke(Color.unbound.surfaceElevated, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        met ? Color.unbound.impact : Color.unbound.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
                    .shadow(
                        color: (met ? Color.unbound.impact : Color.unbound.accent).opacity(0.45),
                        radius: 8
                    )

                VStack(spacing: 2) {
                    Text(formatHold(holdSeconds))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("/ \(holdTargetSeconds)s")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 12) {
                Button {
                    toggleTimer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Start")
                    }
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                    .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    stopTimer()
                    holdSeconds = 0
                    UnboundHaptics.soft()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(.headline).weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                        .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private func toggleTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
        UnboundHaptics.medium()
    }

    private func startTimer() {
        isTimerRunning = true
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                holdSeconds += 1
            }
        }
    }

    private func stopTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        isTimerRunning = false
    }

    private func formatHold(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    // MARK: - Cards

    private var repsCard: some View {
        VStack(spacing: 6) {
            Text("REPS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 24) {
                roundIconButton(icon: "minus") {
                    if reps > 0 { reps -= 1; UnboundHaptics.soft() }
                }
                Text("\(reps)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(minWidth: 90)
                roundIconButton(icon: "plus") {
                    reps += 1; UnboundHaptics.soft()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEIGHT")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(weightKg > 0 ? formatKg(weightKg) : "Bodyweight")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(weightKg > 0 ? Color.unbound.textPrimary : Color.unbound.textTertiary)
            }

            HStack(spacing: 6) {
                ForEach([0.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0, 25.0], id: \.self) { value in
                    Button {
                        weightKg = value
                        UnboundHaptics.soft()
                    } label: {
                        Text(value == 0 ? "BW" : "\(formatKg(value))")
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(weightKg == value ? Color.unbound.bg : Color.unbound.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(weightKg == value ? Color.unbound.accent : Color.unbound.surfaceElevated)
                            )
                            .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var rpeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RPE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(rpe == 0 ? "Optional" : "\(rpe) / 10")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(rpe == 0 ? Color.unbound.textTertiary : Color.unbound.textPrimary)
            }

            HStack(spacing: 6) {
                ForEach([5, 6, 7, 8, 9, 10], id: \.self) { v in
                    Button {
                        rpe = (rpe == v) ? 0 : v
                        UnboundHaptics.soft()
                    } label: {
                        Text("\(v)")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .foregroundStyle(rpe == v ? Color.unbound.bg : Color.unbound.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(rpe == v ? Color.unbound.accent : Color.unbound.surfaceElevated))
                            .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Submit

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        submitErrorMessage = nil
        stopTimer()

        let now = Date()
        let userId = AuthService.shared.currentUserId ?? "anonymous"
        let set = LoggedSet(
            reps: isHoldBased ? 0 : reps,
            holdSeconds: isHoldBased ? holdSeconds : nil,
            weightKg: (isHoldBased || weightKg <= 0) ? nil : weightKg,
            rpe: rpe > 0 ? rpe : nil
        )

        // Snapshot user state BEFORE the write so RewardComputer can
        // diff for PRs, rank-ups, badges, and first-set detection.
        let preSnapshot = await RewardComputer.shared.before(
            skillId: skillId,
            skillRank: skillRank,
            nodeState: nodeState,
            currentLevel: SkillProgressService.shared.currentSkillProgress(for: skillId).currentLevel,
            isHoldBased: isHoldBased,
            userId: userId,
            badgeService: services.badges
        )
        let loggedExercises = [LoggedExercise(name: skillTitle, sets: [set])]
        let performanceLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: UUID().uuidString,
            userId: userId,
            skillId: skillId,
            skillTitle: skillTitle,
            startedAt: now,
            completedAt: now,
            durationSeconds: 0,
            exercises: loggedExercises
        )

        let completionResult: TrainingCompletionResult
        do {
            completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services,
                skillXPAwarded: QuickLogSheet.quickLogXP
            )
        } catch {
            isSubmitting = false
            submitErrorMessage = error.localizedDescription
            HapticManager.notification(.error)
            return
        }

        // Fan out to BadgeService so per-set unlocks fire. Returns the
        // newly-unlocked badges; the computer filters out anything that
        // was already unlocked at snapshot time.
        let triggerKey = isHoldBased ? "\(skillId).hold" : skillId
        let triggerReps = isHoldBased ? (set.holdSeconds ?? 0) : set.reps
        let unlocked = await services.badges.evaluate(
            trigger: .setCompleted(exerciseKey: triggerKey, reps: triggerReps)
        )

        // Post-write state for rank-up diff.
        let postLevel = SkillProgressService.shared.currentSkillProgress(for: skillId).currentLevel
        let postState = SkillProgressService.shared.nodeStates[skillId] ?? nodeState

        var summary = await RewardComputer.shared.after(
            snapshot: preSnapshot,
            skillTitle: skillTitle,
            bestSet: set,
            skillRankAfter: skillRank,
            nodeStateAfter: postState,
            currentLevelAfter: postLevel,
            xpGained: completionResult.skillXPGained,
            unlockedBadges: unlocked
        )
        summary.progression = completionResult.progressionReceipt

        UnboundHaptics.medium()

        isSubmitting = false
        presentationDetent = .large
        rewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: summary,
            fallbackXP: QuickLogSheet.quickLogXP,
            sourceName: "Quick Log"
        )
    }

    // MARK: - Helpers

    private func formatKg(_ kg: Double) -> String {
        if kg == floor(kg) {
            return "\(Int(kg))kg"
        }
        return String(format: "%.1fkg", kg)
    }

    private func roundIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.unbound.surfaceElevated))
                .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var roundedCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }
}
