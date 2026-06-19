// UNBOUND/Views/Squads/SquadMissionCelebrationView.swift
//
// Full-screen takeover when the weekly squad mission completes.
// Claim grants Arcs via CurrencyWalletStore (ledger-deduped by mission sourceId).
import SwiftUI

struct SquadMissionCelebrationView: View {
    let mission: SquadMission
    let contributions: [(name: String, total: Int)]
    let onClaim: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false

    private var maxContribution: Int { max(contributions.map(\.total).max() ?? 1, 1) }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                Image("SquadCrest")
                    .resizable().scaledToFit()
                    .frame(width: 96, height: 96)
                    .scaleEffect(revealed ? 1 : 0.7)
                    .opacity(revealed ? 1 : 0)

                VStack(spacing: 8) {
                    Text("MISSION COMPLETE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(Color.unbound.accent)
                    Text(mission.kind.displayName)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(mission.kind.progressText(mission.currentProgress))
                        .font(Font.unbound.monoM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                }
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 12)

                VStack(spacing: 10) {
                    ForEach(Array(contributions.sorted { $0.total > $1.total }.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 10) {
                            Text(row.name)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .frame(width: 92, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.unbound.surface).frame(height: 6)
                                    Capsule().fill(Color.unbound.accent)
                                        .frame(width: revealed ? geo.size.width * CGFloat(row.total) / CGFloat(maxContribution) : 0, height: 6)
                                }
                            }
                            .frame(height: 6)
                            Text(mission.kind.progressText(row.total))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color.unbound.textTertiary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.horizontal, 28)
                .opacity(revealed ? 1 : 0)

                Spacer()

                Button {
                    onClaim()
                    dismiss()
                } label: {
                    Text("CLAIM \(SquadRewardPolicy.missionArcs) ARCS")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.unbound.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.12)) {
                revealed = true
            }
        }
    }
}
