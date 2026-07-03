import Foundation
import SwiftUI
import UIKit

/// The detail sections shared by the standalone ExerciseDetailView and the
/// inline expansion inside ExerciseLogCard. Field-based so callers need not
/// hold an `Exercise`.
struct ExerciseDetailSections: View {
    let muscleGroups: [MuscleGroup]
    var bodyRegions: [BodyRegion] = []
    var equipmentDefinition: MovementDefinition? = nil
    var showsProgramming: Bool = true
    let sets: Int
    let reps: String
    let restSeconds: Int
    let formCues: String?
    let substitution: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            muscleGroupsSection
                .padding(.top, 8)
            if let equipmentDefinition,
               !ExerciseEquipmentAssetStrip.items(for: equipmentDefinition).isEmpty {
                equipmentSection(equipmentDefinition)
                    .padding(.top, 26)
            }
            if showsProgramming {
                programmingSection
                    .padding(.top, 26)
            }
            if let notes = formCues, !notes.isEmpty {
                formCuesSection(notes: notes)
                    .padding(.top, 26)
            }
            if let sub = substitution, !sub.isEmpty {
                substitutionSection(sub: sub)
                    .padding(.top, 26)
            }
        }
    }

    private func equipmentSection(_ definition: MovementDefinition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EQUIPMENT")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            ExerciseEquipmentAssetStrip(
                definition: definition,
                maxItems: 4,
                itemSize: 34,
                showsLabels: true
            )
        }
    }

    private var muscleGroupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TARGET MUSCLES")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            TargetMuscleHeatmapView(
                muscleGroups: muscleGroups,
                bodyRegions: bodyRegions
            )
        }
    }

    private var programmingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROGRAMMING")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.unbound.border, lineWidth: 1)
                )
                .shadow(color: Color.unbound.bg.opacity(0.35), radius: 12, x: 0, y: 4)
                .overlay(
                    programmingColumns
                        .padding(.vertical, 20)
                        .padding(.horizontal, 8)
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var programmingColumns: some View {
        HStack(spacing: 0) {
            programmingColumn(label: "SETS", value: "\(sets)", isMono: true)
            Rectangle().fill(Color.unbound.borderSubtle)
                .frame(width: 1).padding(.vertical, 6)
            programmingColumn(label: "REPS", value: reps, isMono: false)
            Rectangle().fill(Color.unbound.borderSubtle)
                .frame(width: 1).padding(.vertical, 6)
            programmingColumn(label: "REST", value: "\(restSeconds)s", isMono: true)
        }
    }

    private func programmingColumn(label: String, value: String, isMono: Bool) -> some View {
        VStack(spacing: 6) {
            if isMono {
                Text(value)
                    .font(Font.unbound.monoL)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            } else {
                Text(value)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private func formCuesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FORM CUES")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.unbound.accent)
                    .frame(width: 24)
                Text(notes)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .background(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.unbound.bg.opacity(0.30), radius: 10, x: 0, y: 3)
        }
    }

    private func substitutionSection(sub: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SUBSTITUTION")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.unbound.textSecondary)
                    .frame(width: 24)
                Text(sub)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .background(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.unbound.bg.opacity(0.30), radius: 10, x: 0, y: 3)
        }
    }
}

// MARK: - Target Muscle Heatmap

private struct TargetMuscleHeatmapView: View {
    let muscleGroups: [MuscleGroup]
    let bodyRegions: [BodyRegion]

    // Same ranked heat scale as the rank/skill detail Target Map: specific
    // regions (quads, hamstrings, lats …) by importance tier, in distinct
    // red→amber→cyan hues (most → least worked).
    private var regions: [ProgramRankTargetRegionSet.RankedTargetRegion] {
        ProgramRankTargetRegionSet.rankedRegions(muscleGroups: muscleGroups, bodyRegions: bodyRegions)
    }

