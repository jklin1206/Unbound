import SwiftUI

// MARK: - SkillGraphConcept (throwaway)
//
// Chunk 1.5 concept preview for the unified Skill Graph v2 redesign.
// Option B — cluster-first drill-in.
//
// Home:   6 cluster tiles in a 2×3 grid + a "Skills to Chase" keystone hero row.
// Detail: one cluster's mini-graph (Pulling Power — 9 nodes, 1 keystone).
//
// NO logic. NO persistence. Hardcoded sample states. Pure layout validation.
// Delete after Chunk 4 ships the real SkillGraphView.

// MARK: - Sample data

fileprivate enum ConceptCluster: CaseIterable, Hashable {
    case heavyLifting, legDominance, pullingPower, calisthenicControl, coreLever, conditioning

    var name: String {
        switch self {
        case .heavyLifting:       return "Heavy Lifting"
        case .legDominance:       return "Leg Dominance"
        case .pullingPower:       return "Pulling Power"
        case .calisthenicControl: return "Calisthenic Control"
        case .coreLever:          return "Core"
        case .conditioning:       return "Conditioning"
        }
    }

    var glyph: String {
        switch self {
        case .heavyLifting:       return "dumbbell.fill"
        case .legDominance:       return "figure.walk"
        case .pullingPower:       return "figure.climbing"
        case .calisthenicControl: return "figure.flexibility"
        case .coreLever:          return "figure.core.training"
        case .conditioning:       return "flame.fill"
        }
    }

    /// Hardcoded sample progress for the concept. (unlocked, total)
    var progress: (Int, Int) {
        switch self {
        case .heavyLifting:       return (3, 9)
        case .legDominance:       return (1, 7)
        case .pullingPower:       return (4, 9)
        case .calisthenicControl: return (2, 7)
        case .coreLever:          return (1, 6)
        case .conditioning:       return (2, 6)
        }
    }

    var attemptingChip: String {
        switch self {
        case .heavyLifting:       return "1.5× Deadlift"
        case .legDominance:       return "100 Lunges"
        case .pullingPower:       return "10 Pullups"
        case .calisthenicControl: return "L-Sit 20s"
        case .coreLever:          return "Leg Raises × 10"
        case .conditioning:       return "Dead Hang 60s"
        }
    }
}

fileprivate struct ConceptKeystone: Identifiable {
    let id = UUID()
    let title: String
    let clusterName: String
    let progressPct: Double        // 0.0 – 1.0
    let glyph: String
    let achieved: Bool

    static let sample: [ConceptKeystone] = [
        .init(title: "Muscle-Up",             clusterName: "Pulling Power",       progressPct: 0.55, glyph: "figure.climbing",              achieved: false),
        .init(title: "2× Deadlift",            clusterName: "Heavy Lifting",       progressPct: 0.78, glyph: "dumbbell.fill",                achieved: false),
        .init(title: "Pistol Squat",           clusterName: "Leg Dominance",       progressPct: 0.20, glyph: "figure.walk",                  achieved: false),
        .init(title: "Freestanding Handstand", clusterName: "Calisthenic Control", progressPct: 0.35, glyph: "figure.flexibility",           achieved: false),
        .init(title: "Dragon Flag",            clusterName: "Core",                progressPct: 0.10, glyph: "figure.core.training",         achieved: false),
        .init(title: "1.5× BW Farmer Carry",    clusterName: "Conditioning",        progressPct: 0.40, glyph: "flame.fill",                   achieved: false)
    ]
}

// MARK: - Home (6 cluster tiles + keystone hero row)

struct SkillGraphHomeConcept: View {
    @State private var pushDetail = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    keystoneHeroRow

                    clusterGrid

