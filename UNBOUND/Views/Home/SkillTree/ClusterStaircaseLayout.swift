import SwiftUI
import UIKit

extension ClusterStaircaseView {
    enum NodeRole { case achieved, active, next, keystone, tangent }

    func sizeFor(role: NodeRole) -> CGFloat {
        switch role {
        case .active:   return 120
        case .keystone: return 140
        default:        return 95
        }
    }

    func belowOffset(for role: NodeRole) -> CGFloat {
        switch role {
        case .active:   return 10 + 18
        case .keystone: return 10 + 32
        default:        return 8 + 14
        }
    }

    func rowGap(for role: NodeRole) -> CGFloat {
        switch role {
        case .active:   return 245
        case .keystone: return 290
        default:        return 235
        }
    }

    // MARK: - Tree structure

    /// Assembles the primary-parent tree for every node in this cluster —
    /// mythics included. Mythics are real terminals (Strict Muscle-Up,
    /// One-Arm Pull-Up, etc.) that chain naturally off non-mythic parents,
    /// so they belong in the main tree, not a separate section.
    /// Returns the root ids (nodes with no in-cluster prereq), a children map
    /// (parent → sorted child ids), a primary-parent map, and a role map.
    func buildTreeStructure() -> (
        rootIds: [String],
        children: [String: [String]],
        primaryParent: [String: String],
        roles: [String: NodeRole]
    ) {
        let nodes = clusterNodes
        let clusterIds = Set(nodes.map(\.id))

        // Primary parent: first in-cluster prereq id in declaration order.
        var primaryParent: [String: String] = [:]
        for n in nodes {
            for group in n.prereqs {
                if let first = group.nodeIds.first(where: { clusterIds.contains($0) }) {
                    primaryParent[n.id] = first
                    break
                }
            }
        }

        // Children map, sorted by id for stable layout.
        var children: [String: [String]] = [:]
        for (childId, parentId) in primaryParent {
            children[parentId, default: []].append(childId)
        }
        for k in Array(children.keys) {
            children[k]?.sort()
        }

        // Roots: any non-mythic node without a primary parent in-cluster.
        let rootIds = nodes
            .filter { primaryParent[$0.id] == nil }
            .map(\.id)
            .sorted()

        // Roles: achieved, active, next, keystone, or tangent (fallback).
        var roles: [String: NodeRole] = [:]
        for n in sections.achieved { roles[n.id] = .achieved }
        if let a = sections.active { roles[a.id] = .active }
        for n in sections.next { roles[n.id] = .next }
        if let k = sections.keystone { roles[k.id] = .keystone }
        for n in nodes where roles[n.id] == nil {
            roles[n.id] = .tangent
        }

        return (rootIds, children, primaryParent, roles)
    }

