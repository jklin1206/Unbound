import SwiftUI

// MARK: - LockedClusterInfoSheet
//
// Shown when the user taps a gated cluster on the Skill Map. Explains WHY
// the cluster is dark and names the keystone they have to crack to open it.
// Keeps the cluster picker discoverable without giving the staircase away.

struct LockedClusterInfoSheet: View {
    let cluster: SkillCluster
    let requiredCluster: SkillCluster
    let graph: SkillGraph
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: cluster.glyph)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(cluster.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(cluster.tagline)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.unbound.accent)
                Text("LOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.accent)
                Text("Unlocks when you complete the")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(requiredCluster.displayName.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("keystone")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.unbound.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.unbound.accent.opacity(0.4), lineWidth: 1)
                    )
            )

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("GOT IT")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.unbound.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