                    footerHint
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.unbound.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("YOUR SKILL MAP")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.2)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
            .navigationDestination(isPresented: $pushDetail) {
                ClusterDetailConcept()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where you're building")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("You started in Pulling Power + Calisthenic Control. Every cluster is open — follow what pulls you.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Keystone hero row

    private var keystoneHeroRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SKILLS TO CHASE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("6 keystones")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ConceptKeystone.sample) { k in
                        keystoneCard(k)
                    }
                }
            }
        }
    }

    private func keystoneCard(_ k: ConceptKeystone) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: k.glyph)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                Spacer()
                // Star / keystone mark
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.unbound.impact)
                    .padding(6)
                    .background(Circle().fill(Color.unbound.impact.opacity(0.12)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(k.title)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(k.clusterName.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer(minLength: 0)
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.unbound.border)
                        Capsule()
                            .fill(Color.unbound.accent)
                            .frame(width: max(4, geo.size.width * k.progressPct))
                    }
                }
                .frame(height: 4)
                Text("\(Int(k.progressPct * 100))%")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
        .padding(16)
        .frame(width: 180, height: 200)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    // MARK: Cluster grid

    private var clusterGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CLUSTERS")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("44 total skills")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(ConceptCluster.allCases, id: \.self) { c in
                    clusterTile(c)
                        .onTapGesture {
                            if c == .pullingPower {
                                pushDetail = true
                            }
                        }
                }
            }
        }
    }

    private func clusterTile(_ c: ConceptCluster) -> some View {
        let (unlocked, total) = c.progress
        let pct = total == 0 ? 0 : Double(unlocked) / Double(total)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                // Cluster glyph tile
                Image(systemName: c.glyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                Spacer()
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.unbound.border, lineWidth: 3)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(Color.unbound.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 36, height: 36)
                    Text("\(unlocked)")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(c.name)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(unlocked) / \(total) unlocked")
                    .font(Font.unbound.captionS)
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer(minLength: 0)
            // Attempting chip
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 6, height: 6)
                Text(c.attemptingChip)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.unbound.surfaceElevated)
            )
        }
        .padding(16)
        .frame(height: 200)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    // MARK: Footer hint

    private var footerHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("Tap Pulling Power to see one cluster in detail.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Cluster detail (Pulling Power mini-graph)

struct ClusterDetailConcept: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                detailHeader
                miniGraph
                crossClusterCallouts
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("PULLING POWER")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
    }

    private var detailHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "figure.climbing")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Pulling Power")
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Hangs · pullups · muscle-up · rows")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("4 / 9 unlocked · Keystone: Muscle-Up")
                    .font(Font.unbound.captionS)
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Mini-graph

    private var miniGraph: some View {
        // Layout: row × col grid. 4 rows, 3 columns (-1 / 0 / +1).
        // Node positions per Pulling Power spec:
        //   PP-1 (0, 0)
        //   PP-2 (1, 0)
        //   PP-3 (2, 0)
        //   PP-4 (3, 0)
        //   PP-5 (4, -1)
        //   PP-6 (4, +1)
        //   PP-7 (5, -1)
        //   PP-8 (5, +1)
        //   PP-9 (6, 0)  ⭐ keystone

        let nodes: [ConceptNode] = [
            .init(id: "PP-1", title: "Dead Hang 30s",         state: .achieved,   row: 0, col: 0,  keystone: false),
            .init(id: "PP-2", title: "Negative Pullup × 3",   state: .achieved,   row: 1, col: 0,  keystone: false),
            .init(id: "PP-3", title: "First Pullup",          state: .achieved,   row: 2, col: 0,  keystone: false),
            .init(id: "PP-4", title: "5 Pullups",             state: .achieved,   row: 3, col: 0,  keystone: false),
            .init(id: "PP-5", title: "10 Pullups",            state: .attempting, row: 4, col: -1, keystone: false),
            .init(id: "PP-6", title: "Chest-to-Bar × 5",      state: .locked,     row: 4, col:  1, keystone: false),
            .init(id: "PP-7", title: "Weighted Pullup ¼×",    state: .locked,     row: 5, col: -1, keystone: false),
            .init(id: "PP-8", title: "False-Grip × 3",         state: .locked,     row: 5, col:  1, keystone: false),
            .init(id: "PP-9", title: "Muscle-Up",             state: .locked,     row: 6, col: 0,  keystone: true)
        ]
        let edges: [(String, String)] = [
            ("PP-1","PP-2"), ("PP-2","PP-3"), ("PP-3","PP-4"),
            ("PP-4","PP-5"), ("PP-4","PP-6"),
            ("PP-5","PP-7"), ("PP-6","PP-7"), ("PP-6","PP-8"),
            ("PP-5","PP-9"), ("PP-8","PP-9"), ("PP-7","PP-9")
        ]

        let rowCount = (nodes.map(\.row).max() ?? 0) + 1
        let rowHeight: CGFloat = 120
        let colSpacing: CGFloat = 110
        let height = CGFloat(rowCount) * rowHeight + 40

        return GeometryReader { geo in
            let centerX = geo.size.width / 2
            ZStack {
                // Edges
                Canvas { ctx, _ in
                    for (fromId, toId) in edges {
                        guard let from = nodes.first(where: { $0.id == fromId }),
                              let to = nodes.first(where: { $0.id == toId }) else { continue }
                        let p1 = CGPoint(
                            x: centerX + CGFloat(from.col) * colSpacing,
                            y: CGFloat(from.row) * rowHeight + rowHeight/2 + 20
                        )
                        let p2 = CGPoint(
                            x: centerX + CGFloat(to.col) * colSpacing,
                            y: CGFloat(to.row) * rowHeight + rowHeight/2 + 20
                        )
                        var path = Path()
                        path.move(to: p1); path.addLine(to: p2)
                        let reachable = from.state == .achieved || from.state == .mastered || to.state != .locked
                        ctx.stroke(
                            path,
                            with: .color(reachable ? Color.unbound.accent.opacity(0.55) : Color.unbound.border),
                            style: StrokeStyle(
                                lineWidth: 1.5,
                                lineCap: .round,
                                dash: reachable ? [] : [3,5]
                            )
                        )
                    }
                }
                // Nodes
                ForEach(nodes) { n in
                    ConceptNodeHexagon(node: n)
                        .position(
                            x: centerX + CGFloat(n.col) * colSpacing,
                            y: CGFloat(n.row) * rowHeight + rowHeight/2 + 20
                        )
                }
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: CGFloat(rowCount) * rowHeight + 40)
    }

    // MARK: Cross-cluster callouts

    private var crossClusterCallouts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CROSS-CLUSTER PATHS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2)
                .foregroundStyle(Color.unbound.textSecondary)
                .padding(.top, 12)

            calloutRow(
                glyph: "arrow.triangle.branch",
                title: "Muscle-Up has an alternate path",
                body: "Weighted Pullup ¼× BW + L-Sit 20s (from Calisthenic Control) also unlocks it."
            )
            calloutRow(
                glyph: "link",
                title: "Your 10 Pullups helps Heavy Lifting",
                body: "Hitting 10 Pullups is one of two paths to unlock the 2× Deadlift keystone."
            )
        }
    }

    private func calloutRow(glyph: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: glyph)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(Color.unbound.accent.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(body)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }
}

