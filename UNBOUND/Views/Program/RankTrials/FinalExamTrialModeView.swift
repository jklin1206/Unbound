import SwiftUI

struct FinalExamTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var sections: [FinalExamSectionDraft] {
        FinalExamSectionDraft.group(blocks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            readyHeader

            VStack(spacing: 12) {
                ForEach(sections) { section in
                    FinalExamReadySection(section: section, tint: tint)
                }
            }
            .accessibilityIdentifier("workoutReady.theLastGateSections")
        }
    }

    private var readyHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            FinalExamVerdictSeal(
                title: "FINAL",
                subtitle: "EXAM",
                tint: tint,
                pulse: false
            )
            .frame(width: 104, height: 104)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 9) {
                Text("ASCENSION DOSSIER")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.7)
                    .foregroundStyle(tint)

                Text("Three parts. One verdict.")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 6)], alignment: .leading, spacing: 6) {
                    FinalExamCapsule(label: "A", value: "Control", icon: "bolt.fill", tint: Color.unbound.emberGlow)
                    FinalExamCapsule(label: "B", value: "Capacity", icon: "waveform.path.ecg", tint: Color.unbound.coachCyan)
                    FinalExamCapsule(label: "C", value: "Finish", icon: "seal.fill", tint: tint)
                }
            }
            .layoutPriority(1)
        }
        .padding(14)
        .background(
            FinalExamDossierShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.18),
                            Color.unbound.surface.opacity(0.95),
                            Color.unbound.bg.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            FinalExamDossierShape()
                .strokeBorder(tint.opacity(0.34), lineWidth: 1)
        )
    }
}

private struct FinalExamReadySection: View {
    let section: FinalExamSectionDraft
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                FinalExamPhaseBadge(part: section.part)
                Text(section.part.callout)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text("\(section.items.count)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(section.part.tint)
                    .monospacedDigit()
            }

            ForEach(section.items) { item in
                HStack(alignment: .center, spacing: 11) {
                    if let definition = item.movementDefinition {
                        ExerciseVisualView(definition: definition, size: .thumbnail)
                            .frame(width: 54, height: 48)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: item.fallbackIcon)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(section.part.tint)
                            .frame(width: 54, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.unbound.surfaceElevated)
                            )
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(0.8)
                            .foregroundStyle(section.part.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(item.exerciseName)
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(item.summary)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .layoutPriority(1)

                    FinalExamMiniStamp(text: item.part.rawValue, tint: item.part.tint)
                        .frame(width: 42, height: 42)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(section.part.tint.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct FinalExamCapsule: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
            Text(label)
                .font(Font.unbound.monoS.weight(.bold))
            Text(value)
                .font(Font.unbound.captionS.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .padding(.horizontal, 8)
        .frame(height: 27)
        .background(Capsule().fill(tint.opacity(0.18)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.38), lineWidth: 1))
    }
}

private struct FinalExamPhaseBadge: View {
    let part: FinalExamPart

    var body: some View {
        HStack(spacing: 6) {
            Text(part.rawValue)
                .font(Font.unbound.monoS.weight(.black))
                .monospacedDigit()
            Text(part.shortTitle.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .padding(.horizontal, 9)
        .frame(height: 27)
        .background(Capsule().fill(part.tint.opacity(0.18)))
        .overlay(Capsule().strokeBorder(part.tint.opacity(0.42), lineWidth: 1))
    }
}

private struct FinalExamVerdictSeal: View {
    let title: String
    let subtitle: String
    let tint: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(pulse ? 0.36 : 0.24),
                            Color.unbound.surfaceElevated.opacity(0.96),
                            Color.unbound.bg.opacity(0.98)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 58
                    )
                )
                .shadow(color: tint.opacity(pulse ? 0.34 : 0.18), radius: pulse ? 20 : 10)

            Circle()
                .strokeBorder(tint.opacity(0.68), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .rotationEffect(.degrees(pulse ? 8 : -4))

            Circle()
                .strokeBorder(Color.unbound.textPrimary.opacity(0.22), lineWidth: 1)
                .padding(10)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: title.count > 4 ? 13 : 16, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(subtitle)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct FinalExamMiniStamp: View {
    let text: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(tint.opacity(0.56), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            Text(text)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
        }
        .rotationEffect(.degrees(-9))
    }
}

private struct FinalExamDossierShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut: CGFloat = min(24, min(r.width, r.height) * 0.18)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + 14, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - cut, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + cut))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 14))
        path.addQuadCurve(to: CGPoint(x: r.maxX - 14, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + cut, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - cut))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + 14))
        path.addQuadCurve(to: CGPoint(x: r.minX + 14, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

private struct FinalExamSectionDraft: Identifiable {
    let part: FinalExamPart
    let items: [FinalExamReadyItem]

    var id: String { part.rawValue }

    static func group(_ blocks: [TrainingBlock]) -> [FinalExamSectionDraft] {
        let items = blocks.enumerated().map { index, block in
            FinalExamReadyItem(index: index, block: block)
        }
        return FinalExamPart.allCases.compactMap { part in
            let partItems = items.filter { $0.part == part }
            guard !partItems.isEmpty else { return nil }
            return FinalExamSectionDraft(part: part, items: partItems)
        }
    }
}

private struct FinalExamReadyItem: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }
    var part: FinalExamPart { FinalExamPart(title: block.title, fallbackIndex: index) }
    var prescription: TrainingBlockPrescription? { block.prescriptions.first }
    var title: String { block.title.uppercased() }
    var exerciseName: String { prescription?.exerciseName ?? block.title }

    var summary: String {
        guard let prescription else { return "Official station" }
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

private enum FinalExamPart: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"

    init(title: String, fallbackIndex: Int) {
        if title.localizedCaseInsensitiveContains("Part A") {
            self = .a
        } else if title.localizedCaseInsensitiveContains("Part B") {
            self = .b
        } else if title.localizedCaseInsensitiveContains("Part C") {
            self = .c
        } else if fallbackIndex == 0 {
            self = .a
        } else if fallbackIndex == 1 {
            self = .b
        } else {
            self = .c
        }
    }

    var shortTitle: String {
        switch self {
        case .a: return "Control"
        case .b: return "Capacity"
        case .c: return "Volume"
        }
    }

    var callout: String {
        switch self {
        case .a: return "Explosive control"
        case .b: return "Capacity proof"
        case .c: return "Volume finish"
        }
    }

    var tint: Color {
        switch self {
        case .a: return Color.unbound.emberGlow
        case .b: return Color.unbound.coachCyan
        case .c: return Color.unbound.rankGold
        }
    }
}
