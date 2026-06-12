import SwiftUI

struct DeckExerciseHiddenPanel: View {
    let drawIndex: Int
    let remainingCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                ForEach(0..<3, id: \.self) { offset in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.unbound.surfaceElevated.opacity(0.76))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.unbound.coachCyan.opacity(0.24), lineWidth: 1)
                        )
                        .frame(width: 34, height: 46)
                        .rotationEffect(.degrees(Double(offset - 1) * 7))
                        .offset(x: CGFloat(offset - 1) * 5)
                }
            }
            .frame(width: 54, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text("DRAW \(numberString(drawIndex + 1)) FACE DOWN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("\(remainingCount) cards remain after this draw")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, -4)
        .padding(.bottom, 6)
        .accessibilityIdentifier("deck.hiddenExercise")
    }

    private func numberString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

struct RankTrialActiveFlowHeader: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession

    @ViewBuilder
    var body: some View {
        if definition.format == .fixedDeck {
            floatingDeckHeader
        } else {
            standardHeader
        }
    }

    private var floatingDeckHeader: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(definition.format.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .foregroundStyle(Color.unbound.coachCyan)
                    Text(definition.displayName)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                }

                Spacer()

                Text("\(loggedStations)/\(totalStations)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09)).frame(height: 3)
                    Capsule()
                        .fill(Color.unbound.coachCyan)
                        .frame(width: proxy.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                        stationChip(index: index, exercise: exercise)
                    }
                }
            }
        }
        .padding(.top, 28)
    }

    private var standardHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.format.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.coachCyan)
                    Text(definition.displayName)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Text("\(loggedStations)/\(totalStations)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                    .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.surfaceElevated).frame(height: 6)
                    Capsule()
                        .fill(Color.unbound.coachCyan)
                        .frame(width: proxy.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                        stationChip(index: index, exercise: exercise)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.28), lineWidth: 1)
        )
    }

    private var totalStations: Int {
        max(1, session.exercises.count)
    }

    private var loggedStations: Int {
        session.exercises.filter { exercise in
            exercise.sets.contains { $0.logged && !$0.isWarmup }
        }.count
    }

    private var progress: CGFloat {
        CGFloat(loggedStations) / CGFloat(totalStations)
    }

    private func stationChip(index: Int, exercise: ActiveWorkoutSession.ActiveExercise) -> some View {
        let isLogged = exercise.sets.contains { $0.logged && !$0.isWarmup }
        let isCurrent = index == session.currentExerciseIndex
        return Group {
            if definition.format == .fixedDeck {
                HStack(spacing: 6) {
                    Image(systemName: isLogged ? "checkmark.circle.fill" : (isCurrent ? "circle.dashed" : "circle"))
                        .font(.system(size: 12, weight: .bold))
                    Text(chipTitle(for: exercise, index: index))
                        .font(Font.unbound.captionS.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(isLogged ? Color.unbound.accent : (isCurrent ? Color.unbound.coachCyan : Color.unbound.textTertiary))
                .frame(height: 24)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: isLogged ? "checkmark.circle.fill" : (isCurrent ? "circle.dashed" : "circle"))
                        .font(.system(size: 12, weight: .bold))
                    Text(chipTitle(for: exercise, index: index))
                        .font(Font.unbound.captionS.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(isLogged ? Color.unbound.accent : (isCurrent ? Color.unbound.coachCyan : Color.unbound.textSecondary))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Color.unbound.surfaceElevated))
                .overlay(Capsule().strokeBorder(isCurrent ? Color.unbound.coachCyan.opacity(0.42) : Color.unbound.borderSubtle, lineWidth: 1))
            }
        }
    }

    private func chipTitle(for exercise: ActiveWorkoutSession.ActiveExercise, index: Int) -> String {
        if definition.format == .fixedDeck {
            return "Draw \(numberString(index + 1))"
        }
        if let blockTitle = exercise.blockTitle, !blockTitle.isEmpty {
            return blockTitle
        }
        return "\(unitLabel) \(index + 1)"
    }

    private func numberString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private var unitLabel: String {
        switch definition.format {
        case .daily100: return "Set"
        case .operatorScreen: return "Card"
        case .finisher: return "Round"
        case .fixedDeck: return "Card"
        case .tower: return "Floor"
        case .bossRush: return "Boss"
        case .raid: return "Stage"
        case .finalExam: return "Part"
        }
    }
}
