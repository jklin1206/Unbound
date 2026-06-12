# SkillTree

The full skill-map tab: the landing `SkillGraphView` grid of cluster cards, the per-cluster `ClusterStaircaseView` tree with its layout engine and rail renderer, and supporting sheet/picker views.

| File | Contents |
|---|---|
| `UnboundSkillTreeTabView.swift` | Skill-tree tab root; loads `UserProfile` and `SkillProgressService` state, hosts `SkillGraphView`, and presents `SkillDetailView` on node selection |
| `SkillGraphView.swift` | Landing screen: vertical scroll of `ClusterCardView` tiles (Pull / Push / Legs / Core / Handstand / Planche); routes taps to `ClusterStaircaseView` or `HandbalanceSubclusterPicker` |
| `SkillGraphConcept.swift` | Throwaway prototype (Option-B cluster-first concept); hardcoded states, no persistence — kept until the real graph fully ships |
| `ClusterStaircaseView.swift` | Root of the per-cluster true-tree layout: computes subtree widths, positions nodes, drives `ComputedTreeLayout`, and mounts `ZoomableTreeScrollView` |
| `ClusterStaircaseLayout.swift` | `NodeRole` enum and layout sizing helpers (`sizeFor(role:)`, `belowOffset(for:)`) used during the pre-pass position calculation |
| `ClusterStaircaseTreeRendering.swift` | `mainTree(layout:)` — wraps the positioned ZStack inside `ZoomableTreeScrollView` and renders the cosmetic tree background |
| `ClusterStaircaseSections.swift` | `StaircaseSections` struct and `buildSections()`: classifies nodes into achieved / active / next / keystone / mythic buckets |
| `ClusterStaircaseHex.swift` | `hexCore(node:role:size:)` — dispatches to `activeHex`, `keystoneHex`, or `defaultHex` based on role and node state |
| `ClusterStaircaseRails.swift` | SwiftUI `Canvas` rail drawing: `drawPrimaryRails` and `drawTangentRails` for orthogonal step paths with glow tiers |
| `ClusterStaircaseRailsCG.swift` | CGContext (`UIGraphicsImageRenderer`) rail counterparts: `drawPrimaryRailsCG` — draws into a full-content-sized `UIImage` to prevent lazy-render clipping at zoom-out |
| `ComputedTreeLayout.swift` | Value type capturing the full result of the layout pre-pass: positions, primary-parent map, roles, rank-band regions, rails image, initial offset, and zoom |
| `ZoomableTreeScrollView.swift` | `UIViewRepresentable` wrapping a `UIScrollView` with pinch-zoom (`minimumZoomScale` / `maximumZoomScale`), hosting the SwiftUI tree content |
| `ClusterCardView.swift` | Rich cluster tile for the landing grid: header glyph + tagline, proven/total progress bar, NOW chip, farthest-proof chip, and locked state treatment |
| `ClusterDetailView.swift` | Mini-graph drill-in for a single cluster: nodes placed by tier/barycentre sort, edges between prereq pairs, keystone/mythic amplification |
| `LockedClusterInfoSheet.swift` | Sheet explaining why a gated cluster is dark; names the keystone the user must crack to unlock it |
| `HandbalanceSubclusterPicker.swift` | Sub-cluster picker for the Handbalance umbrella: lists Handstand / HSPU / OAH buttons; gated stages are non-interactive with lock + REQUIRES caption |
| `NodeUnlockShareCard.swift` | 1080×1920 share card rendered via `ImageRenderer`: wordmark, achievement headline, hex badge, node title, gains, cluster meta, and footer |
| `SkillTraditionalVisualResolver.swift` | `SkillTraditionalVisualResolver` enum: resolves a `SkillNode` to its best matching asset name via slug candidates and generated-icon fallback |

## Where to find X

- **Skill-map landing grid** → `SkillGraphView.swift`
- **Per-cluster staircase tree** → `ClusterStaircaseView.swift` (layout) + `ClusterStaircaseLayout.swift` (sizing)
- **Rail drawing (avoiding lazy-clip bug)** → `ClusterStaircaseRailsCG.swift`
- **Pinch-zoom scroll container** → `ZoomableTreeScrollView.swift`
- **Node icon asset resolution** → `SkillTraditionalVisualResolver.swift`
- **Unlock share card** → `NodeUnlockShareCard.swift`
