import SwiftUI

// MARK: - ProgressionsTabView (Phase 3a)
//
// Vertical ladder from this node up to the root of its cluster, walking
// primary-parent prereq links. Each row shows a small hex + title + state
// glyph (checkmark / lock / accent pulse for the current node).
//
// Pure derivation from existing graph data — no new content needed.

struct ProgressionsTabView: View {
    let node: SkillNode
    let graph: SkillGraph
    let nodeStates: [String: NodeState]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PROGRESSION PATH")

            VStack(spacing: 10) {
                let chain = ancestorChain()
                if chain.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(chain.enumerated()), id: \.offset) { idx, entry in
                        progressionRow(
                            entry: entry,
                            isCurrent: entry.node.id == node.id,
                            isFirst: idx == 0,
                            isLast: idx == chain.count - 1
                        )
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    // MARK: - Chain building

    /// One entry per ancestor, top (root) → bottom (this node), including
    /// any primary-chain siblings at the same depth.
    private struct ChainEntry {
        let node: SkillNode
        let siblings: [SkillNode]
    }

    /// Walks primary-parent links from leaf up to root within the cluster.
    /// Primary parent = first in-cluster prereq id in declaration order,
    /// matching ClusterStaircaseView's primary-chain rule.
    private func ancestorChain() -> [ChainEntry] {
        let clusterNodes = graph.nodes(in: node.cluster)
        let clusterIds = Set(clusterNodes.map(\.id))

        func primaryParent(of n: SkillNode) -> SkillNode? {
            for group in n.prereqs {
                if let first = group.nodeIds.first(where: { clusterIds.contains($0) }),
                   let parent = graph.node(id: first) {
                    return parent
                }
            }
            return nil
        }

        // Walk from node upward until root.
        var ancestorsTopDown: [SkillNode] = []
        var visited: Set<String> = []
        var current: SkillNode? = node
        while let n = current {
            if visited.contains(n.id) { break }
            visited.insert(n.id)
            ancestorsTopDown.insert(n, at: 0)
            current = primaryParent(of: n)
        }

        // For each ancestor, find peers sharing the same primary parent (i.e.
        // siblings). Exclude the chain node itself from the sibling list.
        return ancestorsTopDown.map { ancestor in
            let parent = primaryParent(of: ancestor)
            let siblings: [SkillNode]
            if let parent {
                siblings = clusterNodes.filter { candidate in
                    candidate.id != ancestor.id &&
                    primaryParent(of: candidate)?.id == parent.id
                }.sorted { $0.title < $1.title }
            } else {
                // Root row — other roots in the cluster.
                siblings = clusterNodes.filter { candidate in
                    candidate.id != ancestor.id &&
                    primaryParent(of: candidate) == nil
                }.sorted { $0.title < $1.title }
            }
            return ChainEntry(node: ancestor, siblings: siblings)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func progressionRow(
        entry: ChainEntry,
        isCurrent: Bool,
        isFirst: Bool,
        isLast: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Hexagon()
                        .fill(fill(for: entry.node))
                        .frame(width: 44, height: 44)
                    Hexagon()
                        .strokeBorder(border(for: entry.node, isCurrent: isCurrent), lineWidth: isCurrent ? 2 : 1.5)
                        .frame(width: 44, height: 44)
                    Image(systemName: glyph(for: entry.node, isCurrent: isCurrent))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(glyphColor(for: entry.node, isCurrent: isCurrent))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.node.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(titleColor(for: entry.node))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(statusLabel(for: entry.node, isCurrent: isCurrent))
                        .font(Font.unbound.captionS)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 0)
            }

            if !entry.siblings.isEmpty {
                siblingsRow(entry.siblings)
                    .padding(.leading, 56)
            }

            if !isLast {
                Rectangle()
                    .fill(Color.unbound.border.opacity(0.4))
                    .frame(width: 1, height: 14)
                    .padding(.leading, 22)
            }
        }
    }

    private func siblingsRow(_ siblings: [SkillNode]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(siblings, id: \.id) { sib in
                    Text(sib.title)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.unbound.surfaceElevated)
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Row styling helpers

    private func fill(for n: SkillNode) -> Color {
        let state = nodeStates[n.id] ?? .locked
        switch state {
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.accent.opacity(0.14)
        case .achieved:   return Color.unbound.accent.opacity(0.22)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    private func border(for n: SkillNode, isCurrent: Bool) -> Color {
        let state = nodeStates[n.id] ?? .locked
        if isCurrent { return Color.unbound.accent }
        switch state {
        case .locked:     return Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent
        case .mastered:   return Color.unbound.impact
        }
    }

    private func glyph(for n: SkillNode, isCurrent: Bool) -> String {
        let state = nodeStates[n.id] ?? .locked
        if isCurrent { return n.glyph }
        switch state {
        case .locked:     return "lock.fill"
        case .attempting: return n.glyph
        case .achieved:   return "checkmark"
        case .mastered:   return "crown.fill"
        }
    }

    private func glyphColor(for n: SkillNode, isCurrent: Bool) -> Color {
        let state = nodeStates[n.id] ?? .locked
        if isCurrent { return Color.unbound.accent }
        switch state {
        case .locked:     return Color.unbound.textTertiary
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent
        case .mastered:   return Color.unbound.impact
        }
    }

    private func titleColor(for n: SkillNode) -> Color {
        let state = nodeStates[n.id] ?? .locked
        return state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
    }

    private func statusLabel(for n: SkillNode, isCurrent: Bool) -> String {
        if isCurrent { return "CURRENT SKILL" }
        let state = nodeStates[n.id] ?? .locked
        switch state {
        case .locked:     return "LOCKED"
        case .attempting: return "IN PROGRESS"
        case .achieved:   return "ACHIEVED"
        case .mastered:   return "MASTERED"
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "tree")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("This skill is its own root — no ancestors to climb.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Shared

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(2.0)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }
}
