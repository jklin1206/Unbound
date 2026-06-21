# SkillTree

The Skill Map tab: `UnboundSkillTreeTabView` hosts `SkillGraphView` (landing screen of cluster cards), which drills into `ClusterStaircaseView` — the zoomable per-cluster tree whose layout, rails, and hex rendering are split across the `ClusterStaircase*` extension files.

| File | Purpose |
| --- | --- |
| `UnboundSkillTreeTabView.swift` | Skill tree tab root — loads profile + live node state from SkillProgressService, presents `SkillDetailView` on node tap. |
| `SkillGraphView.swift` | Skill Map landing screen: vertical scroll of rich cluster cards, one per display tree (Pull/Push/Legs/Core/...). |
| `ClusterCardView.swift` | One full-width cluster card on the landing screen: glyph + name, proven/total progress, NOW chip, farthest proof. |
| `ClusterStaircaseView.swift` | Per-cluster top-to-bottom tree view (roots at top, keystone terminus); core state + node tap handling. |
| `ClusterStaircaseLayout.swift` | `NodeRole` enum and per-role sizing/spacing for the staircase layout. |
| `ComputedTreeLayout.swift` | Value type holding the computed tree geometry: positions, primary parents, roles, content size, active zoom. |
| `ClusterStaircaseTreeRendering.swift` | `mainTree(layout:)` — mounts the computed layout inside `ZoomableTreeScrollView`. |
| `ClusterStaircaseSections.swift` | `StaircaseSections` partition of a cluster's nodes (achieved / active / next / keystone / tangents). |
| `ClusterStaircaseHex.swift` | Hex node rendering per role (active/achieved/keystone/...) keyed off node state. |
| `ClusterStaircaseRails.swift` | SwiftUI Canvas rails: orthogonal child←parent step paths with reached/partial/locked glow. |
| `ClusterStaircaseRailsCG.swift` | CGContext rail versions for `UIGraphicsImageRenderer` — works around lazy Canvas rendering vanishing rails on zoom-out. |
| `ZoomableTreeScrollView.swift` | `UIViewRepresentable` pinch-zoom/pan scroll container for the tree content. |
| `ClusterDetailView.swift` | Drill-in mini-graph for a single cluster with barycentric tier layout; keystone/Mythic amplified treatment. |
| `LockedClusterInfoSheet.swift` | Sheet explaining why a gated cluster is dark and which keystone unlocks it. |
| `HandbalanceSubclusterPicker.swift` | Picker for the Handbalance umbrella's three sub-clusters (Handstand / HSPU / One-Arm), with gating. |
| `NodeUnlockShareCard.swift` | 1080×1920 IG/TikTok share card for a node unlock, rendered via ImageRenderer. |
| `SkillTraditionalVisualResolver.swift` | Maps a `SkillNode` to its exercise-visual asset name via generated-icon lookup + slug candidates. |
| `SkillGraphConcept.swift` | Throwaway Chunk 1.5 concept preview for the Skill Graph v2 redesign (Option B cluster-first drill-in). |

Where to find X:
- Entry point from the tab bar → `UnboundSkillTreeTabView.swift` (mounted by `../Dashboard/HomeTabView.swift`)
- Which clusters appear on the landing screen → `SkillGraphView.swift`
- Node positions / tree geometry math → `ClusterStaircaseView.swift` + `ComputedTreeLayout.swift` + `ClusterStaircaseLayout.swift`
- Rails missing or glow tiers → `ClusterStaircaseRails.swift` (Canvas) / `ClusterStaircaseRailsCG.swift` (zoomed-out renderer) 
- Node tap → detail screen → `SkillDetailView` in `../SkillDetail/`
- Skill icon asset resolution → `SkillTraditionalVisualResolver.swift`
