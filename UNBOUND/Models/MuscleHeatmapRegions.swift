import Foundation
import CoreGraphics

// MARK: - MuscleHeatmapRegions
//
// Loads `Resources/BodyMap/heatmap_regions.json` once and exposes typed
// polygon data per side. The JSON ships from the muscle-heat-map
// pipeline and uses a 100×179 viewBox; consumers scale polygon points
// into their render rect.

struct MuscleHeatmapRegions {
    struct Polygon: Sendable, Hashable {
        let id: String
        /// Raw label from JSON. Can be a MuscleHeatGroup rawValue OR
        /// "head" (decorative, no tier).
        let label: String
        /// Polygon points in viewBox coordinate space (see `viewBoxSize`).
        let points: [CGPoint]

        /// Typed heat group, or nil for decorative labels ("head").
        var heatGroup: MuscleHeatGroup? {
            MuscleHeatGroup(rawValue: label)
        }
    }

    let viewBoxSize: CGSize
    let front: [Polygon]
    let back: [Polygon]

    func polygons(for side: BodyMapSide) -> [Polygon] {
        switch side {
        case .front: return front
        case .back:  return back
        }
    }
}

// MARK: - Shared instance

extension MuscleHeatmapRegions {
    /// Lazily loaded, cached bundle resource. Fatal errors here are
    /// intentional — the app can't render the home hub without it.
    static let shared: MuscleHeatmapRegions = {
        guard let url = Bundle.main.url(
            forResource: "heatmap_regions",
            withExtension: "json"
        ) else {
            fatalError("heatmap_regions.json missing from bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try decode(from: data)
        } catch {
            fatalError("heatmap_regions.json decode failed: \(error)")
        }
    }()

    static func decode(from data: Data) throws -> MuscleHeatmapRegions {
        let raw = try JSONDecoder().decode(RawRegions.self, from: data)
        let viewBox = CGSize(width: raw.viewBox.width, height: raw.viewBox.height)
        return MuscleHeatmapRegions(
            viewBoxSize: viewBox,
            front: raw.front.regions.map(Polygon.init(raw:)),
            back: raw.back.regions.map(Polygon.init(raw:))
        )
    }
}

// MARK: - Raw JSON decoding

private struct RawRegions: Decodable {
    struct ViewBox: Decodable {
        let width: Double
        let height: Double
    }
    struct Side: Decodable {
        let regions: [RawPolygon]
    }
    struct RawPolygon: Decodable {
        let id: String
        let label: String
        let points: String
    }
    let viewBox: ViewBox
    let front: Side
    let back: Side
}

private extension MuscleHeatmapRegions.Polygon {
    init(raw: RawRegions.RawPolygon) {
        self.id = raw.id
        self.label = raw.label
        self.points = Self.parsePoints(raw.points)
    }

    /// Parse "x1,y1 x2,y2 x3,y3" whitespace-separated pairs into CGPoints.
    private static func parsePoints(_ str: String) -> [CGPoint] {
        str.split(separator: " ").compactMap { pair in
            let parts = pair.split(separator: ",")
            guard parts.count == 2,
                  let x = Double(parts[0]),
                  let y = Double(parts[1]) else { return nil }
            return CGPoint(x: x, y: y)
        }
    }
}
