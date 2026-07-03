import SwiftUI

/// The unified, tabbed rank-detail screen. One screen for BOTH ranked exercises
/// and skills: a custom top bar, a tier-tinted hero, a pinned underline tab bar,
/// and three panes:
/// - Overview: reference (muscle map, equipment, technique guide).
/// - Rank: a current-rank showcase + Log a Set + the inline rank-up reveal.
/// - Stats: PRs + progression graph + derived stats + attempts history.
/// The three panes share one scroll; switching tabs resets it to the top.
struct RankDetailView: View {
    @State private var vm: RankDetailViewModel
    @State private var selectedTab: RankDetailTab
    @State private var showStopTrainingDialog = false
    @State private var showSwapTrainingDialog = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    /// Optional callback fired after a successful log, so the library can reload
    /// its ranks. The real logging flow lands with the Overview/Stats tabs.
    private let onLogged: (() async -> Void)?

    private static let topAnchor = "rank-detail-top"

    // MARK: - Inits (mirror the view model)

    init(
        row: ProgramRankLibraryRow,
        initialTab: RankDetailTab = .overview,
        onLogged: (() async -> Void)? = nil
    ) {
        _vm = State(initialValue: RankDetailViewModel(row: row))
        _selectedTab = State(initialValue: initialTab)
        self.onLogged = onLogged
    }

