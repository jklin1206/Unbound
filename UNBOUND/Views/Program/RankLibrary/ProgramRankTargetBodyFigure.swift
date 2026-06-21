import SwiftUI
import UIKit

struct ProgramRankTargetBodyFigure: View {
    let side: BodyMapSide
    let targetRegions: [BodyRegion]
    let tint: Color

    private var targetSet: Set<BodyRegion> {
        Set(targetRegions)
    }

    var body: some View {
        GeometryReader { proxy in
            let viewBox = ProgramRankTargetSVGAsset.viewBox(for: side)
            let drawRect = Self.drawRect(in: proxy.size, viewBox: viewBox)
            let separatorWidth = max(0.65, min(1.35, drawRect.width / 245))

            ZStack {
                if let baseImage = ProgramRankTargetBodyImage.image(for: side) {
                    Image(uiImage: baseImage)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: drawRect.width, height: drawRect.height)
                        .position(x: drawRect.midX, y: drawRect.midY)
                        .opacity(0.94)
                }

                ForEach(ProgramRankTargetSVGAsset.paths(for: side)) { spec in
                    let isTargeted = targetSet.contains(spec.region)
                    let regionTint = ProgramRankTargetRegionPalette.tint(
                        for: spec.region,
                        fallback: tint
                    )

                    spec.path(in: drawRect, viewBox: viewBox)
                        .fill(
                            isTargeted ? regionTint.opacity(0.66) : Color.clear,
                            style: FillStyle(eoFill: spec.usesEvenOdd)
                        )

                    spec.path(in: drawRect, viewBox: viewBox)
                        .stroke(
                            isTargeted ? regionTint.opacity(0.92) : Color.unbound.borderSubtle.opacity(0.6),
                            style: StrokeStyle(
                                lineWidth: isTargeted ? separatorWidth + 0.35 : separatorWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .shadow(
                            color: isTargeted ? regionTint.opacity(0.20) : .clear,
                            radius: isTargeted ? 3 : 0
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(
            ProgramRankTargetSVGAsset.viewBox(for: side).width / ProgramRankTargetSVGAsset.viewBox(for: side).height,
            contentMode: .fit
        )
        .overlay(alignment: .topTrailing) {
            Text(side.rankTargetShortTitle)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.unbound.bg.opacity(0.72)))
                .padding(6)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(side.rankTargetShortTitle.lowercased()) target body map")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let names = targetRegions
            .filter { $0.isVisible(on: side) }
            .map(\.displayName)
        return names.isEmpty ? "No highlighted regions" : names.joined(separator: ", ")
    }

    private static func drawRect(in size: CGSize, viewBox: CGSize) -> CGRect {
        let scale = min(size.width / viewBox.width, size.height / viewBox.height)
        let width = viewBox.width * scale
        let height = viewBox.height * scale
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }
}

struct ProgramRankTargetRegionStrip: View {
    let regions: [BodyRegion]
    let tint: Color

    var body: some View {
        if regions.isEmpty {
            Text("NO BODY REGION DATA")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        } else {
            // Calm color-coded legend (no pills): a tint dot per region + label,
            // matching the colors on the body figures above.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(regions, id: \.self) { region in
                        let regionTint = ProgramRankTargetRegionPalette.tint(
                            for: region,
                            fallback: tint
                        )
                        HStack(spacing: 6) {
                            Circle()
                                .fill(regionTint)
                                .frame(width: 6, height: 6)
                            Text(region.displayName.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(0.7)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollClipDisabled()
        }
    }
}

enum ProgramRankTargetRegionSet {
    static func regions(for definition: MovementDefinition) -> [BodyRegion] {
        let seeded = definition.bodyRegions.isEmpty
            ? bodyRegions(from: definition.muscleGroups)
            : definition.bodyRegions
        return ordered(normalized(seeded))
    }

    private static func normalized(_ regions: [BodyRegion]) -> Set<BodyRegion> {
        regions.reduce(into: Set<BodyRegion>()) { result, region in
            switch region {
            case .chest:
                result.insert(.upperChest)
                result.insert(.midLowerChest)
            case .shoulders:
                result.insert(.frontSideDelts)
            default:
                result.insert(region)
            }
        }
    }

    private static func bodyRegions(from muscleGroups: [MuscleGroup]) -> [BodyRegion] {
        muscleGroups.flatMap { group -> [BodyRegion] in
            switch group {
            case .chest:
                return [.upperChest, .midLowerChest]
            case .back:
                return [.lats, .rhomboids, .traps]
            case .shoulders:
                return [.frontSideDelts]
            case .arms:
                return [.biceps, .triceps, .forearms]
            case .forearms:
                return [.forearms]
            case .legs:
                return [.quads, .hamstrings, .glutes, .calves]
            case .glutes:
                return [.glutes]
            case .core:
                return [.abs, .obliques, .lowerBack]
            case .traps:
                return [.traps]
            case .lats:
                return [.lats]
            case .calves:
                return [.calves]
            case .neck:
                return []
            }
        }
    }

    private static func ordered(_ regions: Set<BodyRegion>) -> [BodyRegion] {
        displayOrder.filter { regions.contains($0) }
    }

    private static let displayOrder: [BodyRegion] = [
        .upperChest, .midLowerChest, .frontSideDelts,
        .biceps, .triceps, .forearms,
        .traps, .rearDelts, .rhomboids, .lats,
        .abs, .obliques, .lowerBack,
        .quads, .adductors, .abductors, .hamstrings, .glutes, .calves
    ]
}

enum ProgramRankTargetSVGAsset {
    static let defaultViewBox = CGSize(width: 848, height: 1264)
    private static let frontAsset = load(side: .front)
    private static let backAsset = load(side: .back)

    static func viewBox(for side: BodyMapSide) -> CGSize {
        switch side {
        case .front:
            return frontAsset.viewBox
        case .back:
            return backAsset.viewBox
        }
    }

    static func paths(for side: BodyMapSide) -> [ProgramRankTargetRegionSpec] {
        switch side {
        case .front:
            return frontAsset.paths
        case .back:
            return backAsset.paths
        }
    }

    private static func load(side: BodyMapSide) -> Loaded {
        guard let url = Bundle.main.url(
            forResource: side.rankTargetSVGName,
            withExtension: "svg",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.rankTargetSVGName,
            withExtension: "svg"
        ),
              let data = try? Data(contentsOf: url)
        else {
            return Loaded(viewBox: defaultViewBox, paths: [])
        }

        let parser = ProgramRankTargetSVGRegionParser(side: side)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        _ = xmlParser.parse()
        return Loaded(viewBox: parser.viewBox ?? defaultViewBox, paths: parser.paths)
    }

    private struct Loaded {
        let viewBox: CGSize
        let paths: [ProgramRankTargetRegionSpec]
    }
}

final class ProgramRankTargetSVGRegionParser: NSObject, XMLParserDelegate {
    let side: BodyMapSide
    var viewBox: CGSize?
    var paths: [ProgramRankTargetRegionSpec] = []

    init(side: BodyMapSide) {
        self.side = side
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "svg", let rawViewBox = attributeDict["viewBox"] {
            viewBox = Self.parseViewBox(rawViewBox)
            return
        }

        guard elementName == "path",
              let rawRegion = attributeDict["data-region"],
              let region = ProgramRankTargetSVGRegionMapper.region(from: rawRegion),
              let pathData = attributeDict["d"]
        else { return }

        let id = attributeDict["id"] ?? "\(side.rankTargetShortTitle)-\(rawRegion)-\(paths.count)"
        paths.append(
            ProgramRankTargetRegionSpec(
                id: id,
                region: region,
                pathData: pathData,
                usesEvenOdd: attributeDict["fill-rule"] == "evenodd"
            )
        )
    }

    private static func parseViewBox(_ rawValue: String) -> CGSize? {
        let values = rawValue
            .split { $0 == " " || $0 == "," }
            .compactMap { Double($0) }
        guard values.count == 4 else { return nil }
        return CGSize(width: CGFloat(values[2]), height: CGFloat(values[3]))
    }
}

struct ProgramRankTargetRegionSpec: Identifiable {
    let id: String
    let region: BodyRegion
    let pathData: String
    let usesEvenOdd: Bool

    func path(in rect: CGRect, viewBox: CGSize) -> Path {
        let scale = rect.width / viewBox.width
        let transform = CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: rect.minX,
            ty: rect.minY
        )
        return SVGPathParser.path(from: pathData).applying(transform)
    }
}

enum ProgramRankTargetSVGRegionMapper {
    static func region(from rawValue: String) -> BodyRegion? {
        switch rawValue {
        case "deltoids":
            return .frontSideDelts
        case "upper_chest", "upper_pecs":
            return .upperChest
        case "mid_lower_chest", "lower_chest", "mid_chest", "sternal_pecs":
            return .midLowerChest
        case "front_side_delts", "front_delts", "side_delts":
            return .frontSideDelts
        case "rear_delts", "posterior_delts":
            return .rearDelts
        case "mid_back", "upper_mid_back":
            return .rhomboids
        case "traps_upper_back":
            return .traps
        case "lower_back":
            return .lowerBack
        case "inner_thighs":
            return .adductors
        case "outer_hips", "glute_medius":
            return .abductors
        default:
            return BodyRegion(rawValue: rawValue)
        }
    }
}

enum ProgramRankTargetBodyImage {
    static func image(for side: BodyMapSide) -> UIImage? {
        switch side {
        case .front:
            return frontImage
        case .back:
            return backImage
        }
    }

    private static let frontImage = load(side: .front)
    private static let backImage = load(side: .back)

    private static func load(side: BodyMapSide) -> UIImage? {
        if let url = Bundle.main.url(
            forResource: side.rankTargetBaseImageName,
            withExtension: "png",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.rankTargetBaseImageName,
            withExtension: "png"
        ),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: side.rankTargetBaseImageName)
    }
}

enum ProgramRankTargetRegionPalette {
    static func tint(for region: BodyRegion, fallback: Color) -> Color {
        switch region {
        case .upperChest, .midLowerChest:
            return Color.unbound.alert
        case .frontSideDelts, .rearDelts:
            return Color.unbound.rankGreen
        case .biceps, .triceps:
            return Color.unbound.warnOrange
        case .forearms:
            return Color.unbound.rankAmber
        case .traps, .rhomboids, .lats:
            return Color.unbound.coachCyan
        case .abs, .obliques, .lowerBack:
            return Color.unbound.accent
        case .quads, .adductors:
            return Color.unbound.rankGold
        case .abductors, .hamstrings, .glutes:
            return Color.unbound.impact
        case .calves:
            return Color.unbound.success
        case .chest, .shoulders:
            return fallback
        }
    }
}

extension BodyRegion {
    func isVisible(on side: BodyMapSide) -> Bool {
        switch (primarySide, side) {
        case (.front, .front), (.back, .back), (.both, _):
            return true
        default:
            return false
        }
    }
}

extension BodyMapSide {
    var rankTargetShortTitle: String {
        switch self {
        case .front:
            return "FRONT"
        case .back:
            return "BACK"
        }
    }

    var rankTargetBaseImageName: String {
        switch self {
        case .front:
            return "heatmap_anime_front_v4"
        case .back:
            return "heatmap_anime_back_v4"
        }
    }

    var rankTargetSVGName: String {
        switch self {
        case .front:
            return "source_frontmap_anime_v4_regions"
        case .back:
            return "source_backmap_anime_v4_regions"
        }
    }
}
