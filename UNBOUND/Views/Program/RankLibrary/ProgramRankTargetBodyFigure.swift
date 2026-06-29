import SwiftUI
import UIKit

struct ProgramRankTargetBodyFigure: View {
    let side: BodyMapSide
    /// region → importance rank (0 = primary mover … 2 = support). Drives the
    /// heat-ramp tint per region; regions absent from the map stay unfilled.
    let rankByRegion: [BodyRegion: Int]

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
                    let rank = rankByRegion[spec.region]
                    let isTargeted = rank != nil

                    spec.path(in: drawRect, viewBox: viewBox)
                        .fill(
                            rank.map(ProgramRankTargetRegionSet.fillColor(forRank:)) ?? Color.clear,
                            style: FillStyle(eoFill: spec.usesEvenOdd)
                        )

                    spec.path(in: drawRect, viewBox: viewBox)
                        .stroke(
                            rank.map(ProgramRankTargetRegionSet.strokeColor(forRank:)) ?? Color.unbound.borderSubtle.opacity(0.6),
                            style: StrokeStyle(
                                lineWidth: isTargeted ? separatorWidth + 0.35 : separatorWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .shadow(
                            color: rank.map { ProgramRankTargetRegionSet.color(forRank: $0).opacity(0.25) } ?? .clear,
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
        let names = rankByRegion.keys
            .filter { $0.isVisible(on: side) }
            .sorted { (rankByRegion[$0] ?? 9) < (rankByRegion[$1] ?? 9) }
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
    let regions: [ProgramRankTargetRegionSet.RankedTargetRegion]

    /// Regions grouped into their importance tiers, order preserved. One entry
    /// per tier → one legend row.
    private var tiers: [(rank: Int, names: [String])] {
        var result: [(rank: Int, names: [String])] = []
        for item in regions {
            if let last = result.last, last.rank == item.rank {
                result[result.count - 1].names.append(item.region.displayName)
            } else {
                result.append((rank: item.rank, names: [item.region.displayName]))
            }
        }
        return result
    }

    var body: some View {
        if regions.isEmpty {
            Text("NO BODY REGION DATA")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        } else {
            // One calm row per tier (no swatch dots): a role label in the tier's
            // own heat color — the color tie to the figures — then the specific
            // muscles joined by middots. Names stay white for legibility; the
            // distinct hue carries the rank.
            VStack(alignment: .leading, spacing: 9) {
                ForEach(tiers, id: \.rank) { tier in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(ProgramRankTargetRegionSet.roleLabel(forRank: tier.rank))
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(ProgramRankTargetRegionSet.color(forRank: tier.rank))
                            .frame(width: 78, alignment: .leading)
                        Text(tier.names.joined(separator: "  ·  "))
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

enum ProgramRankTargetRegionSet {
    /// A SPECIFIC muscle region (quads, hamstrings, lats, …) ranked by importance
    /// tier: 0 = primary mover, 1 = secondary, 2 = support. Tiers are dense — a
    /// tier is only consumed by a muscle group that contributes at least one
    /// not-yet-listed region, so the PRIMARY / SECONDARY / SUPPORT labels never
    /// skip even when groups overlap (e.g. legs already lit the glutes).
    struct RankedTargetRegion: Identifiable {
        let region: BodyRegion
        let rank: Int
        var id: String { region.rawValue }
    }

    /// The specific target regions for a movement, each tagged with its
    /// importance tier and capped to the top 3 tiers — detailed enough to name
    /// quads vs hamstrings vs glutes, not just "legs". Prefers the skill node's
    /// primary→secondary ordering (the real importance signal — the movement
    /// definition flattens + alphabetizes it); falls back to the definition's
    /// listed groups for gym lifts with no node.
    static func rankedRegions(node: SkillNode?, definition: MovementDefinition?) -> [RankedTargetRegion] {
        rankedRegions(orderedGroups: importanceOrderedGroups(node: node, definition: definition))
    }

    /// Rank directly from an importance-ordered muscle-group list — used by the
    /// in-program exercise detail, which has no node or definition handy (its
    /// `muscleGroups` are already authored primary-first).
    static func rankedRegions(muscleGroups: [MuscleGroup]) -> [RankedTargetRegion] {
        rankedRegions(orderedGroups: drawableDeduped(muscleGroups))
    }

    /// Expand importance-ordered groups into specific regions, each tagged with a
    /// dense importance tier. A group that adds no new region doesn't consume a
    /// tier; ranking stops after the top 3 contributing tiers.
    private static func rankedRegions(orderedGroups: [MuscleGroup]) -> [RankedTargetRegion] {
        var seen = Set<BodyRegion>()
        var result: [RankedTargetRegion] = []
        var tier = -1
        for group in orderedGroups {
            let fresh = ordered(normalized(bodyRegions(from: [group]))).filter { !seen.contains($0) }
            guard !fresh.isEmpty else { continue }
            tier += 1
            if tier > 2 { break }   // keep to the top 3 importance tiers
            for region in fresh {
                seen.insert(region)
                result.append(RankedTargetRegion(region: region, rank: tier))
            }
        }
        return result
    }

    /// region → importance tier, for tinting the body figures.
    static func rankByRegion(from regions: [RankedTargetRegion]) -> [BodyRegion: Int] {
        regions.reduce(into: [BodyRegion: Int]()) { map, item in
            map[item.region] = item.rank
        }
    }

    /// Distinct per-tier hue — a hot→cool heat ramp (red = most worked, cyan =
    /// support). Color carries the importance rank, so tiers no longer rely on
    /// opacity to separate (which left support too faded). Uses the design
    /// system's sanctioned fitness-ramp tokens.
    static func color(forRank rank: Int) -> Color {
        switch rank {
        case 0:  return Color.unbound.rankRed     // #EF4444 — primary mover
        case 1:  return Color.unbound.rankAmber   // #EAB308 — secondary
        default: return Color.unbound.coachCyan   // #06B6D4 — support
        }
    }

    /// Body-fill color for a region's tier (hue + a near-uniform fill, with a
    /// touch more presence on the prime mover). Hue, not opacity, signals rank.
    static func fillColor(forRank rank: Int) -> Color {
        let opacity: Double = rank == 0 ? 0.66 : (rank == 1 ? 0.58 : 0.52)
        return color(forRank: rank).opacity(opacity)
    }

    /// Outline color for a filled region.
    static func strokeColor(forRank rank: Int) -> Color {
        color(forRank: rank).opacity(0.95)
    }

    static func roleLabel(forRank rank: Int) -> String {
        switch rank {
        case 0:  return "PRIMARY"
        case 1:  return "SECONDARY"
        default: return "SUPPORT"
        }
    }

    /// Importance-ordered, deduped muscle groups. Groups that light no drawable
    /// region (e.g. neck) are skipped so they never claim a top-3 slot.
    private static func importanceOrderedGroups(
        node: SkillNode?,
        definition: MovementDefinition?
    ) -> [MuscleGroup] {
        var combined: [MuscleGroup] = []
        if let node, !(node.primaryMuscles.isEmpty && node.secondaryMuscles.isEmpty) {
            combined += node.primaryMuscles + node.secondaryMuscles
        }
        if let definition { combined += definition.muscleGroups }
        return drawableDeduped(combined)
    }

    /// Dedupe preserving order, dropping groups that light no drawable region.
    private static func drawableDeduped(_ groups: [MuscleGroup]) -> [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var result: [MuscleGroup] = []
        for group in groups where !seen.contains(group) && !bodyRegions(from: [group]).isEmpty {
            seen.insert(group)
            result.append(group)
        }
        return result
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
