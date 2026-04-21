import SwiftUI

// MARK: - PhaseChip
//
// Monospace pill that reads "WEEK 3 · ACCUMULATION". Tap opens a sheet
// showing the rationale + next-phase hint. Source of truth is
// ProgramPhaseEngine (not a 12-week countdown).

struct PhaseChip: View {
    let phase: ProgramPhase
    @State private var showingDetail = false

    var body: some View {
        Button {
            UnboundHaptics.medium()
            showingDetail = true
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.unbound.accent.opacity(0.7), radius: 4)
                Text("WEEK \(phase.weekInBlock)")
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(phase.blockType.displayName.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            PhaseDetailSheet(phase: phase)
                .presentationDetents([.medium])
                .presentationBackground(Color.unbound.bg)
        }
    }
}

// MARK: - PhaseDetailSheet

private struct PhaseDetailSheet: View {
    let phase: ProgramPhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("PHASE")
                    .font(Font.unbound.captionS)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(8)
                        .background(Circle().fill(Color.unbound.surface))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(phase.blockType.displayName.uppercased())
                    .font(Font.unbound.titleL)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Week \(phase.weekInBlock) of this phase")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("WHY THIS PHASE")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(phase.rationale)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT COMES NEXT")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(phase.nextPhaseHint)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 14) {
        PhaseChip(phase: ProgramPhase(
            blockType: .accumulation,
            weekInBlock: 3,
            rationale: "You're laying down volume. 2 rank advances in the last four weeks.",
            nextPhaseHint: "Intensification opens when current rep ranges start to feel comfortable."
        ))
        PhaseChip(phase: ProgramPhase(
            blockType: .deload,
            weekInBlock: 1,
            rationale: "2 lifts have stalled. Pulling volume back so the nervous system resets.",
            nextPhaseHint: "Returning to accumulation at refreshed working weights next week."
        ))
    }
    .padding()
    .background(Color.unbound.bg)
}
