import SwiftUI

struct FirstLightTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var oathMarks: [FirstLightReadyMark] {
        blocks.prefix(5).enumerated().map { index, block in
            FirstLightReadyMark(index: index, block: block)
        }
    }

    private var targetTotal: Int {
        max(100, oathMarks.reduce(0) { $0 + $1.targetValue })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                FirstLightProofSeal(
                    progress: 1,
                    completedMarks: oathMarks.count,
                    totalMarks: max(5, oathMarks.count),
                    tint: tint,
                    pulse: false
                )
                .frame(width: 126, height: 152)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("FIRST LIGHT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)

                    Text("Five oath marks. One clean proof.")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        FirstLightChip("\(oathMarks.count) marks", icon: "seal.fill", tint: tint)
                        FirstLightChip("\(targetTotal) proof", icon: "checkmark", tint: Color.unbound.coachCyan)
                    }
                }
                .layoutPriority(1)
            }

            FirstLightEntryGate(marks: oathMarks, tint: tint)
                .frame(height: 164)
                .accessibilityIdentifier("workoutReady.firstLightGate")

            VStack(spacing: 9) {
                ForEach(oathMarks) { mark in
                    FirstLightReadyMarkRow(mark: mark, tint: tint)
                }
            }
            .accessibilityIdentifier("workoutReady.firstLightOathMarks")
        }
    }
}

private struct FirstLightReadyMark: Identifiable {
    let id: String
    let index: Int
    let title: String
    let exerciseName: String
    let targetText: String
    let targetValue: Int
    let kind: TrainingBlockKind
    let movementDefinition: MovementDefinition?
    let isComplete: Bool

    init(index: Int, block: TrainingBlock) {
        let prescription = block.prescriptions.first
        id = block.id
        self.index = index
        title = block.title.isEmpty ? FirstLightOathName.title(for: index) : block.title
        exerciseName = prescription?.exerciseName ?? title
        targetText = prescription.map { "\($0.sets) x \($0.displayTargetText)" } ?? "Official mark"
        targetValue = prescription?.target.firstLightValue ?? 0
        kind = block.kind
        movementDefinition = prescription.flatMap {
            MovementCatalog.resolvedTrainingMovement(
                name: $0.exerciseName,
                movementId: $0.movementId,
                rankStandardMovementId: $0.rankStandardMovementId
            )?.exact
        }
        isComplete = false
    }

    init(
        id: String,
        index: Int,
        title: String,
        exerciseName: String,
        targetText: String,
        targetValue: Int,
        kind: TrainingBlockKind,
        movementDefinition: MovementDefinition?,
        isComplete: Bool
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.exerciseName = exerciseName
        self.targetText = targetText
        self.targetValue = targetValue
        self.kind = kind
        self.movementDefinition = movementDefinition
        self.isComplete = isComplete
    }

    var markLabel: String {
        let value = index + 1
        return value < 10 ? "0\(value)" : "\(value)"
    }

    var cleanedTitle: String {
        title
            .replacingOccurrences(of: " Oath", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var fallbackIcon: String {
        FirstLightVisuals.fallbackIcon(for: kind)
    }
}

private struct FirstLightProofSeal: View {
    let progress: CGFloat
    let completedMarks: Int
    let totalMarks: Int
    let tint: Color
    let pulse: Bool

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            FirstLightSealShape(sides: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surfaceElevated.opacity(0.98),
                            Color.unbound.bg.opacity(0.96),
                            tint.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(FirstLightSealShape(sides: 12).stroke(tint.opacity(0.48), lineWidth: 1.2))
                .shadow(color: tint.opacity(pulse ? 0.30 : 0.14), radius: pulse ? 24 : 12, y: 8)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: [tint, Color.unbound.coachCyan, Color.unbound.accent, tint],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(13)

            Circle()
                .strokeBorder(Color.unbound.textPrimary.opacity(0.12), lineWidth: 1)
                .padding(23)

            VStack(spacing: 0) {
                Text("100")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.76)
                Text("PROOF")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(tint)
                Text("\(completedMarks)/\(max(1, totalMarks))")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
                    .padding(.top, 5)
            }

            VStack {
                FirstLightNotchRow(total: max(1, totalMarks), completed: completedMarks, tint: tint)
                Spacer()
            }
            .padding(.top, 14)
        }
        .accessibilityLabel("First Light proof seal")
        .accessibilityValue("\(completedMarks) of \(max(1, totalMarks)) oath marks")
    }
}

