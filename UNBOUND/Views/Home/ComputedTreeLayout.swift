import SwiftUI
import UIKit

struct ComputedTreeLayout {
    let contentWidth: CGFloat
    let treeHeight: CGFloat
    let positions: [String: CGPoint]
    let primaryParent: [String: String]
    let roles: [String: ClusterStaircaseView.NodeRole]
    let nodeById: [String: SkillNode]
    let rankBands: [ClusterStaircaseView.RankBand]
    let bandRegions: (bands: [ClusterStaircaseView.RankBandRegion], dividers: [CGFloat])
    let railsImage: UIImage
    let initialOffset: CGPoint?
    let activeZoom: CGFloat
    let viewportHeight: CGFloat
}
