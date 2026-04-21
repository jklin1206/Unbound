import SwiftUI

// MARK: - MuscleRegionShape
//
// Hand-positioned polygons / ellipses for each BodyRegion, defined in
// normalized 0...1 coords relative to the body image frame. Scales with
// the container. Shapes are visual-recognition grade, not anatomically
// precise — they tint the right zone, not surgical detail.

struct MuscleRegionShape: Shape {
    let region: BodyRegion
    let side: BodyMapSide

    func path(in rect: CGRect) -> Path {
        let spec = regionSpec(region: region, side: side)
        var path = Path()

        switch spec {
        case .none:
            return path
        case .ellipse(let cx, let cy, let w, let h):
            let r = CGRect(
                x: rect.minX + rect.width * (cx - w / 2),
                y: rect.minY + rect.height * (cy - h / 2),
                width: rect.width * w,
                height: rect.height * h
            )
            path.addEllipse(in: r)
        case .rounded(let cx, let cy, let w, let h, let radius):
            let r = CGRect(
                x: rect.minX + rect.width * (cx - w / 2),
                y: rect.minY + rect.height * (cy - h / 2),
                width: rect.width * w,
                height: rect.height * h
            )
            path.addRoundedRect(in: r, cornerSize: CGSize(width: radius, height: radius))
        case .twoEllipses(let a, let b):
            path.addEllipse(in: CGRect(
                x: rect.minX + rect.width * (a.0 - a.2 / 2),
                y: rect.minY + rect.height * (a.1 - a.3 / 2),
                width: rect.width * a.2,
                height: rect.height * a.3
            ))
            path.addEllipse(in: CGRect(
                x: rect.minX + rect.width * (b.0 - b.2 / 2),
                y: rect.minY + rect.height * (b.1 - b.3 / 2),
                width: rect.width * b.2,
                height: rect.height * b.3
            ))
        }
        return path
    }
}

enum BodyMapSide: Sendable { case front, back }

// MARK: - Region specs

/// Normalized shape specs. Tuples = (centerX, centerY, width, height) in 0...1.
private enum RegionSpec {
    case none
    case ellipse(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat)
    case rounded(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, radius: CGFloat)
    case twoEllipses(
        (CGFloat, CGFloat, CGFloat, CGFloat),
        (CGFloat, CGFloat, CGFloat, CGFloat)
    )
}

private func regionSpec(region: BodyRegion, side: BodyMapSide) -> RegionSpec {
    switch (region, side) {
    // FRONT VIEW
    case (.chest, .front):
        return .rounded(cx: 0.50, cy: 0.30, w: 0.30, h: 0.09, radius: 16)
    case (.shoulders, .front):
        return .twoEllipses(
            (0.30, 0.26, 0.11, 0.07),
            (0.70, 0.26, 0.11, 0.07)
        )
    case (.biceps, .front):
        return .twoEllipses(
            (0.22, 0.47, 0.07, 0.10),
            (0.78, 0.47, 0.07, 0.10)
        )
    case (.forearms, .front):
        return .twoEllipses(
            (0.18, 0.52, 0.06, 0.11),
            (0.82, 0.52, 0.06, 0.11)
        )
    case (.abs, .front):
        return .rounded(cx: 0.50, cy: 0.45, w: 0.145, h: 0.13, radius: 10)
    case (.obliques, .front):
        return .twoEllipses(
            (0.30, 0.52, 0.042, 0.09),
            (0.70, 0.52, 0.042, 0.09)
        )
    case (.quads, .front):
        return .twoEllipses(
            (0.41, 0.70, 0.10, 0.15),
            (0.59, 0.70, 0.10, 0.15)
        )
    case (.calves, .front):
        return .twoEllipses(
            (0.41, 0.84, 0.07, 0.08),
            (0.59, 0.84, 0.07, 0.08)
        )

    // BACK VIEW
    case (.traps, .back):
        return .rounded(cx: 0.50, cy: 0.24, w: 0.14, h: 0.07, radius: 10)
    case (.lats, .back):
        return .twoEllipses(
            (0.36, 0.44, 0.10, 0.13),
            (0.64, 0.44, 0.10, 0.13)
        )
    case (.triceps, .back):
        return .twoEllipses(
            (0.22, 0.40, 0.07, 0.10),
            (0.78, 0.40, 0.07, 0.10)
        )
    case (.forearms, .back):
        return .twoEllipses(
            (0.18, 0.52, 0.06, 0.11),
            (0.82, 0.52, 0.06, 0.11)
        )
    case (.lowerBack, .back):
        return .rounded(cx: 0.50, cy: 0.54, w: 0.16, h: 0.08, radius: 8)
    case (.glutes, .back):
        return .twoEllipses(
            (0.42, 0.66, 0.10, 0.08),
            (0.58, 0.66, 0.10, 0.08)
        )
    case (.hamstrings, .back):
        return .twoEllipses(
            (0.41, 0.78, 0.10, 0.12),
            (0.59, 0.78, 0.10, 0.12)
        )
    case (.calves, .back):
        return .twoEllipses(
            (0.41, 0.84, 0.07, 0.08),
            (0.59, 0.84, 0.07, 0.08)
        )

    // Regions not visible on this side
    default:
        return .none
    }
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
