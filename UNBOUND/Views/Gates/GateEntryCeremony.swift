import SwiftUI

/// The centered JRPG title stack that reveals line-by-line with haptic beats over
/// the gate-hall banner (spec §6.3). Reduced-motion shows all lines at once.
struct GateEntryCeremony: View {
    let world: GateWorld
    var onComplete: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedLines = 0

    private var lines: [String] {
        ["RANK GATE \(world.numeral)", world.trialName.uppercased(), world.promise]
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(lines[0]).font(Font.unbound.captionS.weight(.heavy)).tracking(3)
                .foregroundStyle(world.tint).opacity(revealedLines > 0 ? 1 : 0)
            Rectangle().fill(world.tint.opacity(0.6)).frame(width: 44, height: 1)
                .opacity(revealedLines > 0 ? 1 : 0)
            Text(lines[1]).font(Font.unbound.titleL.weight(.black))
                .foregroundStyle(Color.unbound.textPrimary).opacity(revealedLines > 1 ? 1 : 0)
            Text(lines[2]).font(Font.unbound.bodyMStrong).foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center).opacity(revealedLines > 2 ? 1 : 0)
            difficultyPips.opacity(revealedLines > 2 ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .task { await runCeremony() }
    }

    private var difficultyPips: some View {
        HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { i in
                Circle().fill(i < world.difficultyPips ? world.tint : Color.white.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func runCeremony() async {
        guard !reduceMotion else { revealedLines = lines.count + 1; onComplete?(); return }
        for step in 1...(lines.count) {
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.easeOut(duration: 0.3)) { revealedLines = step }
            UnboundHaptics.soft()
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        revealedLines = lines.count + 1
        onComplete?()
    }
}