    init(
        node: SkillNode,
        graph: SkillGraph,
        nodeStates: [String: NodeState],
        initialTab: RankDetailTab = .overview,
        onLogged: (() async -> Void)? = nil
    ) {
        _vm = State(initialValue: RankDetailViewModel(node: node, graph: graph, nodeStates: nodeStates))
        _selectedTab = State(initialValue: initialTab)
        self.onLogged = onLogged
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            hero
                                .padding(.top, 8)
                                .id(Self.topAnchor)

                            if vm.isSkillEntry, let node = vm.skillNode {
                                programFocusCTA(node: node)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                            }

                            Section {
                                tabContent
                                    .padding(.horizontal, 20)
                                    .padding(.top, 18)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Color.clear.frame(height: 36)
                            } header: {
                                // Pinned so tab switching stays reachable while long
                                // panes (Overview/Stats) scroll under it.
                                UnderlineTabBar(
                                    tabs: RankDetailTab.allCases,
                                    title: \.title,
                                    selection: $selectedTab
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                                .background(Color.unbound.bg)
                            }
                        }
                    }
                    // Switching tabs resets the shared scroll to the top so a deep
                    // scroll in one pane never lands you in a short pane's blank space.
                    .onChange(of: selectedTab) { _, _ in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            proxy.scrollTo(Self.topAnchor, anchor: .top)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await vm.load(services: services)
        }
    }

    // MARK: - 1. Custom top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text(vm.title)
                .font(Font.unbound.bodyLStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            if vm.isSkillEntry, let node = vm.skillNode {
                trainButton(node: node)
            }

            if !(vm.row?.isRankHidden ?? false) {
                Image(vm.displayedTier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .shadow(color: vm.tint.opacity(0.35), radius: 6)
                    .accessibilityLabel("\(vm.displayedTier.displayName) rank")
            }
        }
    }

    /// The action that puts a skill INTO the user's program: toggles it as a
    /// Program Focus, which routes weekly rung-resolved drill blocks into
    /// training days via ProgramScheduler + DailyWorkoutResolver. Once the
    /// skill is training, this CTA disappears — the quiet top-bar dumbbell
    /// toggle carries state and removal, so the screen never sits under a
    /// persistent status banner. At the 3-slot cap the CTA stays ENABLED as a
    /// swap: it lists the three training skills and replaces the chosen one,
    /// so switching never requires hunting down the old skill to deselect it.
    /// Hidden while prereqs are locked.
    @ViewBuilder
    private func programFocusCTA(node: SkillNode) -> some View {
        let progress = SkillProgressService.shared
        let isFocus = progress.isProgramFocus(nodeId: node.id)
        let atCap = progress.programFocusIds.count >= SkillProgressService.programFocusCap
        if !isFocus, progress.isNodeTrainable(nodeId: node.id) {
            Button {
                UnboundHaptics.medium()
                if atCap {
                    showSwapTrainingDialog = true
                } else {
                    Task { await SkillProgressService.shared.toggleProgramFocus(nodeId: node.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14, weight: .bold))
                        .accessibilityHidden(true)
                    Text(atCap ? "SWAP INTO TRAINING" : "TRAIN THIS SKILL")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(atCap ? "Swap into training" : "Train this skill")
            .accessibilityIdentifier("rankDetail.trainThisSkill")
            .confirmationDialog(
                "All 3 training slots are in use",
                isPresented: $showSwapTrainingDialog,
                titleVisibility: .visible
            ) {
                ForEach(currentFocusChoices(), id: \.id) { choice in
                    Button("Replace \(choice.title)") {
                        UnboundHaptics.medium()
                        Task {
                            await SkillProgressService.shared.toggleProgramFocus(nodeId: choice.id)
                            await SkillProgressService.shared.toggleProgramFocus(nodeId: node.id)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pick which skill \(node.title) should replace.")
            }
        }
    }

    /// Quiet top-bar toggle mirroring the old Target scope button: accent-lit
    /// while the skill is a Program Focus. Tapping it while training asks
    /// plainly before stopping — the lit icon alone wasn't a readable
    /// "stop training" affordance.
    private func trainButton(node: SkillNode) -> some View {
        let isFocus = SkillProgressService.shared.isProgramFocus(nodeId: node.id)
        return Button {
            UnboundHaptics.soft()
            if isFocus {
                showStopTrainingDialog = true
            } else {
                Task { await SkillProgressService.shared.toggleProgramFocus(nodeId: node.id) }
            }
        } label: {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isFocus ? Color.unbound.accent : Color.unbound.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(
                        isFocus
                            ? Color.unbound.accent.opacity(0.18)
                            : Color.unbound.surfaceElevated.opacity(0.9)
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        isFocus ? Color.unbound.accent.opacity(0.7) : Color.clear,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFocus ? "Stop training this skill" : "Train this skill")
        .accessibilityIdentifier("rankDetail.trainToggle")
        .confirmationDialog(
            "\(vm.title) is in training",
            isPresented: $showStopTrainingDialog,
            titleVisibility: .visible
        ) {
            Button("Stop training", role: .destructive) {
                UnboundHaptics.medium()
                Task { await SkillProgressService.shared.toggleProgramFocus(nodeId: node.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its drills leave your weekly sessions. You can add it back anytime.")
        }
    }

    /// The three skills currently in training, resolved to titles for the
    /// swap dialog. Sorted for a stable button order.
    private func currentFocusChoices() -> [(id: String, title: String)] {
        SkillProgressService.shared.programFocusIds
            .compactMap { id -> (id: String, title: String)? in
                guard let node = SkillGraph.shared.node(id: id) else { return nil }
                return (id: id, title: node.title)
            }
            .sorted { $0.title < $1.title }
    }

    // MARK: - 2. Tier-tinted hero

    private var hero: some View {
        ZStack {
            Circle()
                .fill(vm.tint.opacity(0.18))
                .frame(width: 188, height: 188)
                .blur(radius: 44)

            heroArtwork
        }
        .frame(height: 196)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var heroArtwork: some View {
        if let assetName = vm.visualAssetName {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 172, height: 172)
                .shadow(color: Color.black.opacity(0.55), radius: 10)
        } else {
            Image(vm.displayedTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .shadow(color: vm.tint.opacity(0.5), radius: 24)
        }
    }

    // MARK: - 3. Tab content (each pane lives in its own file)

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview: RankDetailOverviewTab(vm: vm)
        case .rank:     RankDetailRankTab(vm: vm, onLogged: onLogged)
        case .stats:    RankDetailStatsTab(vm: vm)
        }
    }
}

#if DEBUG
/// DEBUG harness for the repeatable graded-attempt flow. Opens the rank detail
/// straight on the Rank tab so the showcase + blind ruler + attempt reveal can be
/// screenshotted in isolation. `RANK_DETAIL_DEMO_NODE` picks the node (default
/// pp.pullup); `RANK_DEMO_REVEAL=newbest|attempt` overlays a sample reveal so both
/// eyebrow states are checkable without a live login.
struct RankDetailDemoHarness: View {
    @State private var ready = false

    private var nodeId: String {
        ProcessInfo.processInfo.environment["RANK_DETAIL_DEMO_NODE"] ?? "pp.pullup"
    }

    private var initialTab: RankDetailTab {
        switch ProcessInfo.processInfo.environment["RANK_DEMO_TAB"] {
        case "overview": return .overview
        case "stats": return .stats
        default: return .rank
        }
    }

    private var sampleReveal: ProgramRankAttemptReveal? {
        switch ProcessInfo.processInfo.environment["RANK_DEMO_REVEAL"] {
        case "newbest":
            return ProgramRankAttemptReveal(attemptSummary: "12 reps", tier: .veteran, previousTier: .forged)
        case "attempt":
            return ProgramRankAttemptReveal(attemptSummary: "6 reps", tier: .forged, previousTier: .veteran)
        default:
            return nil
        }
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if ready, let node = SkillGraph.shared.node(id: nodeId) {
                RankDetailView(
                    node: node,
                    graph: SkillGraph.shared,
                    nodeStates: SkillProgressService.shared.nodeStates,
                    initialTab: initialTab
                )
            } else if ready {
                Text("Unknown node: \(nodeId)")
                    .foregroundStyle(Color.unbound.textPrimary)
            } else {
                ProgressView().tint(.white)
            }

            if let sampleReveal {
                ProgramRankAttemptRevealOverlay(reveal: sampleReveal) {}
            }
        }
        // Bootstrap a signed-in dev account first so a real "Get Your Rank" tap
        // actually grades + persists (pair with --unbound-dev-fresh-login for a
        // clean climb). Gating on `ready` guarantees the user exists before the
        // detail's load runs.
        .task {
            await DevBuildBootstrapper.ensureReady()
            ready = true
        }
    }
}
#endif
