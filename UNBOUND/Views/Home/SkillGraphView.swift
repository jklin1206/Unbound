import SwiftUI

// MARK: - SkillGraphView
//
// The unified skill map. Replaces the legacy per-archetype SkillTreeView.
// Shape: Option B — cluster-first drill-in.
//
//   ┌─────────────────────────────────┐
//   │  SKILLS TO CHASE                │  ← horizontal keystone row
//   │  [ MU ] [ OAP ] [ FP ] [ …  ]   │
//   │                                 │
//   │  CLUSTERS                       │
//   │  ┌───────┐  ┌───────┐  ┌──────┐│  ← 2-col (or 3-col) grid of tiles
//   │  │  HL   │  │  PP   │  │ CAL  ││
//   │  └───────┘  └───────┘  └──────┘│
//   │  ┌───────┐  ┌───────┐  ┌──────┐│
//   │  │  LD   │  │  CL   │  │ CO   ││
//   │  └───────┘  └───────┘  └──────┘│
//   └─────────────────────────────────┘
//
// Tap a cluster → drill into its mini-graph (ClusterDetailView).
// Tap a keystone → opens the node detail sheet immediately.

struct SkillGraphView: View {
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]
    var onNodeTap: (SkillNode) -> Void

    @State private var focusedCluster: SkillCluster?

    private let clusterColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            keystoneHeroRow
            clustersSection
        }
        .sheet(item: $focusedCluster) { cluster in
            ClusterStaircaseView(
                cluster: cluster,
                graph: graph,
                nodeStates: nodeStates,
                nodeProgress: nodeProgress
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
    }

    // MARK: Keystone hero row

    private var keystoneHeroRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SKILLS TO CHASE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(graph.keystones.count) keystones · \(graph.mythics.count) mythic")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(graph.keystones, id: \.id) { node in
                        keystoneCard(node)
                            .onTapGesture { onNodeTap(node) }
                    }
                    ForEach(graph.mythics, id: \.id) { node in
                        keystoneCard(node)
                            .onTapGesture { onNodeTap(node) }
                    }
                }
            }
        }
    }

    private func keystoneCard(_ node: SkillNode) -> some View {
        let state = nodeStates[node.id] ?? .locked
        let tone: Color = node.isMythic ? Color.unbound.impact : Color.unbound.accent
        let isOn = state == .achieved || state == .mastered

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: node.glyph)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                Spacer()
                ZStack {
                    Circle()
                        .fill(tone.opacity(0.16))
                        .frame(width: 22, height: 22)
                    Image(systemName: node.isMythic ? "star.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tone)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(node.title)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(node.cluster.displayName.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? tone : Color.unbound.border)
                    .frame(width: 6, height: 6)
                Text(node.isMythic ? "MYTHIC" : (isOn ? stateLabel(state) : "KEYSTONE"))
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(isOn ? tone : Color.unbound.textTertiary)
            }
        }
        .padding(14)
        .frame(width: 180, height: 200)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(node.isMythic ? tone.opacity(0.6) : Color.unbound.border,
                              lineWidth: node.isMythic ? 1.5 : 1)
        )
    }

    // MARK: Cluster grid

    private var clustersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CLUSTERS")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(graph.nodes.count) skills")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            LazyVGrid(columns: clusterColumns, spacing: 12) {
                ForEach(SkillCluster.allCases, id: \.id) { c in
                    clusterTile(c)
                        .onTapGesture {
                            UnboundHaptics.medium()
                            focusedCluster = c
                        }
                }
            }
        }
    }

    private func clusterTile(_ c: SkillCluster) -> some View {
        let clusterNodes = graph.nodes(in: c)
        let unlocked = clusterNodes.filter {
            let s = nodeStates[$0.id] ?? .locked
            return s == .achieved || s == .mastered
        }.count
        let total = clusterNodes.count
        let pct = total == 0 ? 0 : Double(unlocked) / Double(total)

        let attempting = clusterNodes.first {
            nodeStates[$0.id] == .attempting
        }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: c.glyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                Spacer()
                progressRing(value: pct, count: unlocked)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(c.displayName)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(unlocked) / \(total) unlocked")
                    .font(Font.unbound.captionS)
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer(minLength: 0)
            if let n = attempting {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: 6, height: 6)
                    Text(n.title)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.unbound.surfaceElevated))
            }
        }
        .padding(16)
        .frame(height: 200)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private func progressRing(value: Double, count: Int) -> some View {
        let size: CGFloat = 36
        let stroke: CGFloat = 3
        return ZStack {
            Circle()
                .stroke(Color.unbound.border, lineWidth: stroke)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: max(0.001, value))
                .stroke(Color.unbound.accent,
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            Text("\(count)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textPrimary)
        }
    }

    // MARK: Helpers

    private func stateLabel(_ s: NodeState) -> String {
        switch s {
        case .locked:     return "LOCKED"
        case .attempting: return "WORKING"
        case .achieved:   return "ACHIEVED"
        case .mastered:   return "MASTERED"
        }
    }
}
