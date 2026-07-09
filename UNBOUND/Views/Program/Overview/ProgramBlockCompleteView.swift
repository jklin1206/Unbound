import SwiftUI

/// The end-of-block beat: a calm card in the day-card slot when a 30-day block
/// (or the 7-day Calibration Week) elapses. The rest of the Program tab stays
/// put — week strip, dock, coach chips — because "your next block is building"
/// is one sentence, not a screen. The next block builds automatically; the
/// CONTINUE button only surfaces if that auto-build didn't land.
struct ProgramBlockCompleteView: View {
    let trainedDays: Int
    let totalDays: Int
    /// The 7-day Calibration Week just elapsed (vs a normal 30-day block).
    var isCalibrationComplete: Bool = false
    let isGeneratingNextBlock: Bool
    let onBuildNextBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(isCalibrationComplete ? "CALIBRATION COMPLETE" : "\(totalDays) DAYS DONE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.accent)
                Spacer(minLength: 0)
                if trainedDays > 0 {
                    Text("\(trainedDays) of \(totalDays) logged")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            Text(headline)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if isGeneratingNextBlock {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.unbound.accent)
                    Text("Building…")
                        .font(Font.unbound.captionS.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                .padding(.top, 2)
            } else {
                Button {
                    onBuildNextBlock()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("CONTINUE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .tracking(1.6)
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.accent)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.14), radius: 16, y: 2)
    }

    private var headline: String {
        if isCalibrationComplete {
            return isGeneratingNextBlock
                ? "Baselines mapped. Building your first \(Arc.durationDays) days."
                : "Baselines mapped. Your first \(Arc.durationDays) days are ready to build."
        }
        return isGeneratingNextBlock
            ? "Nice work. Your next \(totalDays) days are building."
            : "Nice work. Your next \(totalDays) days are ready to build."
    }
}
