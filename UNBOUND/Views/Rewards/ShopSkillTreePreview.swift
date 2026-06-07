import SwiftUI

struct ShopPreviewLinework: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.24))
            path.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.24))
            path.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.68))
            path.addLine(to: CGPoint(x: size.width * 0.76, y: size.height * 0.42))
            path.move(to: CGPoint(x: size.width * 0.28, y: size.height * 0.88))
            path.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.76))
            context.stroke(path, with: .color(color), lineWidth: 1)

            for point in [
                CGPoint(x: size.width * 0.18, y: size.height * 0.24),
                CGPoint(x: size.width * 0.54, y: size.height * 0.54),
                CGPoint(x: size.width * 0.82, y: size.height * 0.76)
            ] {
                let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

struct ShopSkillTreeMapPreview: View {
    let skin: SkillTreeSkin
    let compact: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background(size: proxy.size)
                rankBands(size: proxy.size)
                ShopSkillTreeRails(skin: skin, compact: compact)
                    .padding(compact ? 10 : 18)
                nodes(size: proxy.size)
                bottomScrim
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous))
    }

    @ViewBuilder
    private func background(size: CGSize) -> some View {
        if !skin.backgroundAssetName.isEmpty,
           UIImage(named: skin.backgroundAssetName) != nil {
            Image(skin.backgroundAssetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .saturation(1.08)
                .contrast(skin.backgroundAssetContrast)
                .opacity(skin.backgroundAssetOpacity)
        } else {
            Rectangle()
                .fill(skin.nodeGradient)
        }

        Rectangle()
            .fill(skin.mapBackground)
            .blendMode(.screen)

        RadialGradient(
            colors: [
                skin.impactColor.opacity(compact ? 0.24 : 0.34),
                Color.clear
            ],
            center: .topTrailing,
            startRadius: 8,
            endRadius: max(size.width, size.height) * 0.72
        )
        .blendMode(.screen)
    }

    private func rankBands(size: CGSize) -> some View {
        VStack(spacing: compact ? 10 : 15) {
            ForEach(rankBandData) { band in
                HStack(spacing: compact ? 6 : 9) {
                    Text(band.label)
                        .font(.system(size: compact ? 5 : 8, weight: .black, design: .monospaced))
                        .tracking(compact ? 0.3 : 0.8)
                        .foregroundStyle(band.rank.rewardTextTint.opacity(0.80))
                        .frame(width: compact ? 14 : 28, alignment: .leading)

                    Capsule()
                        .fill(skin.bandTint(for: band.rank).opacity(compact ? 1.2 : 1.7))
                        .frame(height: compact ? 3 : 5)
                }
                .padding(.horizontal, compact ? 8 : 14)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, compact ? 9 : 16)
    }

    private func nodes(size: CGSize) -> some View {
        ZStack {
            ForEach(previewNodes) { node in
                ShopSkillTreePreviewNode(
                    skin: skin,
                    node: node,
                    compact: compact
                )
                .position(
                    x: size.width * node.x,
                    y: size.height * node.y
                )
            }
        }
    }

    private var bottomScrim: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.unbound.bg.opacity(compact ? 0.48 : 0.62)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var rankBandData: [ShopSkillTreePreviewBand] {
        [
            .init(rank: .ascendant, label: "S"),
            .init(rank: .vessel, label: "A"),
            .init(rank: .master, label: "B"),
            .init(rank: .forged, label: "C"),
            .init(rank: .apprentice, label: "D")
        ]
    }

    private var previewNodes: [ShopSkillTreePreviewNodeModel] {
        [
            .init(id: "apex", x: 0.50, y: 0.18, state: .locked, glyph: "bolt.fill", mythic: true),
            .init(id: "leftUpper", x: 0.30, y: 0.36, state: .locked, glyph: "lock.fill"),
            .init(id: "rightUpper", x: 0.70, y: 0.36, state: .proven, glyph: "checkmark"),
            .init(id: "mid", x: 0.50, y: 0.54, state: .proven, glyph: "flame.fill"),
            .init(id: "leftLower", x: 0.32, y: 0.73, state: .proven, glyph: "checkmark"),
            .init(id: "rightLower", x: 0.68, y: 0.73, state: .locked, glyph: "lock.fill"),
            .init(id: "root", x: 0.50, y: 0.88, state: .proven, glyph: "figure.strengthtraining.traditional")
        ]
    }
}

struct ShopSkillTreeRails: View {
    let skin: SkillTreeSkin
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let points: [String: CGPoint] = [
                "root": CGPoint(x: size.width * 0.50, y: size.height * 0.88),
                "leftLower": CGPoint(x: size.width * 0.32, y: size.height * 0.73),
                "rightLower": CGPoint(x: size.width * 0.68, y: size.height * 0.73),
                "mid": CGPoint(x: size.width * 0.50, y: size.height * 0.54),
                "leftUpper": CGPoint(x: size.width * 0.30, y: size.height * 0.36),
                "rightUpper": CGPoint(x: size.width * 0.70, y: size.height * 0.36),
                "apex": CGPoint(x: size.width * 0.50, y: size.height * 0.18)
            ]

            let rails = [
                ("root", "leftLower", false),
                ("root", "rightLower", true),
                ("leftLower", "mid", true),
                ("rightLower", "mid", false),
                ("mid", "leftUpper", false),
                ("mid", "rightUpper", true),
                ("leftUpper", "apex", false),
                ("rightUpper", "apex", true)
            ]

            for rail in rails {
                guard let from = points[rail.0], let to = points[rail.1] else { continue }
                var path = Path()
                path.move(to: from)
                let midY = (from.y + to.y) / 2
                path.addCurve(
                    to: to,
                    control1: CGPoint(x: from.x, y: midY),
                    control2: CGPoint(x: to.x, y: midY)
                )

                let color = rail.2 ? skin.impactColor : skin.primaryColor
                let style = StrokeStyle(
                    lineWidth: compact ? 2.1 : 3.2,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: rail.2 ? [] : [compact ? 4 : 7, compact ? 5 : 8]
                )
                context.stroke(path, with: .color(color.opacity(rail.2 ? 0.72 : 0.32)), style: style)
            }
        }
        .allowsHitTesting(false)
    }
}

