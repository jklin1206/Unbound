import Foundation
import CoreGraphics
import SwiftUI

// MARK: - BodyPaths
//
// Vector muscle paths sourced from HichamELBSI/react-native-body-highlighter
// (MIT license). Each body part has one or more SVG path strings grouped
// by side (left / right / common). ViewBox is 724×1448 portrait.

struct BodyPaths: Sendable {
    struct Part: Sendable, Identifiable {
        let slug: String
        let sides: [String: [String]]   // "left" | "right" | "common" → [path strings]
        var id: String { slug }

        /// All path strings for this part flattened across sides.
        var allPathStrings: [String] {
            sides.values.flatMap { $0 }
        }
    }

    let frontViewBox: CGRect
    let backViewBox: CGRect
    let front: [Part]
    let back: [Part]

    func parts(for side: BodyMapSide) -> [Part] {
        switch side {
        case .front: return front
        case .back:  return back
        }
    }

    func viewBox(for side: BodyMapSide) -> CGRect {
        switch side {
        case .front: return frontViewBox
        case .back:  return backViewBox
        }
    }
}

// MARK: - Loader

extension BodyPaths {
    static let shared: BodyPaths = {
        guard let url = Bundle.main.url(forResource: "body_paths", withExtension: "json") else {
            fatalError("body_paths.json missing from bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try decode(from: data)
        } catch {
            fatalError("body_paths.json decode failed: \(error)")
        }
    }()

    static func decode(from data: Data) throws -> BodyPaths {
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        let frontParts = raw.front.map { Part(slug: $0.slug, sides: $0.sides) }
        let backParts = raw.back.map { Part(slug: $0.slug, sides: $0.sides) }
        return BodyPaths(
            frontViewBox: computeBounds(parts: frontParts),
            backViewBox: computeBounds(parts: backParts),
            front: frontParts,
            back: backParts
        )
    }

    /// Union the bounding rects of every path in the given parts. Front and
    /// back of the source asset live in different coordinate spaces, so each
    /// side needs its own viewBox for the render to fit.
    private static func computeBounds(parts: [Part]) -> CGRect {
        var union: CGRect = .null
        for part in parts {
            for str in part.allPathStrings {
                let rect = SVGPathParser.path(from: str).boundingRect
                if !rect.isNull {
                    union = union.isNull ? rect : union.union(rect)
                }
            }
        }
        return union.isNull ? CGRect(x: 0, y: 0, width: 724, height: 1448) : union
    }

    private struct Raw: Decodable {
        struct ViewBox: Decodable { let width: Double; let height: Double }
        struct RawPart: Decodable { let slug: String; let sides: [String: [String]] }
        let viewBox: ViewBox
        let front: [RawPart]
        let back: [RawPart]
    }
}

// MARK: - Slug → MuscleHeatGroup bridge
//
// The highlighter's slugs are a superset of our taxonomy. Map each slug to
// the MuscleHeatGroup it contributes to; decorative parts (head/hair/feet/
// hands/ankles/knees/neck) return nil and render as non-interactive shapes.

extension BodyPaths.Part {
    var heatGroup: MuscleHeatGroup? {
        switch slug {
        case "chest":                      return .chest
        case "abs", "obliques":            return .core
        case "biceps":                     return .biceps
        case "triceps":                    return .triceps
        case "forearm":                    return .forearms
        case "trapezius":                  return .traps
        case "upper-back", "lower-back":   return .back
        case "deltoids":                   return .shoulders
        case "quadriceps", "adductors":    return .legs
        case "hamstring":                  return .hamstrings
        case "gluteal":                    return .glutes
        case "calves", "tibialis":         return .calves
        default:                           return nil   // head, hair, feet, hands, ankles, knees, neck
        }
    }

    /// Decorative parts should still render as a subtle silhouette so the
    /// body reads as a whole figure even when rank data is absent.
    var isDecorative: Bool { heatGroup == nil }
}
