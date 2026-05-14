import SwiftUI

// MARK: - MuscleRegionShape
//
// Hand-positioned polygons for each BodyRegion, defined in
// normalized 0...1 coords relative to the body image frame. Scales with
// the container. These masks are traced for the unbound body art: compact,
// body-hugging zones instead of detached circles.

struct MuscleRegionShape: Shape {
    let region: BodyRegion
    let side: BodyMapSide

    func path(in rect: CGRect) -> Path {
        let spec = regionSpec(region: region, side: side)
        var path = Path()

        switch spec {
        case .none:
            return path
        case .polygons(let polygons):
            for polygon in polygons {
                guard let first = polygon.first else { continue }
                path.move(to: point(first, in: rect))
                for point in polygon.dropFirst() {
                    path.addLine(to: self.point(point, in: rect))
                }
                path.closeSubpath()
            }
        }
        return path
    }

    private func point(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * point.x,
            y: rect.minY + rect.height * point.y
        )
    }
}

enum BodyMapSide: Sendable { case front, back }

// MARK: - Region specs

/// Normalized shape specs. Tuples = (centerX, centerY, width, height) in 0...1.
private enum RegionSpec {
    case none
    case polygons([[CGPoint]])
}

private func regionSpec(region: BodyRegion, side: BodyMapSide) -> RegionSpec {
    switch (region, side) {
    // FRONT VIEW
    case (.chest, .front):
        return .polygons([
            poly((0.392, 0.286), (0.455, 0.258), (0.495, 0.278), (0.488, 0.334), (0.438, 0.346), (0.392, 0.326)),
            poly((0.505, 0.278), (0.545, 0.258), (0.608, 0.286), (0.608, 0.326), (0.562, 0.346), (0.512, 0.334))
        ])
    case (.shoulders, .front):
        return .polygons([
            poly((0.308, 0.269), (0.356, 0.246), (0.400, 0.266), (0.388, 0.318), (0.336, 0.333), (0.298, 0.306)),
            poly((0.600, 0.266), (0.644, 0.246), (0.692, 0.269), (0.702, 0.306), (0.664, 0.333), (0.612, 0.318))
        ])
    case (.biceps, .front):
        return .polygons([
            poly((0.314, 0.348), (0.358, 0.336), (0.374, 0.448), (0.340, 0.486), (0.302, 0.444)),
            poly((0.626, 0.448), (0.642, 0.336), (0.686, 0.348), (0.698, 0.444), (0.660, 0.486))
        ])
    case (.forearms, .front):
        return .polygons([
            poly((0.286, 0.474), (0.326, 0.496), (0.310, 0.602), (0.268, 0.624), (0.252, 0.552)),
            poly((0.674, 0.496), (0.714, 0.474), (0.748, 0.552), (0.732, 0.624), (0.690, 0.602))
        ])
    case (.abs, .front):
        return .polygons([
            poly((0.454, 0.354), (0.546, 0.354), (0.562, 0.505), (0.528, 0.568), (0.472, 0.568), (0.438, 0.505))
        ])
    case (.obliques, .front):
        return .polygons([
            poly((0.402, 0.382), (0.446, 0.392), (0.438, 0.526), (0.408, 0.578), (0.376, 0.510)),
            poly((0.554, 0.392), (0.598, 0.382), (0.624, 0.510), (0.592, 0.578), (0.562, 0.526))
        ])
    case (.quads, .front):
        return .polygons([
            poly((0.412, 0.592), (0.484, 0.592), (0.486, 0.760), (0.448, 0.820), (0.404, 0.746)),
            poly((0.516, 0.592), (0.588, 0.592), (0.596, 0.746), (0.552, 0.820), (0.514, 0.760))
        ])
    case (.calves, .front):
        return .polygons([
            poly((0.418, 0.792), (0.466, 0.804), (0.472, 0.914), (0.430, 0.958), (0.392, 0.906)),
            poly((0.534, 0.804), (0.582, 0.792), (0.608, 0.906), (0.570, 0.958), (0.528, 0.914))
        ])

    // BACK VIEW
    case (.traps, .back):
        return .polygons([
            poly((0.430, 0.250), (0.500, 0.220), (0.570, 0.250), (0.548, 0.322), (0.500, 0.338), (0.452, 0.322))
        ])
    case (.lats, .back):
        return .polygons([
            poly((0.372, 0.334), (0.456, 0.344), (0.450, 0.512), (0.392, 0.574), (0.344, 0.468)),
            poly((0.544, 0.344), (0.628, 0.334), (0.656, 0.468), (0.608, 0.574), (0.550, 0.512))
        ])
    case (.triceps, .back):
        return .polygons([
            poly((0.308, 0.342), (0.354, 0.348), (0.370, 0.468), (0.334, 0.512), (0.296, 0.448)),
            poly((0.646, 0.348), (0.692, 0.342), (0.704, 0.448), (0.666, 0.512), (0.630, 0.468))
        ])
    case (.forearms, .back):
        return .polygons([
            poly((0.278, 0.486), (0.322, 0.504), (0.306, 0.624), (0.264, 0.646), (0.246, 0.562)),
            poly((0.678, 0.504), (0.722, 0.486), (0.754, 0.562), (0.736, 0.646), (0.694, 0.624))
        ])
    case (.lowerBack, .back):
        return .polygons([
            poly((0.430, 0.506), (0.570, 0.506), (0.558, 0.604), (0.500, 0.636), (0.442, 0.604))
        ])
    case (.glutes, .back):
        return .polygons([
            poly((0.394, 0.616), (0.494, 0.620), (0.486, 0.710), (0.430, 0.738), (0.384, 0.688)),
            poly((0.506, 0.620), (0.606, 0.616), (0.616, 0.688), (0.570, 0.738), (0.514, 0.710))
        ])
    case (.hamstrings, .back):
        return .polygons([
            poly((0.410, 0.712), (0.486, 0.716), (0.480, 0.846), (0.442, 0.898), (0.398, 0.822)),
            poly((0.514, 0.716), (0.590, 0.712), (0.602, 0.822), (0.558, 0.898), (0.520, 0.846))
        ])
    case (.calves, .back):
        return .polygons([
            poly((0.418, 0.820), (0.464, 0.830), (0.472, 0.930), (0.432, 0.966), (0.392, 0.914)),
            poly((0.536, 0.830), (0.582, 0.820), (0.608, 0.914), (0.568, 0.966), (0.528, 0.930))
        ])

    // Regions not visible on this side
    default:
        return .none
    }
}

private func poly(_ points: (CGFloat, CGFloat)...) -> [CGPoint] {
    points.map { CGPoint(x: $0.0, y: $0.1) }
}

// MARK: - Visibility

extension BodyRegion {
    /// Which regions we paint on a given side view.
    static func visible(on side: BodyMapSide) -> [BodyRegion] {
        switch side {
        case .front:
            return [.chest, .shoulders, .biceps, .forearms, .abs, .obliques, .quads, .calves]
        case .back:
            return [.traps, .lats, .triceps, .forearms, .lowerBack, .glutes, .hamstrings, .calves]
        }
    }
}
