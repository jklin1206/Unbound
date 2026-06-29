import SwiftUI
import UIKit

// MARK: - ClusterStaircaseView
//
// True tree layout replacing the prior 2-column zig-zag staircase. Each
// cluster renders as a top-to-bottom tree: roots at top, keystone as the
// terminus, branches fanning out beneath each parent.
//
// Layout algorithm
//   1. For every cluster node, pick a "primary parent" = first in-cluster
//      prereq id in declaration order. Nodes without an in-cluster primary
//      parent are roots. Multiple roots render side-by-side at the top.
//   2. Pre-pass: compute `subtreeWidth(id)` for every node. Leaf = 120pt.
//      Parent = max(120, Σ children.subtreeWidth + 24pt gaps). Bottom-up.
//   3. Position pass: recurse from roots. Each parent centers its children
//      around its own x using their subtree widths as allocations.
//   4. Vertical spacing: 160pt default row, 200pt active row, 210pt keystone.
//   5. Horizontal ScrollView wraps the tree when it's wider than viewport.
//
// Rails
//   • Primary rails use the orthogonal step path (parent bottom-center →
//     midY → horizontal crossbar → child top-center) with blur+solid glow
//     tiered by reached/partial/locked.
//   • Secondary prereqs (anything other than the primary parent) render as
//     ghost rails — dashed, alpha 0.3, drawn first in the Canvas so primary
//     rails paint over them.
//
// Preserved
//   • Header, summary card, cosmetic picker, detail sheet handoff
//   • Active pulse, auto-scroll to active on appear
//   • Keystone sizing + crown
//   • MYTHIC section below the tree when keystone achieved

struct ClusterStaircaseView: View {
    let cluster: SkillCluster
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]

    /// When set, the tree opens, flies the camera to this node, and ignites it
    /// in place (the post-workout unlock reveal). nil = normal browsing.
    var unlockRevealNodeId: String? = nil
    /// DEBUG screenshot aid: hold the ignite peak instead of playing + auto-finishing.
    var revealFreeze: Bool = false
    /// Called when the reveal finishes (or the user dismisses it) so the
    /// presenter can drop the cover and return the user where they were.
    var onUnlockRevealFinished: (() -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var selectedNode: SkillNode?
    @State var showCosmetics: Bool = false
    @State var activePulse: CGFloat = 1.0
    @State var treeLayout: ComputedTreeLayout?
    @StateObject var skinService = SkinService.shared

    // Unlock-reveal animation state (only used when unlockRevealNodeId is set).
    // Deliberately minimal: a gentle camera centering + a clean enlarge of the
    // node's hex with a soft glow. No rings/sparks/flash (that read as a
    // targeting reticle — "too much").
    @State var revealStarted: Bool = false
    @State var revealIgnited: Bool = false   // once-guard so ignite runs a single time
    @State var revealFocus: CGPoint? = nil
    @State var revealChainProgress: CGFloat = 0   // 0→1 rail lighting from the parent node
    @State var revealHexScale: CGFloat = 1.0
    @State var revealGlow: Double = 0
    @State var revealOutline: CGFloat = 0   // 0→1 stroke traced around the hex
    @State var revealCaption: Bool = false

    let minZoom: CGFloat = 0.45
    let maxZoom: CGFloat = 1.5

    var clusterNodes: [SkillNode] { graph.nodes(in: cluster) }

    var sections: StaircaseSections { buildSections() }

    /// Chapter subtitle surfaced in the header. Derived from the parent
    /// display tree so umbrella sub-clusters (Handstand / HSPU / One-Arm)
    /// inherit "The Inversion". Falls back to the cluster tagline if the
    /// cluster is somehow not mapped to a display tree.
    var headerSubtitle: String {
        SkillDisplayTree.containing(cluster)?.chapterSubtitle ?? cluster.tagline
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    summaryCard
                        .padding(.top, 12)
                        .padding(.horizontal, 16)

                    if let layout = treeLayout {
                        mainTree(layout: layout)
                            .padding(.top, 28)
                    } else {
                        Color.unbound.bg
                            .frame(height: 500)
                            .padding(.top, 28)
                    }

                    if !sections.mythic.isEmpty {
                        sectionDivider("MYTHIC")
                            .padding(.top, 32)
                        mythicChain(nodes: sections.mythic)
                            .padding(.top, 28)
                    }
                }
                .padding(.bottom, 48)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    ) {
                        activePulse = 1.05
                    }
                    if treeLayout == nil {
                        treeLayout = buildLayout()
                    }
                    startUnlockRevealIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .skinChanged)) { _ in
                    treeLayout = buildLayout()
                }
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .overlay(alignment: .bottom) { unlockRevealCaption }
        .fullScreenCover(item: $selectedNode) { node in
            RankDetailView(
                node: node,
                graph: graph,
                nodeStates: nodeStates
            )
        }
        .sheet(isPresented: $showCosmetics) {
            NavigationStack {
                SkinPickerView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
    }

    // MARK: - Header

    var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)

            Image(systemName: cluster.glyph)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(cluster.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(headerSubtitle)
                    .font(Font.unbound.captionS.italic())
                    .foregroundStyle(skinService.currentSkin.primaryColor.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Button {
                UnboundHaptics.soft()
                showCosmetics = true
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(skinService.currentSkin.primaryColor)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(
                        Circle().strokeBorder(skinService.currentSkin.primaryColor.opacity(0.36), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skill tree cosmetics")
            .accessibilityHint("Opens cosmetic themes for the skill tree")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    var divider: some View {
        Rectangle()
            .fill(Color.unbound.border.opacity(0.4))
            .frame(height: 1)
    }

    // MARK: - Summary card

    var summaryCard: some View {
        let unlocked = clusterNodes
            .filter { isUnlockedState(nodeStates[$0.id] ?? .locked) }
            .count
        let total = max(1, clusterNodes.count)
        let fraction = Double(unlocked) / Double(total)
        let keystoneNode = clusterNodes.first { $0.isKeystone && !$0.isMythic }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("PROGRESS")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(unlocked) / \(clusterNodes.count)")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            progressBar(fraction: fraction)
            if let k = keystoneNode {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(skinService.currentSkin.primaryColor)
                    Text("KEYSTONE —")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(k.title)
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.unbound.surfaceElevated)
                Capsule()
                    .fill(skinService.currentSkin.nodeGradient)
                    .frame(width: max(0, geo.size.width * CGFloat(max(0, min(1, fraction)))))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Section label divider

    func sectionDivider(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
            Text(text)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Roles



    // MARK: - Hex rendering


    // MARK: - Section algorithm (unchanged — still used to identify role)

}

/// Snapshot of everything ClusterStaircaseView needs to draw the tree,
/// computed once on appear and cached in @State. The `railsImage` field
/// is a pre-rendered UIImage covering the FULL content size — see
/// `renderRailsImage(...)` for the reason.
