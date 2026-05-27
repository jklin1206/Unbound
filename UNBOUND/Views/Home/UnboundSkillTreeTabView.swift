import SwiftUI

// MARK: - UnboundSkillTreeTabView
//
// Full skill tree tab. Renders the universal skill tree with live node
// state from SkillProgressService. Pinch-zoom / scroll navigation.

struct UnboundSkillTreeTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var profile: UserProfile?
    @State private var selectedNode: SkillNode?
    @State private var showCosmetics: Bool = false
    @State private var rankVM = SkillTreeViewModel()
    @Bindable private var skillProgress = SkillProgressService.shared
    @StateObject private var skinService = SkinService.shared
    @AppStorage("unbound.isRecalibrating") private var isRecalibrating: Bool = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    treeCosmeticsAccess

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UnboundHaptics.soft()
                    showCosmetics = true
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(skinService.currentSkin.primaryColor)
                }
                .accessibilityLabel("Skill tree cosmetics")
                .accessibilityHint("Opens cosmetic themes for the skill tree")
            }
        }
        .task {
            let userId = services.auth.currentUserId ?? "anonymous"
            profile = try? await services.user.fetchProfile(userId: userId)
            await SkillProgressService.shared.load(userId: userId)
            await rankVM.load(userId: userId)
        }
        .fullScreenCover(item: $selectedNode) { node in
            SkillDetailView(
                node: node,
                graph: SkillGraph.shared,
                nodeStates: liveStatesForFullGraph()
            )
        }
        .sheet(isPresented: $showCosmetics) {
            NavigationStack {
                SkinPickerView()
                    .environmentObject(services)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
        .nodeUnlockOverlay()
        .skinUnlockToast()
        .task {
            let userId = services.auth.currentUserId ?? "anonymous"
            _ = await skinService.evaluateUnlocks(userId: userId)
        }
    }

    private var treeCosmeticsAccess: some View {
        Button {
            UnboundHaptics.soft()
            showCosmetics = true
        } label: {
            HStack(spacing: 12) {
                cosmeticSwatch
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("TREE COSMETIC")
                        .font(Font.unbound.monoS)
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(skinService.currentSkin.displayName.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                }

                Spacer()

                Text("\(skinService.unlockedSkins.count)/\(SkillTreeSkin.allCases.count)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(skinService.currentSkin.primaryColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(skinService.currentSkin.primaryColor.opacity(0.14)))

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(skinService.currentSkin.primaryColor.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Current skill tree cosmetic: \(skinService.currentSkin.displayName)")
        .accessibilityHint("Opens skill tree cosmetic themes")
    }

    private var cosmeticSwatch: some View {
        ZStack {
            if UIImage(named: skinService.currentSkin.backgroundAssetName) != nil {
                Image(skinService.currentSkin.backgroundAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .contrast(skinService.currentSkin.backgroundAssetContrast)
                    .opacity(skinService.currentSkin.backgroundAssetOpacity)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(skinService.currentSkin.nodeGradient)
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(skinService.currentSkin.mapBackground)
                .blendMode(.screen)
            Image(systemName: "hexagon.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(skinService.currentSkin.decalColor)
                .shadow(color: skinService.currentSkin.impactDecalColor.opacity(0.55), radius: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Build-identity hero — aggregate rank

    private var archetypeHero: some View {
        let rank = rankVM.aggregateRank
        return ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ARC RANK")
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textTertiary)

                    Text("Your Build")
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .tracking(1.2)

                    Text("Aggregate rank across emphasis lifts")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)

                ZStack {
                    Hexagon().fill(Color.unbound.surfaceElevated)
                    Hexagon().strokeBorder(glowColor(for: rank), lineWidth: 2)
                        .shadow(color: glowColor(for: rank).opacity(0.55), radius: 10)
                    VStack(spacing: 5) {
                        Image(rank.title.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                        Text(rank.title.displayName.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(0.7)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                    }
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
        return Text(rank.title.displayName.uppercased())
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(filled ? style.text : Color.unbound.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
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
        rank.title.rewardTint
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

    // Body tier link removed — BodyTierView deleted in scan-redesign-v2.
    // Body visualization is a future pass.
    private var bodyTierLink: some View {
        EmptyView()
    }

    /// Live state from SkillProgressService, with all nodes defaulting to
    /// .locked when no state has been recorded yet. Operates over the full
    /// SkillGraph (universal — same tree for everyone).
    private func liveStatesForFullGraph() -> [String: NodeState] {
        var states = skillProgress.nodeStates
        for node in SkillGraph.shared.nodes where states[node.id] == nil {
            states[node.id] = .locked
        }
        return states
    }
}

// Legacy `SkillNodeDetailSheet` removed in Phase 3a — the full-screen
// `SkillDetailView` replaces it. Presenters now use `.fullScreenCover(item:)`.
