import SwiftUI

// MARK: - UnboundSkillTreeTabView
//
// Full skill tree tab. Renders the user's archetype tree with live node
// state from SkillProgressService. Pinch-zoom / scroll navigation.

struct UnboundSkillTreeTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var profile: UserProfile?
    @State private var selectedNode: SkillNode?
    @State private var rankVM = SkillTreeViewModel()
    @Bindable private var skillProgress = SkillProgressService.shared
    @StateObject private var skinService = SkinService.shared
    @AppStorage("unbound.isRecalibrating") private var isRecalibrating: Bool = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    archetypeHero
                    patternSections
                    header
                    SkillGraphView(
                        graph: SkillGraph.shared,
                        nodeStates: liveStatesForFullGraph(),
                        nodeProgress: skillProgress.nodeProgress,
                        onNodeTap: { node in
                            UnboundHaptics.medium()
                            selectedNode = node
                        }
                    )
                    .padding(.vertical, 4)
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Your tree")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let userId = services.auth.currentUserId ?? "anonymous"
            profile = try? await services.user.fetchProfile(userId: userId)
            await SkillProgressService.shared.load(userId: userId)
            await rankVM.load(
                userId: userId,
                archetype: profile?.preferredArchetype ?? .vTaper
            )
        }
        .fullScreenCover(item: $selectedNode) { node in
            SkillDetailView(
                node: node,
                graph: SkillGraph.shared,
                nodeStates: liveStatesForFullGraph()
            )
        }
        .nodeUnlockOverlay(archetype: profile?.preferredArchetype ?? .vTaper)
        .skinUnlockToast()
        .task(id: profile?.preferredArchetype) {
            guard let archetype = profile?.preferredArchetype else { return }
            let userId = services.auth.currentUserId ?? "anonymous"
            _ = await skinService.evaluateUnlocks(userId: userId, archetype: archetype)
        }
    }

    // MARK: Archetype hero — aggregate rank + identity

    private var archetypeHero: some View {
        let archetype = profile?.preferredArchetype ?? .vTaper
        let rank = rankVM.archetypeRank
        return ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ARC RANK")
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textTertiary)

                    Text(archetype.displayName)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .tracking(1.2)

                    Text(archetype.characterTagline)
                        .font(Font.unbound.monoS)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)

                    Text("Your arc rank — aggregate of \(archetype.emphasisLifts.count) emphasis lifts")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)

                ZStack {
                    Hexagon().fill(Color.unbound.surfaceElevated)
                    Hexagon().strokeBorder(glowColor(for: rank), lineWidth: 2)
                        .shadow(color: glowColor(for: rank).opacity(0.55), radius: 10)
                    Text(rank.displayName)
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                .frame(width: 92, height: 92)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                ChamferedRectangle(inset: 8)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                ChamferedRectangle(inset: 8)
                    .stroke(Color.unbound.border, lineWidth: 1)
            )

            if isRecalibrating {
                Text("RECALIBRATING")
                    .font(Font.unbound.monoS)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.unbound.accent.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                    )
                    .padding(14)
            }
        }
    }

    // MARK: Movement-pattern sections

    @ViewBuilder
    private var patternSections: some View {
        if !rankVM.sections.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(rankVM.sections) { section in
                    patternSection(section)
                }
            }
        }
    }

    private func patternSection(_ section: SkillTreeViewModel.PatternSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: section.pattern.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(section.pattern.title.uppercased())
                    .font(Font.unbound.monoS)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                rankChip(section.aggregate, filled: section.aggregate >= .bPlus)
            }

            VStack(spacing: 6) {
                ForEach(section.ranks, id: \.id) { lift in
                    HStack(spacing: 10) {
                        Text(lift.displayName)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        rankChip(lift.currentRank, filled: lift.currentRank >= .bPlus)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        ChamferedRectangle(inset: 6)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        ChamferedRectangle(inset: 6)
                            .stroke(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func rankChip(_ rank: SubRank, filled: Bool) -> some View {
        let style = skinService.currentSkin.rankChipStyle
        return Text(rank.displayName)
            .font(Font.unbound.monoM)
            .foregroundStyle(filled ? style.text : Color.unbound.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(filled ? style.background : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(filled ? style.border : Color.unbound.border, lineWidth: 1)
            )
    }

    private func glowColor(for rank: SubRank) -> Color {
        if rank.ordinal >= SubRank.sMinus.ordinal {
            return skinService.currentSkin.impactColor
        }
        return skinService.currentSkin.primaryColor
    }

    private var progressionPathsLink: some View {
        NavigationLink {
            ProgressionLadderView()
                .environmentObject(services)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.unbound.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Progression Paths")
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Push · Pull · Single-leg · Core ladders")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("YOUR SKILL MAP")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.2)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
            bodyTierLink
        }
    }

    // MARK: Body tier deep-link
    //
    // Loads the latest BodyAnalysis → MuscleGroupTierState and pushes
    // BodyTierView. Shows an empty state if the user hasn't scanned yet.

    private var bodyTierLink: some View {
        NavigationLink {
            BodyTierLoaderView()
                .environmentObject(services)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 11, weight: .bold))
                Text("BODY")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.unbound.surface))
            .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // Old header content kept commented for reference — removed in Chunk 4.
    private var oldHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("PATH TO")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(activeTree.displayName)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .tracking(0.5)
            }
            Spacer()
        }
    }

    private var activeTree: SkillTree {
        SkillTree.tree(for: profile?.preferredArchetype ?? .vTaper)
    }

    /// Live state from SkillProgressService, with spawn-point nodes
    /// seeded to .attempting if nothing has been recorded yet. Operates
    /// over the full SkillGraph (not a filtered subset).
    private func liveStatesForFullGraph() -> [String: NodeState] {
        var states = skillProgress.nodeStates
        let archetype = profile?.preferredArchetype ?? .vTaper
        let spawnIds = Set(ArchetypeSpawnPoints.nodeIds(for: archetype))
        for node in SkillGraph.shared.nodes where states[node.id] == nil {
            states[node.id] = spawnIds.contains(node.id) ? .attempting : .locked
        }
        return states
    }
}

// Legacy `SkillNodeDetailSheet` removed in Phase 3a — the full-screen
// `SkillDetailView` replaces it. Presenters now use `.fullScreenCover(item:)`.
