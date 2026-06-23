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
    @State private var selectedTab: RankDetailTab = .overview

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    /// Optional callback fired after a successful log, so the library can reload
    /// its ranks. The real logging flow lands with the Overview/Stats tabs.
    private let onLogged: (() async -> Void)?

    private static let topAnchor = "rank-detail-top"

    // MARK: - Inits (mirror the view model)

    init(row: ProgramRankLibraryRow, onLogged: (() async -> Void)? = nil) {
        _vm = State(initialValue: RankDetailViewModel(row: row))
        self.onLogged = onLogged
    }

    init(
        node: SkillNode,
        graph: SkillGraph,
        nodeStates: [String: NodeState],
        onLogged: (() async -> Void)? = nil
    ) {
        _vm = State(initialValue: RankDetailViewModel(node: node, graph: graph, nodeStates: nodeStates))
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
