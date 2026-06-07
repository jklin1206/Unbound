import SwiftUI

struct ProgramBlockCompleteView: View {
    let currentBlock: Int
    let nextBlock: Int
    let arc: String
    let trainedDays: Int
    let totalDays: Int
    let deltaReport: ScanDeltaReport?
    let proposal: BlockRolloverService.ProgramBlockProposal?
    let isGeneratingNextBlock: Bool
    let onProgressSnapshot: () -> Void
    let onBuildNextBlock: () -> Void
    let onCheckpoint: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                summary

                if let deltaReport {
                    progressTeaser(deltaReport)
                }

                if let proposal {
                    blockProposalCard(proposal)
                }

                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BLOCK COMPLETE")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.accent)
            Text("28 days. Block \(currentBlock) done.")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(trainedDays)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("/ \(totalDays) sessions logged")
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.62))
            }
            Text(blockArcSummary)
                .font(Font.unbound.bodyL)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func progressTeaser(_ delta: ScanDeltaReport) -> some View {
        Button {
            onProgressSnapshot()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("PROGRESS SNAPSHOT")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Text(blockProgressTeaser(delta))
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func blockProposalCard(_ proposal: BlockRolloverService.ProgramBlockProposal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                Text("NEXT BLOCK PROPOSAL")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                Text("BLOCK \(proposal.nextBlockNumber)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(proposal.lines.prefix(4).enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: proposalIcon(for: line.kind))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(proposalColor(for: line.kind))
                            .frame(width: 16)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(2)
                            Text(line.detail)
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
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
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                onBuildNextBlock()
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingNextBlock {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.unbound.textPrimary)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(isGeneratingNextBlock ? "BUILDING..." : "BUILD BLOCK \(nextBlock)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .tracking(1.6)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingNextBlock)

            Button(action: onCheckpoint) {
                Text("CHECKPOINT FIRST")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.66))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingNextBlock)
        }
    }

    private var blockArcSummary: String {
        let currentArc = arcLabel(for: currentBlock)
        switch currentArc {
        case "accumulation":
            return "Block \(currentBlock) was about laying volume - base reps, base shape. Block \(nextBlock) shifts into \(arc): heavier loads, lower reps, harder finishes."
        case "intensification":
            return "Block \(currentBlock) pushed intensity. Block \(nextBlock) moves into \(arc): peak weights, sharpest output, the highest output of the cycle."
        case "realization":
            return "Block \(currentBlock) was peak. Block \(nextBlock) resets into \(arc): rebuild volume, set the next ceiling."
        default:
            return "Block \(currentBlock) is in the books. Block \(nextBlock) shifts into \(arc) - different stimulus, fresh adaptations."
        }
    }

    private func blockProgressTeaser(_ delta: ScanDeltaReport) -> String {
        let improvement = delta.improvements.first?.capitalized
        switch improvement {
        case let improvement?:
            return "\(improvement) trending up. Block \(nextBlock) builds on it."
        case nil:
            return "Tap to see the side-by-side."
        }
    }

    private func arcLabel(for blockNumber: Int) -> String {
        let arc = ((max(blockNumber, 1) - 1) % 3) + 1
        switch arc {
        case 1: return "accumulation"
        case 2: return "intensification"
        case 3: return "realization"
        default: return "accumulation"
        }
    }

    private func proposalIcon(for kind: BlockRolloverService.ProgramBlockProposal.Line.Kind) -> String {
        switch kind {
        case .scan: return "camera.metering.center.weighted"
        case .focus: return "scope"
        case .carryForward: return "arrow.forward.circle"
        case .rotation: return "arrow.triangle.2.circlepath"
        case .rescan: return "camera.viewfinder"
        }
    }

    private func proposalColor(for kind: BlockRolloverService.ProgramBlockProposal.Line.Kind) -> Color {
        switch kind {
        case .scan, .focus: return Color.unbound.accent
        case .rotation, .rescan: return Color.unbound.warnOrange
        case .carryForward: return Color.unbound.textSecondary
        }
    }
}
