import SwiftUI

struct ProgramMidBlockProposalCard: View {
    let proposal: BlockRolloverService.ProgramBlockProposal
    let onCheckpoint: () -> Void

    var body: some View {
        Button(action: onCheckpoint) {
            VStack(spacing: 0) {
                Divider()
                    .overlay(Color.unbound.accent.opacity(0.45))

                HStack(spacing: 10) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Checkpoint")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.accent)
                        Text(checkpointTitle)
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(.vertical, 11)

                Divider()
                    .overlay(Color.unbound.accent.opacity(0.28))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var checkpointTitle: String {
        proposal.scanDeltaReport?.improvements.first.map {
            "\($0.capitalized) changed since last scan"
        } ?? "Review this arc before it changes"
    }
}