struct ShopSkillTreePreviewNodeModel: Identifiable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let state: NodeState
    let glyph: String
    var mythic = false
}

struct ShopSkillTreePreviewBand: Identifiable {
    let rank: RankTier
    let label: String

    var id: String { label }
}

struct ShopSkillTreePreviewNode: View {
    let skin: SkillTreeSkin
    let node: ShopSkillTreePreviewNodeModel
    let compact: Bool

    private var size: CGFloat {
        if node.mythic { return compact ? 27 : 46 }
        return compact ? 21 : 36
    }

    var body: some View {
        ZStack {
            Hexagon()
                .fill(fill)
                .frame(width: size, height: size)
                .shadow(color: glow, radius: node.state == .proven ? (compact ? 6 : 12) : 0)

            Hexagon()
                .strokeBorder(border, lineWidth: node.mythic ? 1.8 : 1.2)
                .frame(width: size, height: size)

            Image(systemName: node.glyph)
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(iconColor)
                .minimumScaleFactor(0.6)
        }
    }

    private var fill: Color {
        if node.mythic { return skin.impactColor.opacity(0.24) }
        return skin.nodeFill(state: node.state, faded: false)
    }

    private var border: Color {
        skin.nodeBorder(state: node.state, faded: false, mythic: node.mythic)
    }

    private var iconColor: Color {
        switch node.state {
        case .locked: return Color.unbound.textTertiary
        case .proven: return node.mythic ? skin.impactDecalColor : skin.decalColor
        }
    }

    private var glow: Color {
        node.mythic ? skin.impactColor.opacity(0.54) : skin.nodeGlow(state: node.state, faded: false)
    }
}