    private var rankByRegion: [BodyRegion: Int] {
        ProgramRankTargetRegionSet.rankByRegion(from: regions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                TargetMuscleBodyFigure(side: .front, rankByRegion: rankByRegion)
                TargetMuscleBodyFigure(side: .back, rankByRegion: rankByRegion)
            }
            if !regions.isEmpty {
                ProgramRankTargetRegionStrip(regions: regions)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
        .shadow(color: Color.unbound.bg.opacity(0.26), radius: 10, x: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Target muscle heatmap")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard !regions.isEmpty else { return "No target regions" }
        return regions.map(\.region.displayName).joined(separator: ", ")
    }
}

private struct TargetMuscleBodyFigure: View {
    let side: BodyMapSide
    /// region → importance rank (0 = primary mover … 2 = support). Heat-ramp
    /// tint per region; regions absent from the map stay unfilled.
    let rankByRegion: [BodyRegion: Int]

    var body: some View {
        GeometryReader { proxy in
            let viewBox = TargetMuscleSVGAsset.viewBox(for: side)
            let drawRect = Self.drawRect(in: proxy.size, viewBox: viewBox)
            let separatorWidth = max(0.65, min(1.35, drawRect.width / 245))

            ZStack {
                if let baseImage = TargetMuscleBodyImage.image(for: side) {
                    Image(uiImage: baseImage)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: drawRect.width, height: drawRect.height)
                        .position(x: drawRect.midX, y: drawRect.midY)
                        .opacity(0.96)
                }

                ForEach(TargetMuscleSVGAsset.paths(for: side)) { spec in
                    let rank = rankByRegion[spec.region]
                    let isTargeted = rank != nil

                    spec.path(in: drawRect, viewBox: viewBox)
                        .fill(
                            rank.map(ProgramRankTargetRegionSet.fillColor(forRank:)) ?? Color.clear,
                            style: FillStyle(eoFill: spec.usesEvenOdd)
                        )

                    spec.path(in: drawRect, viewBox: viewBox)
                        .stroke(
                            rank.map(ProgramRankTargetRegionSet.strokeColor(forRank:)) ?? Color.black.opacity(0.30),
                            style: StrokeStyle(
                                lineWidth: isTargeted ? separatorWidth + 0.35 : separatorWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .shadow(
                            color: rank.map { ProgramRankTargetRegionSet.color(forRank: $0).opacity(0.22) } ?? .clear,
                            radius: isTargeted ? 3 : 0
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(
            TargetMuscleSVGAsset.viewBox(for: side).width / TargetMuscleSVGAsset.viewBox(for: side).height,
            contentMode: .fit
        )
        .overlay(alignment: .topTrailing) {
            Text(side.targetMuscleShortTitle)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.unbound.bg.opacity(0.56)))
                .padding(5)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
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

private enum TargetMuscleSVGAsset {
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

    static func paths(for side: BodyMapSide) -> [TargetMuscleRegionSpec] {
        switch side {
        case .front:
            return frontAsset.paths
        case .back:
            return backAsset.paths
        }
    }

    private static func load(side: BodyMapSide) -> Loaded {
        guard let url = Bundle.main.url(
            forResource: side.targetMuscleSVGName,
            withExtension: "svg",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.targetMuscleSVGName,
            withExtension: "svg"
        ),
              let data = try? Data(contentsOf: url)
        else {
            return Loaded(viewBox: defaultViewBox, paths: [])
        }

        let parser = TargetMuscleSVGRegionParser(side: side)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        _ = xmlParser.parse()
        return Loaded(viewBox: parser.viewBox ?? defaultViewBox, paths: parser.paths)
    }

    private struct Loaded {
        let viewBox: CGSize
        let paths: [TargetMuscleRegionSpec]
    }
}

private final class TargetMuscleSVGRegionParser: NSObject, XMLParserDelegate {
    let side: BodyMapSide
    var viewBox: CGSize?
    var paths: [TargetMuscleRegionSpec] = []

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
              let region = TargetMuscleSVGRegionMapper.region(from: rawRegion),
              let pathData = attributeDict["d"]
        else { return }

        let id = attributeDict["id"] ?? "\(side.targetMuscleShortTitle)-\(rawRegion)-\(paths.count)"
        paths.append(
            TargetMuscleRegionSpec(
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

private struct TargetMuscleRegionSpec: Identifiable {
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

private enum TargetMuscleSVGRegionMapper {
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

private enum TargetMuscleBodyImage {
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
            forResource: side.targetMuscleBaseImageName,
            withExtension: "png",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.targetMuscleBaseImageName,
            withExtension: "png"
        ),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: side.targetMuscleBaseImageName)
    }
}

private extension BodyMapSide {
    var targetMuscleShortTitle: String {
        switch self {
        case .front:
            return "FRONT"
        case .back:
            return "BACK"
        }
    }

    var targetMuscleBaseImageName: String {
        switch self {
        case .front:
            return "heatmap_anime_front_v4"
        case .back:
            return "heatmap_anime_back_v4"
        }
    }

    var targetMuscleSVGName: String {
        switch self {
        case .front:
            return "source_frontmap_anime_v4_regions"
        case .back:
            return "source_backmap_anime_v4_regions"
        }
    }
}
