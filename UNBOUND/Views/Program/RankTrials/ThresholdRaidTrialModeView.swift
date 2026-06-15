import SwiftUI

struct ThresholdRaidTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var nodes: [ThresholdRaidReadyNode] {
        blocks.enumerated().map { index, block in
            ThresholdRaidReadyNode(index: index, block: block)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                ThresholdRaidReadyMap(nodes: nodes, tint: tint)
                    .frame(width: 132, height: 250)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("THRESHOLD RAID")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(tint)

                    Text("Break three phase gates: engine repeat, breach work, control hold.")
                        .font(Font.unbound.bodyM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        RankTrialInfoChip(text: "\(nodes.count) stations", icon: "point.3.connected.trianglepath.dotted", tint: tint, strokeOpacity: 0.3)
                        RankTrialInfoChip(text: "3 gates", icon: "shield.lefthalf.filled", tint: tint, strokeOpacity: 0.3)
                    }
                }
                .layoutPriority(1)
            }

            VStack(spacing: 10) {
                ForEach(ThresholdRaidPhase.readyPhases(for: nodes)) { phase in
                    ThresholdRaidReadyPhaseRow(phase: phase, tint: tint)
                }
            }
            .accessibilityIdentifier("workoutReady.thresholdRaidPhases")
        }
    }

}

private enum ThresholdRaidPhase: Int, CaseIterable, Identifiable {
    case engine = 1
    case breach = 2
    case control = 3

    var id: Int { rawValue }

    var displayTitle: String {
        switch self {
        case .engine: return "Stage 1: Engine Repeats"
        case .breach: return "Stage 2: Breach Work"
        case .control: return "Stage 3: Control Hold"
        }
    }

    var shortTitle: String {
        switch self {
        case .engine: return "Engine"
        case .breach: return "Breach"
        case .control: return "Control"
        }
    }

    var icon: String {
        switch self {
        case .engine: return "repeat"
        case .breach: return "bolt.shield.fill"
        case .control: return "timer"
        }
    }

    var color: Color {
        switch self {
        case .engine: return Color.unbound.coachCyan
        case .breach: return Color.unbound.impact
        case .control: return Color.unbound.rankGold
        }
    }

    static func phase(for title: String, fallbackIndex: Int) -> ThresholdRaidPhase {
        let lowercased = title.lowercased()
        if lowercased.contains("stage 1") || lowercased.contains("engine") {
            return .engine
        }
        if lowercased.contains("stage 3") || lowercased.contains("control") || lowercased.contains("hold") {
            return .control
        }
        if lowercased.contains("stage 2") || lowercased.contains("carry") || lowercased.contains("raid") {
            return .breach
        }
        if fallbackIndex == 0 { return .engine }
        return fallbackIndex >= 4 ? .control : .breach
    }

    static func readyPhases(for nodes: [ThresholdRaidReadyNode]) -> [ThresholdRaidReadyPhase] {
        ThresholdRaidPhase.allCases.map { phase in
            let phaseNodes = nodes.filter { $0.phase == phase }
            return ThresholdRaidReadyPhase(phase: phase, nodes: phaseNodes)
        }
    }
}

private struct ThresholdRaidReadyNode: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }
    var phase: ThresholdRaidPhase { ThresholdRaidPhase.phase(for: block.title, fallbackIndex: index) }
    var title: String { block.title }
    var prescription: TrainingBlockPrescription? { block.prescriptions.first }
    var exerciseName: String { prescription?.exerciseName ?? block.title }

    var summary: String {
        guard let prescription else { return "Official gate" }
        var parts = ["\(prescription.sets)x \(prescription.displayTargetText)"]
        if prescription.restSeconds > 0 {
            parts.append("\(Self.mmss(prescription.restSeconds)) rest")
        }
        if let rpe = prescription.rpe {
            parts.append("RPE \(rpe)")
        }
        return parts.joined(separator: " / ")
    }

    var movementDefinition: MovementDefinition? {
        guard let prescription else { return nil }
        return MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
    }

    var fallbackIcon: String {
        switch block.kind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }

    private static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct ThresholdRaidReadyPhase: Identifiable {
    let phase: ThresholdRaidPhase
    let nodes: [ThresholdRaidReadyNode]

    var id: Int { phase.rawValue }
}

private struct ThresholdRaidReadyPhaseRow: View {
    let phase: ThresholdRaidReadyPhase
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                ThresholdRaidDiamond()
                    .fill(phase.phase.color.opacity(0.22))
                ThresholdRaidDiamond()
                    .stroke(phase.phase.color.opacity(0.64), lineWidth: 1.2)
                Image(systemName: phase.phase.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(phase.phase.color)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(phase.phase.displayTitle.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(phase.phase.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("\(phase.nodes.count)")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .foregroundStyle(Color.unbound.bg)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(tint))
                }

                if let primary = phase.nodes.first {
                    HStack(spacing: 10) {
                        if let definition = primary.movementDefinition {
                            ExerciseVisualView(definition: definition, size: .thumbnail)
                                .frame(width: 46, height: 38)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: primary.fallbackIcon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(phase.phase.color)
                                .frame(width: 46, height: 38)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(primary.exerciseName)
                                .font(Font.unbound.bodyS.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(primary.summary)
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .layoutPriority(1)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct ThresholdRaidReadyMap: View {
    let nodes: [ThresholdRaidReadyNode]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let points = Self.points(in: proxy.size, count: nodes.count)

            ZStack {
                ThresholdRaidMapPlate()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.bg.opacity(0.96),
                                Color.unbound.surfaceElevated.opacity(0.9),
                                tint.opacity(0.2)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    .overlay(ThresholdRaidMapPlate().stroke(tint.opacity(0.34), lineWidth: 1.2))

                ThresholdRaidPath(points: points)
                    .stroke(tint.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [7, 6]))

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    ZStack {
                        ThresholdRaidDiamond()
                            .fill(node.phase.color.opacity(0.24))
                        ThresholdRaidDiamond()
                            .stroke(node.phase.color.opacity(0.76), lineWidth: index == 0 || index == nodes.count - 1 ? 1.8 : 1.2)
                        Text("\(node.phase.rawValue)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                    .frame(width: index == 0 || index == nodes.count - 1 ? 34 : 28, height: index == 0 || index == nodes.count - 1 ? 34 : 28)
                    .position(point(at: index, in: points))
                }
            }
        }
    }

    private func point(at index: Int, in points: [CGPoint]) -> CGPoint {
        points.indices.contains(index) ? points[index] : .zero
    }

    private static func points(in size: CGSize, count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let usableWidth = max(1, size.width - 34)
        let step = count == 1 ? 0 : usableWidth / CGFloat(count - 1)
        return (0..<count).map { index in
            let x = 17 + CGFloat(index) * step
            let wave = CGFloat(index % 2 == 0 ? -1 : 1)
            let y = (size.height * 0.5) + (wave * size.height * 0.2)
            return CGPoint(x: x, y: min(max(24, y), size.height - 24))
        }
    }
}

private struct ThresholdRaidPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct ThresholdRaidMapPlate: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = min(rect.width, rect.height) * 0.12
        path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + notch))
        path.addLine(to: CGPoint(x: rect.maxX - notch * 0.55, y: rect.maxY - notch * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + notch * 0.85, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX + notch * 0.45, y: rect.minY + notch * 0.6))
        path.closeSubpath()
        return path
    }
}

private struct ThresholdRaidDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
