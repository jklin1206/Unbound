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
            .accessibilityIdentifier("workoutReady.finalExamSections")
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

struct FinalExamTrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var verdictPulse = false

    init(
        definition: OverallRankTrialDefinition,
        session: ActiveWorkoutSession,
        @ViewBuilder currentStationCard: @escaping (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard
    ) {
        self.definition = definition
        self.session = session
        self.currentStationCard = currentStationCard
    }

    var body: some View {
        RankTrialActiveStageLayout(pair: session.rankTrialCurrentExercisePair) {
            activeHeader
        } activeContent: { pair in
            activeDossier(pair)
            currentStationCard(pair.index, pair.exercise)
        } completedContent: {
            completedDossier
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                verdictPulse = true
            }
        }
    }

    private var activeHeader: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 14) {
                FinalExamVerdictSeal(
                    title: verdictTitle,
                    subtitle: "VERDICT",
                    tint: tint,
                    pulse: verdictPulse
                )
                .frame(width: 86, height: 86)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(definition.format.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.7)
                        .foregroundStyle(tint)
                    Text(currentTitle)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text("\(loggedStations)/\(totalStations) stations stamped")
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .layoutPriority(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surfaceElevated)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.unbound.emberGlow, Color.unbound.coachCyan, tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stations) { station in
                        FinalExamStationStamp(station: station, tint: tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("finalExam.activeHeader")
    }

    private func activeDossier(_ pair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)) -> some View {
        let station = FinalExamActiveStation(index: pair.index, exercise: pair.exercise, currentIndex: session.currentExerciseIndex)

        return VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                FinalExamDossierShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                station.part.tint.opacity(0.26),
                                Color.unbound.surface.opacity(0.94),
                                Color.unbound.bg.opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(FinalExamDossierShape().strokeBorder(station.part.tint.opacity(0.42), lineWidth: 1.1))

                HStack(alignment: .center, spacing: 14) {
                    visual(for: pair.exercise)
                        .frame(width: 104, height: 104)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            FinalExamPhaseBadge(part: station.part)
                            Label(station.dossierStatusText, systemImage: station.isLogged ? "checkmark.seal.fill" : "scope")
                                .font(Font.unbound.captionS.weight(.heavy))
                                .foregroundStyle(station.isLogged ? Color.unbound.bg : Color.unbound.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .padding(.horizontal, 9)
                                .frame(height: 27)
                                .background(Capsule().fill(station.isLogged ? Color.unbound.accent : Color.unbound.surfaceElevated))
                                .overlay(Capsule().strokeBorder(station.part.tint.opacity(0.32), lineWidth: 1))
                        }

                        Text(pair.exercise.blockTitle ?? pair.exercise.name)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        Text(pair.exercise.name)
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        HStack(spacing: 8) {
                            FinalExamMetricChip(value: "\(pair.exercise.plannedSets)x", label: pair.exercise.plannedReps, tint: station.part.tint)
                            FinalExamMetricChip(value: Self.mmss(pair.exercise.restSeconds), label: "REST", tint: tint)
                        }
                    }
                    .layoutPriority(1)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 168)

            FinalExamVerdictStampPad(
                stations: stations,
                currentPart: station.part,
                tint: tint
            )

            FinalExamPartRail(stations: stations, tint: tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("finalExam.activeDossier")
    }

    private var completedDossier: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                FinalExamVerdictSeal(
                    title: "FILED",
                    subtitle: "VERDICT",
                    tint: tint,
                    pulse: verdictPulse
                )
                .frame(width: 108, height: 108)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("EXAM COMPLETE")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.7)
                        .foregroundStyle(tint)
                    Text("All stations are stamped. Finish the trial to record the verdict.")
                        .font(Font.unbound.bodyM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }

            FinalExamPartRail(stations: stations, tint: tint)
        }
        .padding(14)
        .background(FinalExamDossierShape().fill(Color.unbound.surface.opacity(0.92)))
        .overlay(FinalExamDossierShape().strokeBorder(tint.opacity(0.34), lineWidth: 1))
        .accessibilityIdentifier("finalExam.completedDossier")
    }

    private var stations: [FinalExamActiveStation] {
        session.exercises.enumerated().compactMap { index, exercise in
            guard !exercise.skipped else { return nil }
            return FinalExamActiveStation(index: index, exercise: exercise, currentIndex: session.currentExerciseIndex)
        }
    }

    private var currentTitle: String {
        guard let pair = session.rankTrialCurrentExercisePair else { return "Final Verdict" }
        return pair.exercise.blockTitle ?? pair.exercise.name
    }

    private var verdictTitle: String {
        progress >= 1 ? "PASS" : "LIVE"
    }

    private var totalStations: Int {
        max(1, stations.count)
    }

    private var loggedStations: Int {
        stations.filter(\.isLogged).count
    }

    private var progress: CGFloat {
        session.rankTrialProgress(loggedStations: loggedStations)
    }

    private var tint: Color {
        definition.targetRank.rewardTextTint
    }

    @ViewBuilder
    private func visual(for exercise: ActiveWorkoutSession.ActiveExercise) -> some View {
        if let definition = movementDefinition(for: exercise) {
            ExerciseVisualView(definition: definition, size: .thumbnail)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
                .overlay(
                    Image(systemName: fallbackIcon(for: exercise.blockKind))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(tint)
                )
                .accessibilityHidden(true)
        }
    }

    private func movementDefinition(for exercise: ActiveWorkoutSession.ActiveExercise) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    private func fallbackIcon(for blockKind: TrainingBlockKind) -> String {
        switch blockKind {
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

private struct FinalExamMetricChip: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, 9)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct FinalExamStationStamp: View {
    let station: FinalExamActiveStation
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: station.isLogged ? "checkmark.seal.fill" : (station.isCurrent ? "circle.hexagongrid.circle.fill" : "circle"))
                .font(.system(size: 12, weight: .bold))
            Text(station.part.rawValue)
                .font(Font.unbound.monoS.weight(.bold))
            Text(station.compactTitle)
                .font(Font.unbound.captionS.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(stationColor)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(Color.unbound.surfaceElevated))
        .overlay(Capsule().strokeBorder(stationBorder, lineWidth: 1))
    }

    private var stationColor: Color {
        if station.isLogged { return Color.unbound.accent }
        if station.isCurrent { return station.part.tint }
        return Color.unbound.textSecondary
    }

    private var stationBorder: Color {
        if station.isCurrent { return station.part.tint.opacity(0.5) }
        if station.isLogged { return tint.opacity(0.36) }
        return Color.unbound.borderSubtle
    }
}

