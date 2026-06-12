import Foundation
import SwiftUI
import UIKit

struct BodyLoadHeatmapView: View {
    let loads: [BodyRegion: Double]
    let plannedRegions: [BodyRegion]
    @State private var selectedRegion: BodyRegion?

    private var readings: [BodyLoadRegionReading] {
        loads
            .filter { $0.value > 0.05 }
            .map { BodyLoadRegionReading(region: $0.key, load: $0.value) }
            .sorted { lhs, rhs in
                if lhs.load == rhs.load { return lhs.region.displayName < rhs.region.displayName }
                return lhs.load > rhs.load
            }
    }

    private var topReading: BodyLoadRegionReading? {
        readings.first
    }

    private var selectedReading: BodyLoadRegionReading? {
        guard let selectedRegion else { return nil }
        return BodyLoadRegionReading(region: selectedRegion, load: loads[selectedRegion] ?? 0)
    }

    private var plannedSummary: String? {
        let regions = Array(Set(plannedRegions))
            .sorted { $0.displayName < $1.displayName }
        guard !regions.isEmpty else { return nil }

        let names = regions.prefix(2).map(\.displayName)
        if regions.count > names.count {
            return names.joined(separator: " + ") + " +\(regions.count - names.count)"
        }
        return names.joined(separator: " + ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .top, spacing: 12) {
                BodyLoadFigure(side: .front, loads: loads, selectedRegion: $selectedRegion)
                BodyLoadFigure(side: .back, loads: loads, selectedRegion: $selectedRegion)
            }

            if let selectedReading {
                BodyLoadSelectionStrip(reading: selectedReading)
            }

            footer
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.42))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.30))
                .frame(height: 0.5)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let topReading {
                VStack(alignment: .leading, spacing: 5) {
                    Text("BODY LOAD")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(topReading.region.displayName.uppercased())
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("Last 7 days")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer(minLength: 8)

                BodyLoadBandPill(band: topReading.band)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BODY LOAD")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("NO RECENT LOAD")
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            miniLegend

            Spacer(minLength: 8)

            if let plannedSummary {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(plannedSummary.uppercased())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var miniLegend: some View {
        HStack(spacing: 5) {
            ForEach(BodyLoadBand.allCases) { band in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(band.tint)
                    .frame(width: 16, height: 6)
            }
            Text("FRESH TO HEAVY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }
}

struct BodyLoadFigure: View {
    let side: BodyMapSide
    let loads: [BodyRegion: Double]
    @Binding var selectedRegion: BodyRegion?

    var body: some View {
        VStack(spacing: 8) {
            BodyLoadFigureCanvas(
                side: side,
                loads: loads,
                selectedRegion: $selectedRegion
            )
            .overlay(alignment: .topTrailing) {
                Text(side.shortTitle)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.unbound.bg.opacity(0.62))
                    )
                    .padding(5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct BodyLoadFigureCanvas: View {
    let side: BodyMapSide
    let loads: [BodyRegion: Double]
    @Binding var selectedRegion: BodyRegion?

    var body: some View {
        GeometryReader { proxy in
            let viewBox = BodyLoadSVGRegionAsset.viewBox(for: side)
            let drawRect = Self.drawRect(in: proxy.size, viewBox: viewBox)
            let separatorWidth = max(0.75, min(1.6, drawRect.width / 260))
            ZStack {
                if let baseImage = BodyLoadImageAsset.image(for: side) {
                    Image(uiImage: baseImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: drawRect.width, height: drawRect.height)
                        .position(x: drawRect.midX, y: drawRect.midY)
                        .opacity(1)
                }

                ZStack {
                    ForEach(BodyLoadSVGRegionAsset.paths(for: side)) { spec in
                        let load = loads[spec.region] ?? 0
                        let isSelected = selectedRegion == spec.region

                        spec.path(in: drawRect, viewBox: viewBox)
                            .fill(
                                BodyLoadHeatColor.color(
                                    forLoad: load,
                                    kind: spec.kind,
                                    isSelected: isSelected
                                ),
                                style: FillStyle(eoFill: spec.usesEvenOdd)
                            )
                            .blendMode(.normal)
                            .shadow(
                                color: BodyLoadHeatColor.color(forLoad: load, kind: .stroke)
                                    .opacity(load > 0.5 ? 0.20 : 0),
                                radius: spec.kind == .stroke ? 2 : 0
                            )

                        spec.path(in: drawRect, viewBox: viewBox)
                            .stroke(
                                BodyLoadHeatColor.separatorColor(
                                    forLoad: load,
                                    isSelected: isSelected
                                ),
                                style: StrokeStyle(
                                    lineWidth: separatorWidth,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )

                        if isSelected {
                            spec.path(in: drawRect, viewBox: viewBox)
                                .stroke(
                                    BodyLoadHeatColor.selectionColor(forLoad: load),
                                    style: StrokeStyle(
                                        lineWidth: separatorWidth + 1.05,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                                .shadow(
                                    color: BodyLoadHeatColor.selectionColor(forLoad: load).opacity(0.42),
                                    radius: 5
                                )
                        }
                    }
                }

                ZStack {
                    ForEach(BodyLoadSVGRegionAsset.paths(for: side)) { spec in
                        let load = loads[spec.region] ?? 0

                        spec.path(in: drawRect, viewBox: viewBox)
                            .fill(Color.white.opacity(0.001), style: FillStyle(eoFill: spec.usesEvenOdd))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                                    selectedRegion = spec.region
                                }
                                UnboundHaptics.medium()
                            }
                            .accessibilityLabel("\(spec.region.displayName) body load")
                            .accessibilityValue(Text(BodyLoadRegionReading(region: spec.region, load: load).accessibilityValue))
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(BodyLoadSVGRegionAsset.viewBox(for: side).width / BodyLoadSVGRegionAsset.viewBox(for: side).height, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

enum BodyLoadSVGRegionAsset {
    static let defaultViewBox = CGSize(width: 1280, height: 1908)
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

    static func paths(for side: BodyMapSide) -> [BodyLoadRegionSpec] {
        switch side {
        case .front:
            return frontAsset.paths
        case .back:
            return backAsset.paths
        }
    }

    private static func load(side: BodyMapSide) -> Loaded {
        guard let url = Bundle.main.url(
            forResource: side.bodyLoadSVGName,
            withExtension: "svg",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.bodyLoadSVGName,
            withExtension: "svg"
        ),
              let data = try? Data(contentsOf: url)
        else {
            return Loaded(viewBox: defaultViewBox, paths: [])
        }

        let parser = BodyLoadSVGRegionParser(side: side)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        _ = xmlParser.parse()
        return Loaded(viewBox: parser.viewBox ?? defaultViewBox, paths: parser.paths)
    }

    private struct Loaded {
        let viewBox: CGSize
        let paths: [BodyLoadRegionSpec]
    }
}

final class BodyLoadSVGRegionParser: NSObject, XMLParserDelegate {
    let side: BodyMapSide
    var viewBox: CGSize?
    var paths: [BodyLoadRegionSpec] = []

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
              let region = BodyLoadSVGRegionMapper.region(from: rawRegion),
              let pathData = attributeDict["d"]
        else { return }

        let id = attributeDict["id"] ?? "\(side.shortTitle)-\(rawRegion)-\(paths.count)"
        let className = attributeDict["class"] ?? ""
        let kind: BodyLoadPathKind = id.contains("-stroke") || className.contains("stroke")
            ? .stroke
            : .fill

        paths.append(
            BodyLoadRegionSpec(
                id: id,
                region: region,
                kind: kind,
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

struct BodyLoadRegionSpec: Identifiable {
    let id: String
    let region: BodyRegion
    let kind: BodyLoadPathKind
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

enum BodyLoadSVGRegionMapper {
    static func region(from rawValue: String) -> BodyRegion? {
        switch rawValue {
        case "deltoids":
            return .shoulders
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

enum BodyLoadImageAsset {
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
            forResource: side.bodyLoadBaseImageName,
            withExtension: "png",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.bodyLoadBaseImageName,
            withExtension: "png"
        ),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: side.bodyLoadBaseImageName)
    }
}

enum BodyLoadPathKind {
    case fill
    case stroke
}

enum BodyLoadHeatColor {
    static func color(forLoad load: Double, kind: BodyLoadPathKind, isSelected: Bool = false) -> Color {
        if isSelected, load < 0.5 {
            return Color.white.opacity(0.10)
        }

        guard load >= 0.5 else {
            return Color.clear
        }

        let band = BodyLoadBand.band(for: load)
        let intensity = min(1, max(0.18, load / BodyLoadBand.heavyThreshold))

        switch kind {
        case .fill:
            return band.tint.opacity(0.42 + intensity * 0.40)
        case .stroke:
            return band.tint.opacity(0.78 + intensity * 0.18)
        }
    }

    static func separatorColor(forLoad load: Double, isSelected: Bool) -> Color {
        if isSelected {
            return selectionColor(forLoad: load).opacity(0.82)
        }
        return load >= 0.5
            ? Color.black.opacity(0.52)
            : Color.black.opacity(0.34)
    }

    static func selectionColor(forLoad load: Double) -> Color {
        guard load >= 0.5 else {
            return Color.white.opacity(0.86)
        }
        return BodyLoadBand.band(for: load).tint
    }
}

struct BodyLoadRegionReading: Identifiable {
    var id: BodyRegion { region }
    let region: BodyRegion
    let load: Double

    var band: BodyLoadBand {
        BodyLoadBand.band(for: load)
    }

    var loadText: String {
        if load < 1 {
            return "<1"
        }
        return "\(Int(load.rounded()))"
    }

    var accessibilityValue: String {
        "\(band.label), \(loadText) recent load"
    }
}

struct BodyLoadSelectionStrip: View {
    let reading: BodyLoadRegionReading

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(reading.band.tint)
                .frame(width: 8, height: 8)
                .shadow(color: reading.band.tint.opacity(0.55), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(reading.region.displayName.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)

                Text("\(reading.band.label.uppercased()) · \(reading.loadText) LOAD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 8)

            Image(systemName: "scope")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(reading.band.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.unbound.bg.opacity(0.42))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(reading.band.tint.opacity(0.34), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
    }
}

struct BodyLoadBandPill: View {
    let band: BodyLoadBand

    var body: some View {
        Text(band.label.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(band.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(band.tint.opacity(0.13))
            )
            .overlay(
                Capsule()
                    .strokeBorder(band.tint.opacity(0.28), lineWidth: 1)
            )
    }
}

enum BodyLoadBand: CaseIterable, Identifiable {
    case fresh
    case steady
    case high
    case heavy

    static let heavyThreshold: Double = 22

    var id: String { label }

    static func band(for load: Double) -> BodyLoadBand {
        let displayedLoad = load < 1 ? load : Double(Int(load.rounded()))
        switch displayedLoad {
        case ..<6:
            return .fresh
        case ..<13:
            return .steady
        case ..<heavyThreshold:
            return .high
        default:
            return .heavy
        }
    }

    var label: String {
        switch self {
        case .fresh:
            return "Fresh"
        case .steady:
            return "Steady"
        case .high:
            return "High"
        case .heavy:
            return "Heavy"
        }
    }

    var rangeLabel: String {
        switch self {
        case .fresh:
            return "0-5"
        case .steady:
            return "6-12"
        case .high:
            return "13-21"
        case .heavy:
            return "22+"
        }
    }

    var tint: Color {
        switch self {
        case .fresh:
            return Color.unbound.rankGreen
        case .steady:
            return Color.unbound.rankAmber
        case .high:
            return Color.unbound.warnOrange
        case .heavy:
            return Color.unbound.alert
        }
    }
}

extension BodyMapSide {
    var shortTitle: String {
        switch self {
        case .front:
            return "FRONT"
        case .back:
            return "BACK"
        }
    }

    var bodyLoadBaseImageName: String {
        switch self {
        case .front:
            return "heatmap_anime_front_v4"
        case .back:
            return "heatmap_anime_back_v4"
        }
    }

    var bodyLoadSVGName: String {
        switch self {
        case .front:
            return "source_frontmap_anime_v4_regions"
        case .back:
            return "source_backmap_anime_v4_regions"
        }
    }
}