    /// Bottom-up pre-pass: each node's subtree width is its own hex cell
    /// width (leaf), the sum of regular children's subtree widths centered
    /// below it, plus the sum of any parallel children's subtree widths
    /// extending to the right at the same y. Cycle-safe via a visited set.
    func computeSubtreeWidths(
        rootIds: [String],
        children: [String: [String]]
    ) -> [String: CGFloat] {
        let hexCellWidth: CGFloat = 160
        let gap: CGFloat = 48
        var widths: [String: CGFloat] = [:]
        var visiting: Set<String> = []
        let nodeById: [String: SkillNode] = Dictionary(
            uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) }
        )

        func isParallel(_ id: String) -> Bool {
            nodeById[id]?.isParallelToParent ?? false
        }

        func compute(_ id: String) -> CGFloat {
            if let w = widths[id] { return w }
            if visiting.contains(id) { return hexCellWidth }
            visiting.insert(id)
            defer { visiting.remove(id) }

            let kids = children[id] ?? []
            let regularKids = kids.filter { !isParallel($0) }
            let parallelKids = kids.filter { isParallel($0) }

            // Regular subtree below: standard child packing centered under self.
            let regularBelowWidth: CGFloat
            if regularKids.isEmpty {
                regularBelowWidth = hexCellWidth
            } else {
                let sum = regularKids.map { compute($0) }.reduce(0, +)
                    + gap * CGFloat(max(0, regularKids.count - 1))
                regularBelowWidth = max(hexCellWidth, sum)
            }

            // Parallel siblings extend to the right of the parent's own
            // bounding box; each parallel kid contributes its own subtree
            // width plus a leading gap separating it from what's left.
            let parallelSideWidth = parallelKids
                .map { compute($0) }
                .reduce(0, +)
                + gap * CGFloat(parallelKids.count)

            let w = regularBelowWidth + parallelSideWidth
            widths[id] = w
            return w
        }

        for id in rootIds { _ = compute(id) }
        return widths
    }

    /// Recurse from each root, centering regular children around the
    /// parent's x and placing parallel children at the same y to the
    /// right. Vertical step varies per role.
    func assignPositions(
        rootIds: [String],
        children: [String: [String]],
        subtreeWidths: [String: CGFloat],
        roles: [String: NodeRole],
        totalWidth: CGFloat,
        topY: CGFloat
    ) -> [String: CGPoint] {
        let gap: CGFloat = 48
        let hexCellWidth: CGFloat = 160
        var positions: [String: CGPoint] = [:]
        var visiting: Set<String> = []
        let nodeById: [String: SkillNode] = Dictionary(
            uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) }
        )

        func isParallel(_ id: String) -> Bool {
            nodeById[id]?.isParallelToParent ?? false
        }

        // Place a node into a horizontal allocation slot starting at
        // `slotLeft` with width `subtreeWidths[id]`. The node's own x is
        // anchored to the centerline of its regular-below subtree (i.e.
        // its left "block"). Parallel kids consume the right-hand
        // portion of the slot at the parent's y.
        func place(_ id: String, slotLeft: CGFloat, y: CGFloat) {
            if visiting.contains(id) { return }
            visiting.insert(id)
            defer { visiting.remove(id) }

            let kids = children[id] ?? []
            let regularKids = kids.filter { !isParallel($0) }
            let parallelKids = kids.filter { isParallel($0) }

            // Reconstruct the regular-below width so we can position self
            // over its center. Mirrors logic in computeSubtreeWidths.
            let regularBelowWidth: CGFloat = {
                if regularKids.isEmpty { return hexCellWidth }
                let sum = regularKids.map { subtreeWidths[$0] ?? hexCellWidth }.reduce(0, +)
                    + gap * CGFloat(max(0, regularKids.count - 1))
                return max(hexCellWidth, sum)
            }()

            let selfX = slotLeft + regularBelowWidth / 2
            positions[id] = CGPoint(x: selfX, y: y)

            // Regular kids: distribute centered around self at y + rowGap.
            if !regularKids.isEmpty {
                var cursor = slotLeft
                if regularKids.count == 1 {
                    // Center single child directly under parent.
                    let kw = subtreeWidths[regularKids[0]] ?? hexCellWidth
                    let kSlotLeft = selfX - kw / 2
                    let ky = y + rowGap(for: roles[regularKids[0]] ?? .tangent)
                    place(regularKids[0], slotLeft: kSlotLeft, y: ky)
                } else {
                    // Pack regular kids' slots end-to-end across the
                    // regular-below band, which already starts at slotLeft
                    // and is regularBelowWidth wide (centered on selfX).
                    let bandLeft = selfX - regularBelowWidth / 2
                    cursor = bandLeft
                    for kid in regularKids {
                        let kw = subtreeWidths[kid] ?? hexCellWidth
                        let ky = y + rowGap(for: roles[kid] ?? .tangent)
                        place(kid, slotLeft: cursor, y: ky)
                        cursor += kw + gap
                    }
                }
            }

            // Parallel kids: same y, march to the right of self's regular
            // block. Each one starts after a gap.
            if !parallelKids.isEmpty {
                var cursor = slotLeft + regularBelowWidth + gap
                for kid in parallelKids {
                    let kw = subtreeWidths[kid] ?? hexCellWidth
                    place(kid, slotLeft: cursor, y: y)
                    cursor += kw + gap
                }
            }
        }

        // Lay roots side-by-side along the top row.
        let rootWidths = rootIds.map { subtreeWidths[$0] ?? hexCellWidth }
        let totalRootsWidth = rootWidths.reduce(0, +) + gap * CGFloat(max(0, rootIds.count - 1))
        let startX = (totalWidth - totalRootsWidth) / 2
        var cursor = startX
        for (i, id) in rootIds.enumerated() {
            let w = rootWidths[i]
            place(id, slotLeft: cursor, y: topY)
            cursor += w + gap
            _ = i
        }
        return positions
    }

    // MARK: - Main tree

    /// Pre-compute everything needed to render the tree, including the rails
    /// as a UIImage. Called once on .onAppear, cached in `treeLayout` state.
    /// Rails are rendered with UIGraphicsImageRenderer (which always renders
    /// the FULL content size) rather than SwiftUI Canvas (which renders
    /// lazily per visible rect inside UIScrollView — causing rails connecting
    /// to off-viewport nodes to vanish when the user zooms out).
    func buildLayout() -> ComputedTreeLayout {
        let (rootIds, children, primaryParent, roles) = buildTreeStructure()
        let subtreeWidths = computeSubtreeWidths(rootIds: rootIds, children: children)

        let rootWidthsSum = rootIds.map { subtreeWidths[$0] ?? 120 }.reduce(0, +)
        let rootGapWidth = CGFloat(max(0, rootIds.count - 1)) * 48
        let contentWidth = max(340, rootWidthsSum + rootGapWidth + 32)

        let topY: CGFloat = 80
        let positions = assignPositions(
            rootIds: rootIds,
            children: children,
            subtreeWidths: subtreeWidths,
            roles: roles,
            totalWidth: contentWidth,
            topY: topY
        )

        let maxY = positions.values.map(\.y).max() ?? topY
        let treeHeight = maxY + 200

        let nodeById: [String: SkillNode] = Dictionary(
            uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) }
        )

        let rankBands = computeAllRankBands(
            positions: positions,
            nodeById: nodeById,
            topY: topY,
            bottomY: maxY
        )

        let bandRegions = computeRankBandRegions(
            positions: positions,
            nodeById: nodeById,
            topY: 0,
            bottomY: treeHeight
        )

        let activeId = roles.first(where: { $0.value == .active })?.key
        let activePos = activeId.flatMap { positions[$0] }
        let activeZoom = min(maxZoom, max(minZoom, 1.0))

        let viewportH = mapViewportHeight(contentWidth: contentWidth, for: treeHeight)
        let initialOffset: CGPoint? = activePos.map { pt in
            let viewportW = ScreenMetrics.bounds.width
            let scaledX = pt.x * activeZoom - viewportW / 2
            let scaledY = pt.y * activeZoom - viewportH / 2
            let maxOffX = max(0, contentWidth * activeZoom - viewportW)
            let maxOffY = max(0, treeHeight * activeZoom - viewportH)
            return CGPoint(
                x: min(max(0, scaledX), maxOffX),
                y: min(max(0, scaledY), maxOffY)
            )
        }

        let railsImage = renderRailsImage(
            positions: positions,
            primaryParent: primaryParent,
            roles: roles,
            nodeById: nodeById,
            contentWidth: contentWidth,
            treeHeight: treeHeight
        )

        return ComputedTreeLayout(
            contentWidth: contentWidth,
            treeHeight: treeHeight,
            positions: positions,
            primaryParent: primaryParent,
            roles: roles,
            nodeById: nodeById,
            rankBands: rankBands,
            bandRegions: bandRegions,
            railsImage: railsImage,
            initialOffset: initialOffset,
            activeZoom: activeZoom,
            viewportHeight: viewportH
        )
    }
}
