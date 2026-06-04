import SwiftUI

struct TowerTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var floors: [TowerReadyFloor] {
        blocks.enumerated().map { index, block in
            TowerReadyFloor(index: index, block: block)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                TowerReadySilhouette(totalFloors: towerFloorCount, tint: tint)
                    .frame(width: 112, height: 260)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("10-FLOOR ASCENT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(tint)
                    Text("Climb one floor at a time. The top floor is the boss hold.")
                        .font(Font.unbound.bodyM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        towerChip("\(floors.count) stations", icon: "square.stack.3d.up")
                        towerChip("Boss hold", icon: "timer")
                    }
                }
                .layoutPriority(1)
            }

            VStack(spacing: 0) {
                ForEach(floors) { floor in
                    floorRow(floor)
                }
            }
            .accessibilityIdentifier("workoutReady.towerFloors")
        }
    }

    private var towerFloorCount: Int {
        max(1, Set(floors.map(\.number)).count)
    }

    private func floorRow(_ floor: TowerReadyFloor) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(floor.index == 0 ? Color.clear : tint.opacity(0.28))
                    .frame(width: 2, height: 12)
                ZStack {
                    Circle()
                        .strokeBorder(tint.opacity(floor.isBossFloor ? 0.88 : 0.46), lineWidth: 1.4)
                    Text(floor.numberString)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(floor.isBossFloor ? tint : Color.unbound.textPrimary)
                }
                .frame(width: 28, height: 28)
                Rectangle()
                    .fill(floor.index == floors.count - 1 ? Color.clear : tint.opacity(0.28))
                    .frame(width: 2, height: 12)
            }

            if let definition = floor.movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 54, height: 48)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: floor.fallbackIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 48)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(floor.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(floor.isBossFloor ? tint : Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(floor.exerciseName)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(floor.summary)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func towerChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Capsule().fill(Color.unbound.surfaceElevated))
            .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }
}

private struct TowerReadyFloor: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }
    var number: Int { Self.floorNumber(from: block.title) ?? (index + 1) }
    var numberString: String { number < 10 ? "0\(number)" : "\(number)" }
    var isBossFloor: Bool { number >= 10 || block.title.localizedCaseInsensitiveContains("boss") }

    var title: String {
        block.title
            .replacingOccurrences(of: "Floor \(number) ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var prescription: TrainingBlockPrescription? {
        block.prescriptions.first
    }

    var exerciseName: String {
        prescription?.exerciseName ?? block.title
    }

    var summary: String {
        guard let prescription else { return "Official floor" }
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

    private static func floorNumber(from title: String) -> Int? {
        let pieces = title.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        guard let floorIndex = pieces.firstIndex(where: { $0.caseInsensitiveCompare("floor") == .orderedSame }),
              pieces.indices.contains(floorIndex + 1)
        else { return nil }
        return Int(pieces[floorIndex + 1])
    }
}

private struct TowerReadySilhouette: View {
    let totalFloors: Int
    let tint: Color

    var body: some View {
        ZStack {
            TowerTaperShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.24),
                            Color.unbound.surfaceElevated.opacity(0.94),
                            Color.unbound.bg.opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(TowerTaperShape().stroke(tint.opacity(0.42), lineWidth: 1.2))

            VStack(spacing: 8) {
                ForEach((1...totalFloors).reversed(), id: \.self) { floor in
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { window in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(windowTint(floor: floor, window: window))
                                .frame(height: floor == totalFloors ? 8 : 6)
                        }
                    }
                    .padding(.horizontal, floor == totalFloors ? 24 : 18)
                }
            }
            .padding(.vertical, 22)

            VStack {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 13, weight: .black))
                    .rotationEffect(.degrees(180))
                    .foregroundStyle(tint)
                Spacer()
                Text("START")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.bottom, 10)
            }
        }
    }

    private func windowTint(floor: Int, window: Int) -> Color {
        if floor == totalFloors { return tint.opacity(0.95) }
        if floor % 2 == window % 2 { return Color.unbound.coachCyan.opacity(0.44) }
        return Color.unbound.textPrimary.opacity(0.18)
    }
}

private struct TowerTaperShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * 0.22
        let bottomInset = rect.width * 0.04
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