private struct FirstLightEntryGate: View {
    let marks: [FirstLightReadyMark]
    let tint: Color
    var activeIndex: Int? = nil
    var completedCount: Int = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                FirstLightGateShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.24),
                                Color.unbound.surfaceElevated.opacity(0.90),
                                Color.unbound.bg.opacity(0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(FirstLightGateShape().stroke(tint.opacity(0.38), lineWidth: 1.2))

                VStack(spacing: 10) {
                    HStack(spacing: 7) {
                        ForEach(Array(marks.prefix(5).enumerated()), id: \.element.id) { index, mark in
                            FirstLightGateMark(
                                mark: mark,
                                isActive: activeIndex == index,
                                isComplete: mark.isComplete || index < completedCount,
                                tint: tint
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(tint.opacity(0.48))
                            .frame(width: max(30, proxy.size.width * 0.22), height: 2)
                        Text("ENTRY GATE")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Rectangle()
                            .fill(tint.opacity(0.48))
                            .frame(width: max(30, proxy.size.width * 0.22), height: 2)
                    }
                }
                .padding(.bottom, 18)
            }
        }
    }
}

private struct FirstLightReadyMarkRow: View {
    let mark: FirstLightReadyMark
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                FirstLightMarkShape()
                    .fill(tint.opacity(0.12))
                    .overlay(FirstLightMarkShape().stroke(tint.opacity(0.42), lineWidth: 1))
                Text(mark.markLabel)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 38)

            if let definition = mark.movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 54, height: 46)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: mark.fallbackIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 46)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(mark.cleanedTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(mark.exerciseName)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(mark.targetText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private struct FirstLightGateMark: View {
    let mark: FirstLightReadyMark
    let isActive: Bool
    let isComplete: Bool
    let tint: Color

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                FirstLightMarkShape()
                    .fill(fill)
                    .overlay(FirstLightMarkShape().stroke(border, lineWidth: isActive ? 1.5 : 1))
                    .shadow(color: shadow, radius: isActive ? 12 : 0)

                Image(systemName: isComplete ? "checkmark" : icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(isComplete ? Color.unbound.bg : labelTint)
            }
            .frame(height: 44)

            Text(mark.cleanedTitle.uppercased())
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(isActive ? tint : Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(maxWidth: .infinity)
    }

    private var fill: Color {
        if isComplete { return Color.unbound.accent.opacity(0.94) }
        if isActive { return tint.opacity(0.26) }
        return Color.unbound.bg.opacity(0.72)
    }

    private var border: Color {
        if isComplete { return Color.unbound.accent }
        if isActive { return tint.opacity(0.82) }
        return Color.unbound.textPrimary.opacity(0.18)
    }

    private var labelTint: Color {
        isActive ? tint : Color.unbound.textSecondary
    }

    private var shadow: Color {
        isActive ? tint.opacity(0.30) : Color.clear
    }

    private var icon: String {
        switch mark.index {
        case 0: return "figure.strengthtraining.traditional"
        case 1: return "arrow.up.forward"
        case 2: return "arrow.left.and.right"
        case 3: return "figure.stairs"
        default: return "timer"
        }
    }
}

private struct FirstLightChip: View {
    let text: String
    let icon: String
    let tint: Color

    init(_ text: String, icon: String, tint: Color) {
        self.text = text
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        RankTrialInfoChip(text: text, icon: icon, tint: tint)
    }
}

private struct FirstLightNotchRow: View {
    let total: Int
    let completed: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < completed ? tint : Color.unbound.textPrimary.opacity(0.18))
                    .frame(width: 11, height: index < completed ? 5 : 3)
            }
        }
    }
}

private struct FirstLightSealShape: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        let count = max(6, sides * 2)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.48
        let innerRadius = outerRadius * 0.88
        var path = Path()

        for index in 0..<count {
            let angle = (Double(index) / Double(count) * 2 * Double.pi) - Double.pi / 2
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct FirstLightGateShape: Shape {
    func path(in rect: CGRect) -> Path {
        let capHeight = rect.height * 0.28
        let shoulder = rect.width * 0.14
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + capHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + capHeight),
            control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FirstLightMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.width * 0.18
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.24))
        path.closeSubpath()
        return path
    }
}

private enum FirstLightOathName {
    static func title(for index: Int) -> String {
        switch index {
        case 0: return "Lower Oath"
        case 1: return "Push Oath"
        case 2: return "Posture Oath"
        case 3: return "Step Oath"
        default: return "Trunk Oath"
        }
    }
}

private enum FirstLightVisuals {
    static func fallbackIcon(for blockKind: TrainingBlockKind) -> String {
        switch blockKind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }
}

private extension TrainingTarget {
    var firstLightValue: Int {
        switch self {
        case .reps(let value),
             .holdSeconds(let value),
             .timedSeconds(let value),
             .distanceMeters(let value),
             .calories(let value):
            return value
        case .repsRange(let lower, _):
            return lower
        case .amrap:
            return 0
        }
    }
}
