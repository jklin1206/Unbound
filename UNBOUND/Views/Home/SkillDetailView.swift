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

    // MARK: - Body

    var body: some View {
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

                skillGuideSection
                    .padding(.top, 28)
                    .padding(.horizontal, 20)

                if shouldShowRequirements {
                    requirementsSection
                        .padding(.top, 28)
                        .padding(.horizontal, 20)
                }

                Color.clear.frame(height: 32)
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
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
        }
        .sheet(isPresented: $isSessionPresented) {
            SkillSessionView(skillId: node.id, skillTitle: node.title)
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
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isTrainChooserPresented) {
            trainChooserSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.unbound.bg)
        }
        .task(id: node.id) {
            await loadReadinessHistory()
        }
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
        let userId = AuthService.shared.currentUserId ?? "anonymous"
        let skillTier = UserSkillTierStore.shared.load(userId: userId).perSkill[node.id] ?? .initiate
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
            TierBadge(tier: skillTier)
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
        case .bodyweightRatio(let ratio):
            return "\(String(format: "%.2g", ratio))x bodyweight"
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
                rankFocusCard(active)
            }

            VStack(spacing: 0) {
                ForEach(Array(visibleRankRows(rows).enumerated()), id: \.element.id) { index, row in
                    rankPathRow(row, isLast: index == visibleRankRows(rows).count - 1)
                }
            }
            .padding(.vertical, 6)
            .background(roundedCardBackground)

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isRankPathExpanded.toggle()
                }
                UnboundHaptics.soft()
            } label: {
                HStack(spacing: 6) {
                    Text(isRankPathExpanded ? "Collapse ladder" : "Show all ranks")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.0)
                    Image(systemName: isRankPathExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.unbound.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
    }

    private struct RankPathDisplayRow: Identifiable {
        var id: SkillTier { tier }
        let tier: SkillTier
        let detail: String
        let isCleared: Bool
        let isCurrent: Bool
        let isFuture: Bool
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
                isFuture: !cleared && !current
            )
        }
    }

    private func visibleRankRows(_ rows: [RankPathDisplayRow]) -> [RankPathDisplayRow] {
        if isRankPathExpanded { return rows }
        guard let currentIndex = rows.firstIndex(where: { $0.isCurrent }) else {
            return Array(rows.suffix(3))
        }
        let lower = max(0, currentIndex - 1)
        let upper = min(rows.count - 1, currentIndex + 1)
        return Array(rows[lower...upper])
    }

    private func rankFocusCard(_ row: RankPathDisplayRow) -> some View {
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
            }

            if let plan = SkillTrainingPlanLibrary.plan(for: node.id), !row.isCleared {
                trainingChips(plan: plan, targetText: row.detail)
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
                        formSection
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

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
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
        id.replacingOccurrences(of: ".", with: "_") + "_info"
    }

    // MARK: - 7. Requirements (only when locked)

    private var shouldShowRequirements: Bool {
        let state = nodeStates[node.id] ?? .locked
        guard state == .locked else { return false }
        return !node.prereqs.isEmpty
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Requires")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(node.prereqs.enumerated()), id: \.offset) { gIdx, group in
                    ForEach(Array(group.nodeIds.enumerated()), id: \.offset) { _, pid in
                        prereqRow(id: pid)
                    }
                    if gIdx < node.prereqs.count - 1 {
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
    private func prereqRow(id: String) -> some View {
        let resolved = graph.node(id: id)
        let state = nodeStates[id] ?? .locked
        let met = (state == .achieved || state == .mastered)
        HStack(spacing: 12) {
            Image(systemName: met ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
                .frame(width: 18, alignment: .center)
            Text(resolved?.title ?? id)
                .font(Font.unbound.bodyM)
                .foregroundStyle(met ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let trainTitle = canTrain ? "Train" : "Trained Today"
        let trainIcon = canTrain ? "dumbbell.fill" : "checkmark.seal.fill"

        return UnboundButton(
            title: trainTitle,
            icon: trainIcon
        ) {
            UnboundHaptics.medium()
            isTrainChooserPresented = true
        }
    }

    // MARK: - Train chooser sheet

    private var trainChooserSheet: some View {
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let isGoal = skillProgress.isActiveGoal(nodeId: node.id)
        let goalCount = skillProgress.activeGoalIds.count
        let atCap = goalCount >= SkillProgressService.activeGoalCap
        let goalDisabled = atCap && !isGoal
        let goalTitle: String = {
            if isGoal { return "In Program" }
            if goalDisabled { return "Program Full (\(goalCount) / \(SkillProgressService.activeGoalCap))" }
            return "Add to Program"
        }()
        let goalIcon = isGoal ? "checkmark.circle.fill" : "plus.circle"

        return VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("TRAIN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(node.title)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                trainOptionRow(
                    title: goalTitle,
                    subtitle: isGoal
                        ? "Active in your weekly program"
                        : "Pin this skill to TODAY'S TRAINING",
                    icon: goalIcon,
                    isEnabled: !goalDisabled
                ) {
                    Task {
                        await SkillProgressService.shared.toggleActiveGoal(nodeId: node.id)
                        isTrainChooserPresented = false
                    }
                }

                trainOptionRow(
                    title: "Log a Set",
                    subtitle: "Quick capture — reps, weight, RPE",
                    icon: "plus.circle",
                    isEnabled: canTrain
                ) {
                    isTrainChooserPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isQuickLogPresented = true
                    }
                }

                trainOptionRow(
                    title: "Start Session",
                    subtitle: "Full guided workout for this skill",
                    icon: "dumbbell.fill",
                    isEnabled: canTrain
                ) {
                    isTrainChooserPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isSessionPresented = true
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
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
        case "pp.muscle-up":
            return SkillGuide(
                standard: "A clean bar muscle-up starts from an active hang, pulls high enough for the chest to travel over the bar, turns both elbows through together, then finishes in a stable straight-arm support.",
                scoringNote: "This regular muscle-up allows controlled hip drive. Zero-hip-drive reps belong to the later strict muscle-up node.",
                assistance: [
                    SkillGuideAssistance(
                        name: "Banded Muscle-Up",
                        detail: "Use the lightest band that preserves a smooth pull and turnover. Avoid bouncing out of the bottom.",
                        icon: "point.3.connected.trianglepath.dotted"
                    ),
                    SkillGuideAssistance(
                        name: "Low-Bar Transition",
                        detail: "Keep feet lightly assisted while drilling chest-over-hands timing and a clean press-out.",
                        icon: "arrow.triangle.branch"
                    ),
                    SkillGuideAssistance(
                        name: "Explosive Chest-to-Bar",
                        detail: "Build the pull height before full attempts. Low pulls create rushed, messy catches.",
                        icon: "arrow.up.forward"
                    )
                ],
                tips: [
                    SkillGuideTip(
                        title: "False grip helps the turnover",
                        detail: "A high wrist position means the hand is already partly ready for the straight-bar dip. It matters more as the rep gets stricter.",
                        icon: "hand.raised.fill"
                    ),
                    SkillGuideTip(
                        title: "Legs create timing",
                        detail: "Use one connected hollow-to-arch rhythm. The legs should create hip drive, not a bicycle kick or one-sided throw.",
                        icon: "figure.run"
                    ),
                    SkillGuideTip(
                        title: "Pull around the bar",
                        detail: "A muscle-up pull is not a normal pull-up. Pull high, keep the bar close, and let the chest travel forward over the hands.",
                        icon: "arrow.up.and.forward"
                    )
                ],
                mistakes: [
                    SkillGuideMistake(
                        mistake: "Pulling low and crashing into the bar.",
                        fix: "Return to explosive chest-to-bar work and banded reps until the transition has space."
                    ),
                    SkillGuideMistake(
                        mistake: "One elbow turns over before the other.",
                        fix: "Stop max attempts and drill assisted turnovers with both elbows moving through together."
                    )
                ]
            )
        default:
            return nil
        }
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
    @State private var isTimerRunning: Bool = false
    @State private var holdTimer: Timer?
    @State private var rewardSummary: RewardSummary? = nil

    private static let quickLogXP: Int = 10

    var body: some View {
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
                title: "Log Set",
                icon: "checkmark",
                isEnabled: canSubmit && !isSubmitting
            ) {
                Task { await submit() }
            }

            Button("Cancel") {
                stopTimer()
                dismiss()
            }
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear {
            if !isHoldBased, reps == 0 { reps = defaultReps }
        }
        .onDisappear { stopTimer() }
        .sheet(item: Binding(
            get: { rewardSummary.map { CelebrationItem(summary: $0) } },
            set: { rewardSummary = $0?.summary }
        )) { item in
            RewardCelebrationView(summary: item.summary) {
                rewardSummary = nil
                dismiss()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
    }

    /// Wrapper so RewardSummary (struct, not Identifiable) plays nice
    /// with sheet(item:) presentation.
    private struct CelebrationItem: Identifiable {
        let id = UUID()
        let summary: RewardSummary
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
        let log = SessionLog(
            id: UUID().uuidString,
            userId: userId,
            skillId: skillId,
            createdAt: now,
            durationSeconds: 0,
            exercises: [LoggedExercise(name: skillTitle, sets: [set])],
            xpAwarded: QuickLogSheet.quickLogXP
        )

        try? await services.database.create(log, collection: "sessionLogs", documentId: log.id)
        await SkillProgressService.shared.awardSessionXP(forNodeId: skillId, xpAmount: QuickLogSheet.quickLogXP)

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

        let summary = await RewardComputer.shared.after(
            snapshot: preSnapshot,
            skillTitle: skillTitle,
            bestSet: set,
            skillRankAfter: skillRank,
            nodeStateAfter: postState,
            currentLevelAfter: postLevel,
            xpGained: QuickLogSheet.quickLogXP,
            unlockedBadges: unlocked
        )

        UnboundHaptics.medium()

        if summary.hasContent {
            rewardSummary = summary
        } else {
            dismiss()
        }
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
