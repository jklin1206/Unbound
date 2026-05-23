import SwiftUI

// MARK: - ActiveTrialCard
//
// Shows the current active Binding Vow in the Home contextualStack.

struct ActiveTrialCard: View {
    let trial: Trial

    @EnvironmentObject private var services: ServiceContainer
    @State private var trainingDraft: TrainingSessionDraft?

    private var card: TrialCard { trial.chosenCard }
    private var tint: Color { card.theme.tintColor }
    private var canLaunchTraining: Bool {
        trial.capstoneState != .completed && trial.capstoneState != .missed
    }

    /// 0.0 = not started, 1.0 = complete.
    /// For now: pending=0, windowOpen=0.5, completed=1.0, missed=0.
    private var capstoneProgress: Double {
        switch trial.capstoneState {
        case .pending:    return 0.0
        case .windowOpen: return 0.5
        case .completed:  return 1.0
        case .missed:     return 0.0
        }
    }

    var body: some View {
        Button {
            startTraining()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .disabled(!canLaunchTraining)
        .accessibilityIdentifier("weeklyVow.activeCard.startTraining")
        .accessibilityLabel("Start binding vow training")
        .fullScreenCover(item: $trainingDraft) { draft in
            WorkoutReadyView(draft: draft)
                .environmentObject(services)
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 14) {
            TrialProgressGlyph(progress: capstoneProgress, tint: tint)
                .frame(width: 54, height: 58)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(card.theme.displayLabel.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(tint)
                        .lineLimit(1)

                    Text(capstoneStateLabel)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }

                Text(card.displayName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 7) {
                    Text("PROOF")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                    Text(card.capstone.displayName.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            capstonePill
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .trailing) {
                Color.unbound.surface
                TrialActiveCutShape()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.16), .clear],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: 178)
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 2)
                .shadow(color: tint.opacity(0.45), radius: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helpers

    @ViewBuilder
    private var capstonePill: some View {
        if trial.capstoneState == .completed {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("DONE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
            }
            .foregroundStyle(Color.unbound.success)
            .frame(width: 64, height: 30)
            .background(Capsule().fill(Color.unbound.success.opacity(0.14)))
        } else if canLaunchTraining {
            HStack(spacing: 5) {
                Text("TRAIN")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .black))
            }
            .foregroundStyle(Color.unbound.bg)
            .frame(width: 64, height: 30)
            .background(Capsule().fill(tint))
        } else {
            Text("LOCKED")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(tint)
                .frame(width: 64, height: 30)
                .background(Capsule().fill(tint.opacity(0.13)))
        }
    }

    private func startTraining() {
        guard canLaunchTraining else { return }
        UnboundHaptics.medium()
        trainingDraft = services.trials.trainingDraft(for: trial, date: Date())
    }

    private var capstoneStateLabel: String {
        switch trial.capstoneState {
        case .pending:    return "MON–FRI"
        case .windowOpen: return "OPEN"
        case .completed:  return "COMPLETE"
        case .missed:     return "MISSED"
        }
    }
}

private struct TrialProgressGlyph: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<3, id: \.self) { index in
                TrialActiveCutShape()
                    .fill(tint.opacity(0.10 + Double(index) * 0.07))
                    .frame(width: 13, height: CGFloat(38 + index * 8))
                    .offset(x: CGFloat(index - 1) * 14)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    TrialActiveCutShape()
                        .fill(tint)
                        .frame(width: 10, height: fillHeight(for: index))
                        .shadow(color: tint.opacity(0.28), radius: 6)
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: progress)
    }

    private func fillHeight(for index: Int) -> CGFloat {
        let target = progress * 3
        let fill = min(max(target - Double(index), 0), 1)
        return CGFloat(12 + fill * 34)
    }
}

private struct TrialActiveCutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lean = rect.width * 0.38
        path.move(to: CGPoint(x: rect.minX + lean, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - lean, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ActiveTrialCard(
            trial: Trial(
                id: "weekly-vow-W20-ember",
                userId: "preview",
                weekStart: Date(),
                chosenCard: TrialCard(
                    id: "weekly-vow-W20-ember",
                    kind: .ember,
                    theme: .axis(.power),
                    displayName: "Iron Rule Vow",
                    blurb: "Accept a low-day Binding Vow.",
                    capstone: TrialCapstone(displayName: "Low-Day Proof", description: "Complete easy power work.", evaluation: .manualClaim)
                ),
                capstoneState: .windowOpen
            )
        )
        .padding(20)
        .environmentObject(ServiceContainer.mock)
    }
}
