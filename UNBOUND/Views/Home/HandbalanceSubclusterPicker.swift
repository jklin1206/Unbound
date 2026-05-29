import SwiftUI

// MARK: - HandbalanceSubclusterPicker
//
// Shown when the user taps the Handbalance umbrella card. Lists the three
// sub-clusters (Handstand, Handstand Pushup, One-Arm Handstand) as a
// vertical stack of buttons. Each button drills into its own
// ClusterStaircaseView. Gated stages show a lock + "REQUIRES" caption and
// are non-interactive.

struct HandbalanceSubclusterPicker: View {
    let tree: SkillDisplayTree
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    let onPick: (SkillCluster) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider().overlay(Color.unbound.border)
            stages
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: tree.glyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(tree.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(tree.tagline)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
            }
            Text("Pick a stage to drill into.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Stages

    private var stages: some View {
        VStack(spacing: 10) {
            ForEach(tree.clusters, id: \.self) { cluster in
                stageButton(cluster)
            }
        }
    }

    @ViewBuilder
    private func stageButton(_ cluster: SkillCluster) -> some View {
        let isUnlocked = graph.isClusterUnlocked(cluster, nodeStates: nodeStates)
        let clusterNodes = graph.nodes(in: cluster)
        let achieved = clusterNodes.filter {
            (nodeStates[$0.id] ?? .locked) == .proven
        }.count
        let total = clusterNodes.count

        Button {
            guard isUnlocked else { return }
            onPick(cluster)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isUnlocked ? cluster.glyph : "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isUnlocked ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(cluster.displayName)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(isUnlocked ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    if isUnlocked {
                        Text("\(achieved) / \(total) unlocked")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    } else if let required = cluster.requiresClusterKeystone {
                        Text("REQUIRES · \(required.displayName.uppercased()) KEYSTONE")
                            .font(Font.unbound.captionS.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer()
                if isUnlocked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isUnlocked ? Color.unbound.border : Color.unbound.border,
                        style: StrokeStyle(lineWidth: 1, dash: isUnlocked ? [] : [4, 4])
                    )
            )
            .opacity(isUnlocked ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }
}
