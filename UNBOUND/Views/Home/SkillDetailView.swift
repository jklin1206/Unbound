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

    @Environment(\.dismiss) var dismiss
    @Bindable var skillProgress = SkillProgressService.shared
    @ObservedObject var skinService = SkinService.shared

    @State var phase: Bool = false
    @State var presentedSheet: SkillDetailSheet?
    @State var isRankPathExpanded: Bool = false
    @State var recentExerciseHistory: [ExerciseLogEntry] = []
    @State var readinessHistoryLoaded: Bool = false
    @State var selectedGuideTab: SkillGuideTab = .form
    @State var userSkillTierState: UserSkillTierState = .empty
    @State var bodyweightKg: Double = 70

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
    func sheetView(_ sheet: SkillDetailSheet) -> some View {
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

    var skillSessionDraft: TrainingSessionDraft {
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
    var quickLogIsHoldBased: Bool {
        if case .hold = node.target { return true }
        return false
    }

    /// Hold target seconds derived from the node's primary requirement,
    /// or 30 if the node isn't hold-based (irrelevant in that case).
    var quickLogHoldTargetSeconds: Int {
        if case .hold(_, let seconds) = node.target { return seconds }
        return 30
    }

    /// Default rep target for the quick-log sheet. A sane default of 5 reps.
    var defaultRepsForQuickLog: Int {
        5
    }

    // MARK: - 1. Top nav

    var topNav: some View {
        HStack {
            backButton
            Spacer()
            bookmarkButton
        }
    }

    var backButton: some View {
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

    var bookmarkButton: some View {
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
    var heroBlock: some View {
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

    var currentSkillIconTint: Color {
        node.isMythic ? skinService.currentSkin.impactDecalColor : skinService.currentSkin.decalColor
    }

    // MARK: - 3. Title block

    var titleBlock: some View {
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
    func rankDescription(for rank: RankTier) -> String {
        switch rank {
        case .initiate, .novice: return "Beginner"
        case .apprentice, .forged: return "Intermediate"
        case .veteran, .master: return "Advanced"
        case .vessel, .unbound: return "Elite"
        case .ascendant: return "Mythic"
        }
    }

    // MARK: - 4. Progress strip

    var progressStrip: some View {
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

    func criterionSummary(_ criterion: TierCriterion) -> String {
        switch criterion {
        case .reps(let count, let exerciseName):
            return "\(count) \(displayExerciseName(exerciseName))"
        case .seconds(let seconds):
            return "\(seconds)-second hold"
        case .exerciseSeconds(let seconds, let exerciseName):
            return "\(seconds)s \(displayExerciseName(exerciseName)) hold"
        case .weightKg(let weight):
            return "\(WeightPlatePolicy.formatLoggedWeightWithUnit(weight, separator: " ")) working set"
        case .exerciseWeightKg(let weight, let exerciseName):
            return "\(WeightPlatePolicy.formatLoggedWeightWithUnit(weight, separator: " ")) \(displayExerciseName(exerciseName))"
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

    func displayExerciseName(_ name: String) -> String {
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
    func loadReadinessHistory() async {
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
    func loadUserSkillTierState() {
        guard let userId = AuthService.shared.currentUserId else {
            userSkillTierState = .empty
            return
        }
        userSkillTierState = UserSkillTierStore.shared.load(userId: userId)
    }

    @MainActor
    func loadBodyweight() async {
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

    // MARK: - 6. Skill guide section


    // MARK: - 5b. Legacy Next Beat card (kept for reference; not rendered)


    // MARK: - 7. Requirements (only when locked)


    // MARK: - Shared styling helpers

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline).weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
    }

    var roundedCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }

    // MARK: - Asset lookup
}