private struct FinalExamPartRail: View {
    let stations: [FinalExamActiveStation]
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            ForEach(stations) { station in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(station.isLogged ? station.part.tint : Color.unbound.surfaceElevated)
                        Circle()
                            .strokeBorder(station.part.tint.opacity(station.isCurrent ? 0.86 : 0.34), lineWidth: station.isCurrent ? 2 : 1)
                        Text(station.part.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(station.isLogged ? Color.unbound.bg : Color.unbound.textPrimary)
                    }
                    .frame(width: 30, height: 30)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.unbound.surfaceElevated).frame(height: 5)
                            Capsule()
                                .fill(station.part.tint)
                                .frame(width: proxy.size.width * station.progress, height: 5)
                        }
                    }
                    .frame(height: 5)

                    Text(station.statusText)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .foregroundStyle(station.isLogged ? tint : Color.unbound.textSecondary)
                        .frame(width: 70, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

private struct FinalExamVerdictStampPad: View {
    let stations: [FinalExamActiveStation]
    let currentPart: FinalExamPart
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FinalExamPart.allCases, id: \.rawValue) { part in
                let total = stations.filter { $0.part == part }.count
                let stamped = stations.filter { $0.part == part && $0.isLogged }.count

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        FinalExamMiniStamp(text: part.rawValue, tint: part.tint)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(part.shortTitle.uppercased())
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .tracking(0.9)
                                .foregroundStyle(part == currentPart ? part.tint : Color.unbound.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                            Text("\(stamped)/\(max(1, total))")
                                .font(Font.unbound.monoS.weight(.bold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .monospacedDigit()
                        }
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.unbound.bg.opacity(0.72))
                            Capsule()
                                .fill(part.tint)
                                .frame(width: proxy.size.width * CGFloat(stamped) / CGFloat(max(1, total)))
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    FinalExamDossierShape()
                        .fill(Color.unbound.surface.opacity(part == currentPart ? 0.96 : 0.76))
                )
                .overlay(
                    FinalExamDossierShape()
                        .strokeBorder(part.tint.opacity(part == currentPart ? 0.42 : 0.18), lineWidth: 1)
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Final exam stamp pad")
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

private struct FinalExamActiveStation: Identifiable {
    let index: Int
    let exercise: ActiveWorkoutSession.ActiveExercise
    let currentIndex: Int

    var id: String { exercise.id }
    var part: FinalExamPart { FinalExamPart(title: exercise.blockTitle ?? exercise.name, fallbackIndex: index) }
    var isCurrent: Bool { index == currentIndex }

    var isLogged: Bool {
        let workSets = exercise.sets.filter { !$0.isWarmup }
        guard !workSets.isEmpty else { return false }
        return workSets.allSatisfy(\.logged)
    }

    var progress: CGFloat {
        CGFloat(loggedWorkSetCount) / CGFloat(totalWorkSetCount)
    }

    var compactTitle: String {
        let title = exercise.blockTitle ?? exercise.name
        if title.localizedCaseInsensitiveContains("Explosive") { return "Explosive" }
        if title.localizedCaseInsensitiveContains("Capacity") { return "Capacity" }
        if title.localizedCaseInsensitiveContains("Pull") { return "Pull" }
        if title.localizedCaseInsensitiveContains("Push") { return "Push" }
        if title.localizedCaseInsensitiveContains("Lower") { return "Lower" }
        if title.localizedCaseInsensitiveContains("Carry") { return "Carry" }
        if title.localizedCaseInsensitiveContains("Trunk") { return "Trunk" }
        return "Station \(index + 1)"
    }

    var statusText: String {
        if isLogged { return "STAMPED" }
        if loggedWorkSetCount > 0 { return "\(loggedWorkSetCount)/\(totalWorkSetCount)" }
        if isCurrent { return "LIVE" }
        return "OPEN"
    }

    var dossierStatusText: String {
        if isLogged { return "STAMPED" }
        if loggedWorkSetCount > 0 { return "\(loggedWorkSetCount)/\(totalWorkSetCount) REVIEW" }
        return "IN REVIEW"
    }

    private var totalWorkSetCount: Int {
        max(1, exercise.sets.filter { !$0.isWarmup }.count)
    }

    private var loggedWorkSetCount: Int {
        exercise.sets.filter { !$0.isWarmup && $0.logged }.count
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