// MARK: - Concept node hexagon (simplified)

fileprivate enum ConceptNodeState { case locked, attempting, achieved, mastered }

fileprivate struct ConceptNode: Identifiable, Hashable {
    let id: String
    let title: String
    let state: ConceptNodeState
    let row: Int
    let col: Int
    let keystone: Bool
}

fileprivate struct ConceptNodeHexagon: View {
    let node: ConceptNode

    private var size: CGFloat { node.keystone ? 98 : 72 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Hexagon().fill(fill).frame(width: size, height: size)
                Hexagon().fill(.thinMaterial).opacity(0.08).frame(width: size, height: size)
                Hexagon().strokeBorder(border, lineWidth: node.keystone ? 2 : 1.5).frame(width: size, height: size)
                if node.keystone && node.state != .locked {
                    Hexagon()
                        .strokeBorder(Color.unbound.impact, lineWidth: 1)
                        .frame(width: size + 12, height: size + 12)
                        .shadow(color: Color.unbound.impact.opacity(0.55), radius: 12)
                }
                glyph
            }
            .shadow(color: glow, radius: node.state == .locked ? 0 : 10)

            Text(node.title)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(node.state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary)
                .tracking(0.4)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 96)

            if node.keystone {
                Text("KEYSTONE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.impact)
            }
        }
    }

    private var fill: Color {
        switch node.state {
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.surface
        case .achieved:   return Color.unbound.accent.opacity(0.18)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    private var border: Color {
        switch node.state {
        case .locked:     return Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent
        case .mastered:   return Color.unbound.impact
        }
    }

    private var glow: Color {
        switch node.state {
        case .locked:     return .clear
        case .attempting: return Color.unbound.accent.opacity(0.4)
        case .achieved:   return Color.unbound.accent.opacity(0.55)
        case .mastered:   return Color.unbound.impact.opacity(0.6)
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch node.state {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: node.keystone ? 22 : 18, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .attempting:
            Image(systemName: node.keystone ? "star.fill" : "figure.climbing")
                .font(.system(size: node.keystone ? 26 : 22, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        case .achieved:
            Image(systemName: "checkmark")
                .font(.system(size: node.keystone ? 28 : 22, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        case .mastered:
            Image(systemName: "crown.fill")
                .font(.system(size: node.keystone ? 28 : 22, weight: .semibold))
                .foregroundStyle(Color.unbound.impact)
        }
    }
}

// MARK: - Previews

#Preview("Skill Graph — Home (Option B)") {
    SkillGraphHomeConcept()
}

#Preview("Skill Graph — Cluster Detail (PP)") {
    NavigationStack {
        ClusterDetailConcept()
    }
    .preferredColorScheme(.dark)
}
