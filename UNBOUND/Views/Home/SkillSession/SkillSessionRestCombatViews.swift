import SwiftUI

struct ActiveSlot: Identifiable, Equatable {
    let prescriptionId: String
    let slotIndex: Int
    var id: String { "\(prescriptionId)#\(slotIndex)" }
}

// MARK: - RestCombatState

struct RestCombatState: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let setNumber: Int
    var targetRestSeconds: Int
    let startedAt: Date
}

// MARK: - RestCombatBanner

struct RestCombatBanner: View {
    let state: RestCombatState
    let onExtend: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: state.startedAt, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(state.startedAt)))
            let remaining = state.targetRestSeconds - elapsed
            let progress = max(0, min(1, Double(elapsed) / Double(max(1, state.targetRestSeconds))))
            let phase = phase(for: elapsed)
            let color = color(for: phase)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.unbound.borderSubtle, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1)))
                        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.42), radius: 8)
                    VStack(spacing: 0) {
                        Text(remaining >= 0 ? formatClock(remaining) : "+\(formatClock(abs(remaining)))")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .monospacedDigit()
                        Text(phase.label)
                            .font(.system(size: 7, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(color)
                    }
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text("REST")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.5)
                            .foregroundStyle(color)
                        Text("SET \(state.setNumber)")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }

                    Text(state.exerciseName.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    RestGuardHealthBar(progress: progress, isOverRest: phase == .over, color: color)
                }

                VStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Image(systemName: phase == .ready ? "bolt.fill" : "forward.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.unbound.bg)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(color))
                    }
                    .buttonStyle(.plain)

                    Button(action: onExtend) {
                        Text("+30")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 38, height: 26)
                            .background(Capsule().fill(Color.unbound.bg.opacity(0.72)))
                            .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.93))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(color.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.22), radius: 18, y: 10)
        }
    }

    private enum Phase {
        case recover, ready, over

        var label: String {
            switch self {
            case .recover: return "REC"
            case .ready: return "GO"
            case .over: return "DRAG"
            }
        }
    }

    private func phase(for elapsed: Int) -> Phase {
        if elapsed < state.targetRestSeconds { return .recover }
        if elapsed <= state.targetRestSeconds + 20 { return .ready }
        return .over
    }

    private func color(for phase: Phase) -> Color {
        switch phase {
        case .recover: return Color.unbound.coachCyan
        case .ready: return Color.unbound.success
        case .over: return Color.unbound.warnOrange
        }
    }

    private func formatClock(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct RestGuardHealthBar: View {
    let progress: Double
    let isOverRest: Bool
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.unbound.bg)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(clamped))
                    .shadow(color: color.opacity(0.35), radius: 5)
                if isOverRest {
                    Capsule()
                        .strokeBorder(Color.unbound.warnOrange.opacity(0.7), lineWidth: 1)
                }
            }
        }
        .frame(height: 7)
        .accessibilityLabel("Rest timer")
    }
}
